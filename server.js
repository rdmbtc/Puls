import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { initiateDeveloperControlledWalletsClient } from '@circle-fin/developer-controlled-wallets';

const app = express();
app.use(cors());
app.use(express.json());

const circle = initiateDeveloperControlledWalletsClient({
  apiKey: process.env.CIRCLE_API_KEY,
  entitySecret: process.env.CIRCLE_ENTITY_SECRET,
});

const USDC = '0x3600000000000000000000000000000000000000';
const MARKET_CONTRACT = process.env.MARKET_CONTRACT || '';
const DB_FILE = './wallets.json';

// Persist userId → walletId to disk so wallets survive restarts
function loadDb() {
  if (!existsSync(DB_FILE)) return {};
  try { return JSON.parse(readFileSync(DB_FILE, 'utf8')); } catch { return {}; }
}
function saveDb(db) {
  writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

let db = loadDb();
let walletSetId = process.env.WALLET_SET_ID || '';

// Track which wallets have already approved the market contract
const approvedWallets = new Set(
  existsSync('./approved.json')
    ? JSON.parse(readFileSync('./approved.json', 'utf8'))
    : []
);
function saveApproved() {
  writeFileSync('./approved.json', JSON.stringify([...approvedWallets]));
}
const TRADES_FILE = './trades.json';
function loadTrades() {
  if (!existsSync(TRADES_FILE)) return {};
  try { return JSON.parse(readFileSync(TRADES_FILE, 'utf8')); } catch { return {}; }
}
function saveTrades(t) { writeFileSync(TRADES_FILE, JSON.stringify(t, null, 2)); }
let trades = loadTrades(); // { userId: [{ txId, side, usdcAmount, question, marketId, timestamp, state }] }

async function ensureWalletSet() {
  if (walletSetId) return walletSetId;
  const res = await circle.createWalletSet({ name: 'Puls Users' });
  walletSetId = res.data.walletSet.id;
  console.log('Created wallet set:', walletSetId);
  return walletSetId;
}

// ── GET or CREATE wallet ──────────────────────────────────────────────────────

app.post('/api/wallet/get-or-create', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    // Return existing wallet from disk
    if (db[userId]) {
      const info = await getWalletInfo(db[userId]);
      return res.json(info);
    }

    // Create new wallet
    const setId = await ensureWalletSet();
    const createRes = await circle.createWallets({
      accountType: 'EOA',
      blockchains: ['ARC-TESTNET'],
      count: 1,
      walletSetId: setId,
    });

    const wallet = createRes.data.wallets[0];
    db[userId] = wallet.id;
    saveDb(db);
    console.log(`Created wallet for ${userId}: ${wallet.address}`);

    res.json(await getWalletInfo(wallet.id));
  } catch (e) {
    console.error('get-or-create error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

async function getWalletInfo(walletId) {
  const [walletRes, balRes] = await Promise.all([
    circle.getWallet({ id: walletId }),
    circle.getWalletTokenBalance({ id: walletId }),
  ]);
  const wallet = walletRes.data.wallet;
  const usdcToken = balRes.data.tokenBalances?.find(
    t => t.token?.address?.toLowerCase() === USDC.toLowerCase() || t.token?.symbol === 'USDC'
  );
  return {
    walletId,
    address: wallet.address,
    usdcBalance: parseFloat(usdcToken?.amount ?? '0').toFixed(2),
  };
}

// ── Export wallet (returns address only — private key not accessible via API) ─

app.get('/api/wallet/balance', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId || !db[userId]) return res.status(404).json({ error: 'Wallet not found' });
    const balRes = await circle.getWalletTokenBalance({ id: db[userId] });
    const usdcToken = balRes.data.tokenBalances?.find(
      t => t.token?.address?.toLowerCase() === USDC.toLowerCase() || t.token?.symbol === 'USDC'
    );
    res.json({ usdcBalance: parseFloat(usdcToken?.amount ?? '0').toFixed(2) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/wallet/export', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId || !db[userId]) return res.status(404).json({ error: 'Wallet not found' });

    const info = await getWalletInfo(db[userId]);
    // Circle developer-controlled wallets don't expose private keys via API by design.
    // We return the address and walletId for reference.
    res.json({
      walletId: info.walletId,
      address: info.address,
      network: 'Arc Testnet',
      chainId: 5042002,
      rpc: 'https://rpc.testnet.arc.network',
      explorer: `https://testnet.arcscan.app/address/${info.address}`,
      note: 'This is a developer-controlled wallet. Private key is managed by Circle MPC.',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── Trade ─────────────────────────────────────────────────────────────────────

app.post('/api/trade/buy', async (req, res) => {
  try {
    const { userId, side, usdcAmount } = req.body;
    if (!userId || !side || !usdcAmount) return res.status(400).json({ error: 'Missing fields' });
    if (!MARKET_CONTRACT) return res.status(500).json({ error: 'MARKET_CONTRACT not set' });

    const walletId = db[userId];
    if (!walletId) return res.status(400).json({ error: 'No wallet. Call get-or-create first.' });

    const isYes = side === 'YES';
    const amount = parseFloat(usdcAmount);
    // USDC has 6 decimals: $1.00 = 1_000_000
    const amountMicro = Math.round(amount * 1_000_000).toString();

    // Check balance before trading
    const info = await getWalletInfo(walletId);
    const balance = parseFloat(info.usdcBalance);
    if (balance < amount) {
      return res.status(400).json({
        error: `Insufficient USDC. Balance: $${balance.toFixed(2)}, Need: $${amount.toFixed(2)}. Get testnet USDC at faucet.circle.com`,
        balance: info.usdcBalance,
      });
    }

    // Step 1: Approve max USDC once per wallet (skip if already approved)
    if (!approvedWallets.has(walletId)) {
      const MAX_UINT256 = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
      const approveRes = await circle.createContractExecutionTransaction({
        walletId,
        contractAddress: USDC,
        abiFunctionSignature: 'approve(address,uint256)',
        abiParameters: [MARKET_CONTRACT, MAX_UINT256],
        fee: { type: 'level', config: { feeLevel: 'HIGH' } },
      });

      // Wait for approval
      const approveTxId = approveRes.data.id;
      for (let i = 0; i < 30; i++) {
        await new Promise(r => setTimeout(r, 2000));
        const check = await circle.getTransaction({ id: approveTxId });
        const state = check.data.transaction.state;
        if (state === 'COMPLETE') {
          approvedWallets.add(walletId);
          saveApproved();
          break;
        }
        if (state === 'FAILED' || state === 'DENIED') {
          return res.status(500).json({ error: 'USDC approval failed', state });
        }
      }
    }

    // Step 2: Call buyYes or buyNo (no approve needed — already approved max)
    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: MARKET_CONTRACT,
      abiFunctionSignature: isYes ? 'buyYes(uint256)' : 'buyNo(uint256)',
      abiParameters: [amountMicro],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    res.json({ txId: txRes.data.id, state: txRes.data.state, side, balance: info.usdcBalance });

    // Save only the buyYes/buyNo trade (not the approve)
    if (!trades[userId]) trades[userId] = [];
    trades[userId].unshift({
      txId: txRes.data.id,
      side,
      usdcAmount: amount,
      question: req.body.question || 'Prediction Market',
      marketId: MARKET_CONTRACT,
      timestamp: new Date().toISOString(),
      state: 'INITIATED',
    });
    saveTrades(trades);
  } catch (e) {
    console.error('trade error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/trade/status', async (req, res) => {
  try {
    const { txId } = req.query;
    const txRes = await circle.getTransaction({ id: txId });
    const tx = txRes.data.transaction;
    res.json({ state: tx.state, txHash: tx.txHash ?? null });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /api/portfolio?userId=...
// Returns real trades with live status from Circle
app.get('/api/portfolio', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    const userTrades = trades[userId] ?? [];
    if (userTrades.length === 0) return res.json({ positions: [], totalSpent: '0.00', totalValue: '0.00' });

    // Fetch live status for recent trades
    const positions = await Promise.all(
      userTrades.slice(0, 20).map(async (trade) => {
        try {
          const txRes = await circle.getTransaction({ id: trade.txId });
          const tx = txRes.data.transaction;
          return { ...trade, state: tx.state, txHash: tx.txHash ?? null };
        } catch {
          return trade;
        }
      })
    );

    const completed = positions.filter(p => p.state === 'COMPLETE');
    const totalSpent = completed.reduce((s, p) => s + p.usdcAmount, 0).toFixed(2);

    res.json({ positions, totalSpent, totalValue: totalSpent }); // value = cost basis until market resolves
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (_, res) => res.json({ ok: true, wallets: Object.keys(db).length }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Puls backend :${PORT} | ${Object.keys(db).length} wallets loaded`));
