import 'dotenv/config';
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import { initiateDeveloperControlledWalletsClient } from '@circle-fin/developer-controlled-wallets';

const app = express();
app.use(cors());
app.use(express.json());

const circle = initiateDeveloperControlledWalletsClient({
  apiKey: process.env.CIRCLE_API_KEY,
  entitySecret: process.env.CIRCLE_ENTITY_SECRET,
});

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY // use service_role key (server-side only)
);

const USDC = '0x3600000000000000000000000000000000000000';
const MARKET_CONTRACT = process.env.MARKET_CONTRACT || '';
let walletSetId = process.env.WALLET_SET_ID || '';

// ── Supabase helpers ──────────────────────────────────────────────────────────

async function getWalletId(userId) {
  const { data } = await supabase
    .from('wallets')
    .select('wallet_id')
    .eq('user_id', userId)
    .single();
  return data?.wallet_id ?? null;
}

async function saveWallet(userId, walletId) {
  await supabase.from('wallets').upsert({ user_id: userId, wallet_id: walletId });
}

async function isApproved(walletId) {
  const { data } = await supabase
    .from('approved_wallets')
    .select('wallet_id')
    .eq('wallet_id', walletId)
    .single();
  return !!data;
}

async function markApproved(walletId) {
  await supabase.from('approved_wallets').upsert({ wallet_id: walletId });
}

async function saveTrade(userId, trade) {
  await supabase.from('trades').insert({ user_id: userId, ...trade });
}

async function getTrades(userId) {
  const { data } = await supabase
    .from('trades')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(50);
  return data ?? [];
}

// ── Wallet ────────────────────────────────────────────────────────────────────

async function ensureWalletSet() {
  if (walletSetId) return walletSetId;
  const res = await circle.createWalletSet({ name: 'Puls Users' });
  walletSetId = res.data.walletSet.id;
  console.log('Created wallet set:', walletSetId);
  return walletSetId;
}

const walletAddressCache = new Map();

async function getWalletInfo(walletId) {
  try {
    let address = walletAddressCache.get(walletId);
    if (address) {
      const balRes = await circle.getWalletTokenBalance({ id: walletId });
      const usdcToken = balRes.data.tokenBalances?.find(
        t => t.token?.address?.toLowerCase() === USDC.toLowerCase() || t.token?.symbol === 'USDC'
      );
      const balance = parseFloat(usdcToken?.amount ?? '0').toFixed(2);
      return { walletId, address, usdcBalance: balance };
    } else {
      const [walletRes, balRes] = await Promise.all([
        circle.getWallet({ id: walletId }),
        circle.getWalletTokenBalance({ id: walletId }),
      ]);
      address = walletRes.data.wallet.address;
      walletAddressCache.set(walletId, address);
      const usdcToken = balRes.data.tokenBalances?.find(
        t => t.token?.address?.toLowerCase() === USDC.toLowerCase() || t.token?.symbol === 'USDC'
      );
      const balance = parseFloat(usdcToken?.amount ?? '0').toFixed(2);
      return { walletId, address, usdcBalance: balance };
    }
  } catch (e) {
    console.error('getWalletInfo error:', e.message);
    return { walletId, address: '', usdcBalance: '0' };
  }
}

// POST /api/wallet/get-or-create
app.post('/api/wallet/get-or-create', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    const existing = await getWalletId(userId);
    if (existing) return res.json(await getWalletInfo(existing));

    const setId = await ensureWalletSet();
    const createRes = await circle.createWallets({
      accountType: 'EOA',
      blockchains: ['ARC-TESTNET'],
      count: 1,
      walletSetId: setId,
    });

    const wallet = createRes.data.wallets[0];
    await saveWallet(userId, wallet.id);
    console.log(`Created wallet for ${userId}: ${wallet.address}`);
    res.json(await getWalletInfo(wallet.id));
  } catch (e) {
    console.error('get-or-create:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// GET /api/wallet/balance
app.get('/api/wallet/balance', async (req, res) => {
  try {
    const { userId } = req.query;
    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(404).json({ error: 'Wallet not found' });
    const info = await getWalletInfo(walletId);
    res.json({ usdcBalance: info.usdcBalance });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /api/wallet/export
app.get('/api/wallet/export', async (req, res) => {
  try {
    const { userId } = req.query;
    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(404).json({ error: 'Wallet not found' });
    const info = await getWalletInfo(walletId);
    res.json({
      ...info,
      network: 'Arc Testnet',
      chainId: 5042002,
      rpc: 'https://rpc.testnet.arc.network',
      explorer: `https://testnet.arcscan.app/address/${info.address}`,
      note: 'Circle MPC wallet. Private key managed by Circle.',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── Trade ─────────────────────────────────────────────────────────────────────

app.post('/api/trade/buy', async (req, res) => {
  try {
    const { userId, side, usdcAmount, question } = req.body;
    if (!userId || !side || !usdcAmount) return res.status(400).json({ error: 'Missing fields' });
    if (!MARKET_CONTRACT) return res.status(500).json({ error: 'MARKET_CONTRACT not set' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    const isYes = side === 'YES';
    const amount = parseFloat(usdcAmount);
    const amountMicro = Math.round(amount * 1_000_000).toString();

    const info = await getWalletInfo(walletId);
    if (parseFloat(info.usdcBalance) < amount) {
      return res.status(400).json({
        error: `Insufficient USDC. Balance: $${info.usdcBalance}, Need: $${amount.toFixed(2)}. Get testnet USDC at faucet.circle.com`,
      });
    }

    // Approve max once — fire async, don't block the trade response
    if (!(await isApproved(walletId))) {
      const MAX = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
      try {
        const approveRes = await circle.createContractExecutionTransaction({
          walletId,
          contractAddress: USDC,
          abiFunctionSignature: 'approve(address,uint256)',
          abiParameters: [MARKET_CONTRACT, MAX],
          fee: { type: 'level', config: { feeLevel: 'HIGH' } },
        });
        // Poll approval in background — mark approved when done
        (async () => {
          for (let i = 0; i < 30; i++) {
            await new Promise(r => setTimeout(r, 2000));
            try {
              const check = await circle.getTransaction({ id: approveRes.data.id });
              const s = check.data.transaction.state;
              if (s === 'COMPLETE') { await markApproved(walletId); break; }
              if (s === 'FAILED' || s === 'DENIED' || s === 'CANCELLED') break;
            } catch {}
          }
        })();
        // Wait briefly for approval to clear before submitting trade
        await new Promise(r => setTimeout(r, 4000));
      } catch (e) {
        console.error('approve error:', e.message);
      }
    }

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: MARKET_CONTRACT,
      abiFunctionSignature: isYes ? 'buyYes(uint256)' : 'buyNo(uint256)',
      abiParameters: [amountMicro],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    const txId = txRes.data.id;
    res.json({ txId, state: txRes.data.state, side, balance: info.usdcBalance });

    await saveTrade(userId, {
      tx_id: txId,
      side,
      usdc_amount: amount,
      entry_price: parseFloat(req.body.entryPrice ?? 0.5),
      question: question || 'Prediction Market',
      market_id: MARKET_CONTRACT,
      state: 'INITIATED',
    });
  } catch (e) {
    console.error('trade:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// POST /api/trade/claim — calls claim() on PulsMarket for resolved markets
app.post('/api/trade/claim', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    if (!MARKET_CONTRACT) return res.status(500).json({ error: 'MARKET_CONTRACT not set' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: MARKET_CONTRACT,
      abiFunctionSignature: 'claim()',
      abiParameters: [],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    res.json({ txId: txRes.data.id, state: txRes.data.state });
  } catch (e) {
    console.error('claim:', e.message);
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

app.get('/api/portfolio', async (req, res) => {
  try {
    const { userId } = req.query;
    const rows = await getTrades(userId);
    
    // Map existing rows immediately to return the response in <1ms
    const positions = rows.map((r) => ({
      id: r.id,
      side: r.side,
      usdcAmount: parseFloat(r.usdc_amount ?? 0),
      entryPrice: parseFloat(r.entry_price ?? 0),
      question: r.question,
      state: r.state || 'INITIATED',
      txHash: r.tx_hash,
      timestamp: r.created_at,
    }));

    const completed = positions.filter(p => p.state === 'COMPLETE');
    const totalSpent = completed.reduce((s, p) => s + p.usdcAmount, 0).toFixed(2);
    
    // Return to client immediately (1ms response latency)
    res.json({ positions, totalSpent });

    // Sync any pending (INITIATED/null) states from Circle in the background without blocking the client
    const pendingRows = rows.filter(r => r.state === 'INITIATED' || r.state === null);
    if (pendingRows.length > 0) {
      (async () => {
        for (const r of pendingRows) {
          try {
            const tx = await circle.getTransaction({ id: r.tx_id });
            const state = tx.data.transaction.state;
            const txHash = tx.data.transaction.txHash ?? r.tx_hash;
            await supabase.from('trades').update({ state, tx_hash: txHash }).eq('tx_id', r.tx_id);
          } catch (err) {
            console.error(`Background portfolio sync failed for tx ${r.tx_id}:`, err.message);
          }
        }
      })().catch(console.error);
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (_, res) => res.json({ ok: true }));

// ── Circle Webhook — instant trade state updates ───────────────────────────
app.post('/api/webhook/circle', async (req, res) => {
  res.sendStatus(200); // Acknowledge immediately
  try {
    const { notificationType, transaction } = req.body;
    if (notificationType !== 'transactions.outbound' || !transaction) return;
    const { id: txId, state, txHash } = transaction;
    if (!txId) return;
    // Update trade state in Supabase
    await supabase.from('trades').update({
      state,
      tx_hash: txHash ?? null,
    }).eq('tx_id', txId);
    console.log(`Webhook: tx ${txId} → ${state}`);
  } catch (e) {
    console.error('webhook error:', e.message);
  }
});

// ── Market resolution (owner only) ────────────────────────────────────────
app.post('/api/market/resolve', async (req, res) => {
  try {
    const { userId, outcome } = req.body; // outcome: true=YES wins, false=NO wins
    if (!userId || outcome === undefined) return res.status(400).json({ error: 'userId and outcome required' });
    if (!MARKET_CONTRACT) return res.status(500).json({ error: 'MARKET_CONTRACT not set' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: MARKET_CONTRACT,
      abiFunctionSignature: 'resolve(bool)',
      abiParameters: [outcome],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    res.json({ txId: txRes.data.id, state: txRes.data.state });
  } catch (e) {
    console.error('resolve:', e.message);
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Puls backend :${PORT}`));
