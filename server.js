import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';
import { initiateDeveloperControlledWalletsClient } from '@circle-fin/developer-controlled-wallets';
import { createPublicClient, createWalletClient, http, decodeEventLog } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arcTestnet } from 'viem/chains';

// Prevent unhandled promise rejections from crashing the server
process.on('unhandledRejection', (reason, promise) => {
  console.error('[UNHANDLED REJECTION]', reason?.message || reason);
});

const app = express();
app.use(cors());
app.use(express.json());

const circle = initiateDeveloperControlledWalletsClient({
  apiKey: process.env.CIRCLE_API_KEY ? process.env.CIRCLE_API_KEY.trim() : undefined,
  entitySecret: process.env.CIRCLE_ENTITY_SECRET ? process.env.CIRCLE_ENTITY_SECRET.trim() : undefined,
});

const supabase = createClient(
  process.env.SUPABASE_URL ? process.env.SUPABASE_URL.trim() : '',
  process.env.SUPABASE_SERVICE_KEY ? process.env.SUPABASE_SERVICE_KEY.trim() : '' // use service_role key (server-side only)
);

const USDC = '0x3600000000000000000000000000000000000000';
let walletSetId = (process.env.WALLET_SET_ID || '').trim();

const rpcUrl = (process.env.ARC_RPC_URL || 'https://rpc.testnet.arc.network').trim();
const publicClient = createPublicClient({
  chain: arcTestnet,
  transport: http(rpcUrl)
});

const adminPrivateKey = process.env.PRIVATE_KEY ? process.env.PRIVATE_KEY.trim() : null;
const adminAccount = adminPrivateKey ? privateKeyToAccount(adminPrivateKey.startsWith('0x') ? adminPrivateKey : `0x${adminPrivateKey}`) : null;

const walletClient = adminAccount ? createWalletClient({
  account: adminAccount,
  chain: arcTestnet,
  transport: http(rpcUrl)
}) : null;

const FACTORY_ADDRESS = (process.env.FACTORY_ADDRESS || '').trim();

const FACTORY_ABI = [
  {
    name: 'createMarket',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'slug', type: 'string' },
      { name: 'deadline', type: 'uint256' },
      { name: 'b', type: 'uint256' }
    ],
    outputs: [{ name: 'market', type: 'address' }]
  },
  {
    name: 'allMarkets',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }]
  }
];

// ── Cache of Deployed Markets ────────────────────────────────────────────────
const deployedMarketsCache = new Map(); // slug -> { contractAddress, deadline, resolved, outcome }
const contractToSlugCache = new Map(); // contractAddress -> slug

const MARKET_EVENTS_ABI = [
  {
    anonymous: false,
    name: 'Bought',
    type: 'event',
    inputs: [
      { indexed: true, name: 'user', type: 'address' },
      { indexed: false, name: 'side', type: 'bool' },
      { indexed: false, name: 'amount', type: 'uint256' },
      { indexed: false, name: 'shares', type: 'uint256' }
    ]
  },
  {
    anonymous: false,
    name: 'Sold',
    type: 'event',
    inputs: [
      { indexed: true, name: 'user', type: 'address' },
      { indexed: false, name: 'side', type: 'bool' },
      { indexed: false, name: 'shares', type: 'uint256' },
      { indexed: false, name: 'usdcOut', type: 'uint256' }
    ]
  },
  {
    anonymous: false,
    name: 'Resolved',
    type: 'event',
    inputs: [
      { indexed: false, name: 'outcome', type: 'bool' }
    ]
  },
  {
    anonymous: false,
    name: 'Claimed',
    type: 'event',
    inputs: [
      { indexed: true, name: 'user', type: 'address' },
      { indexed: false, name: 'payout', type: 'uint256' }
    ]
  }
];

// ── Cache of User Wallets ──────────────────────────────────────────────────
const addressToUserIdCache = new Map(); // address (lowercase) -> userId
const userIdToAddressCache = new Map(); // userId -> address (lowercase)

async function loadWalletAddressMapping() {
  try {
    const { data, error } = await supabase
      .from('wallets')
      .select('user_id, wallet_id');
    if (error) {
      console.error('Failed to load wallets for address mapping:', error.message);
      return;
    }
    console.log(`Loading wallet addresses for ${data.length} wallets...`);
    for (const row of data) {
      try {
        const walletId = row.wallet_id;
        const userId = row.user_id;
        
        let address = walletAddressCache.get(walletId);
        if (!address) {
          const walletRes = await circle.getWallet({ id: walletId });
          address = walletRes.data.wallet.address;
          walletAddressCache.set(walletId, address);
        }
        
        const lowerAddress = address.toLowerCase();
        addressToUserIdCache.set(lowerAddress, userId);
        userIdToAddressCache.set(userId, lowerAddress);
      } catch (err) {
        console.error(`Failed to fetch wallet address for user ${row.user_id}:`, err.message);
      }
    }
    console.log(`Loaded ${addressToUserIdCache.size} wallet address mappings.`);
  } catch (e) {
    console.error('loadWalletAddressMapping error:', e.message);
  }
}

async function loadDeployedMarkets() {
  try {
    const { data, error } = await supabase
      .from('deployed_markets')
      .select('*');
    if (error) {
      console.error('Failed to load deployed_markets from Supabase:', error.message);
      return;
    }
    for (const row of (data || [])) {
      const entry = {
        contractAddress: row.contract_address,
        deadline: Number(row.deadline),
        resolved: row.resolved,
        outcome: row.outcome
      };
      deployedMarketsCache.set(row.slug, entry);
      contractToSlugCache.set(row.contract_address.toLowerCase(), row.slug);
    }
    console.log(`Loaded ${deployedMarketsCache.size} deployed markets into cache.`);
  } catch (e) {
    console.error('loadDeployedMarkets error:', e.message);
  }
}

// Prevent duplicate concurrent deployments
const pendingDeployments = new Map();
let deploymentQueue = Promise.resolve();

async function _executeMarketDeployment(slug, deadlineSeconds) {
  let cached = deployedMarketsCache.get(slug);
  if (cached) return cached.contractAddress;

  if (!FACTORY_ADDRESS) throw new Error('FACTORY_ADDRESS not set in backend');
  if (!walletClient || !adminAccount) throw new Error('Admin wallet credentials not configured');

  console.log(`Dynamic deployment triggered for slug: ${slug}, deadline: ${deadlineSeconds}`);
  const b = 10_000_000; // b = 10 USDC
  const initialCost = BigInt(Math.round(b * Math.log(2))); // ~6,931,471

  // Check current allowance first to avoid redundant approvals and race conditions
  const allowance = await publicClient.readContract({
    address: USDC,
    abi: [{
      name: 'allowance',
      type: 'function',
      stateMutability: 'view',
      inputs: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' }
      ],
      outputs: [{ name: '', type: 'uint256' }]
    }],
    functionName: 'allowance',
    args: [adminAccount.address, FACTORY_ADDRESS]
  });

  if (BigInt(allowance) < initialCost) {
    console.log(`Current factory allowance is ${allowance}, less than required ${initialCost}. Approving MaxUint256...`);
    const MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935n;
    const approveHash = await walletClient.writeContract({
      address: USDC,
      abi: [{
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
          { name: 'spender', type: 'address' },
          { name: 'amount', type: 'uint256' }
        ],
        outputs: [{ name: '', type: 'bool' }]
      }],
      functionName: 'approve',
      args: [FACTORY_ADDRESS, MAX]
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log(`✅ Approved factory for MaxUint256 USDC`);
  }

  // Check deployer USDC balance before attempting deployment
  const deployerBalance = await publicClient.readContract({
    address: USDC,
    abi: [{
      name: 'balanceOf',
      type: 'function',
      stateMutability: 'view',
      inputs: [{ name: 'account', type: 'address' }],
      outputs: [{ name: '', type: 'uint256' }]
    }],
    functionName: 'balanceOf',
    args: [adminAccount.address]
  });
  if (BigInt(deployerBalance) < initialCost) {
    console.warn(`⚠️  Deployer USDC balance (${deployerBalance}) < required (${initialCost}) — skipping deployment for ${slug}`);
    throw new Error(`Deployer has insufficient USDC (${deployerBalance} < ${initialCost}) to deploy market ${slug}`);
  }

  const { request } = await publicClient.simulateContract({
    account: adminAccount,
    address: FACTORY_ADDRESS,
    abi: FACTORY_ABI,
    functionName: 'createMarket',
    args: [slug, BigInt(deadlineSeconds), BigInt(b)]
  });

  const hash = await walletClient.writeContract(request);
  console.log(`Deploy Tx Hash: ${hash}`);
  await publicClient.waitForTransactionReceipt({ hash });

  const allM = await publicClient.readContract({
    address: FACTORY_ADDRESS,
    abi: FACTORY_ABI,
    functionName: 'allMarkets'
  });
  
  const deployedAddress = allM[allM.length - 1];
  if (!deployedAddress) throw new Error('Failed to retrieve deployed market address from factory');

  console.log(`✅ Successfully deployed LMSRMarket at ${deployedAddress} for slug ${slug}`);

  await supabase.from('deployed_markets').upsert({
    slug,
    contract_address: deployedAddress,
    deadline: deadlineSeconds,
    resolved: false
  });

  const entry = {
    contractAddress: deployedAddress,
    deadline: deadlineSeconds,
    resolved: false,
    outcome: null
  };
  deployedMarketsCache.set(slug, entry);
  contractToSlugCache.set(deployedAddress.toLowerCase(), slug);

  return deployedAddress;
}

async function getOrDeployMarket(slug, deadlineSeconds) {
  if (!slug) throw new Error('slug is required');
  
  let cached = deployedMarketsCache.get(slug);
  if (cached) return cached.contractAddress;

  if (pendingDeployments.has(slug)) {
    return pendingDeployments.get(slug);
  }

  const promise = new Promise((resolve, reject) => {
    deploymentQueue = deploymentQueue.then(async () => {
      try {
        const addr = await _executeMarketDeployment(slug, deadlineSeconds);
        resolve(addr);
      } catch (err) {
        reject(err);
      }
    }).catch((err) => {
      console.error(`Queue execution failed:`, err.message);
    });
  });

  pendingDeployments.set(slug, promise);
  
  promise.finally(() => {
    pendingDeployments.delete(slug);
  });

  return promise;
}

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

async function isApproved(walletId, contractAddress) {
  try {
    const info = await getWalletInfo(walletId);
    if (!info || !info.address) return false;

    const allowance = await publicClient.readContract({
      address: USDC,
      abi: [{
        name: 'allowance',
        type: 'function',
        stateMutability: 'view',
        inputs: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' }
        ],
        outputs: [{ name: '', type: 'uint256' }]
      }],
      functionName: 'allowance',
      args: [info.address, contractAddress]
    });

    return BigInt(allowance) >= BigInt(1_000_000_000_000);
  } catch (e) {
    console.error('Check allowance failed:', e.message);
    return false;
  }
}

async function saveTrade(userId, trade) {
  await supabase.from('trades').insert({ user_id: userId, ...trade });
}

async function syncCompletedTrade(userId, { marketId, side, amountUsdc, shares, txHash, question, entryPrice }) {
  try {
    const { data: existing, error } = await supabase
      .from('trades')
      .select('*')
      .eq('user_id', userId)
      .eq('market_id', marketId)
      .eq('side', side)
      .eq('state', 'INITIATED')
      .order('created_at', { ascending: false })
      .limit(1);

    if (error) {
      console.error('Error fetching existing trade for sync:', error.message);
    }

    if (existing && existing.length > 0) {
      const trade = existing[0];
      await supabase
        .from('trades')
        .update({
          state: 'COMPLETE',
          tx_hash: txHash,
          usdc_amount: amountUsdc,
        })
        .eq('id', trade.id);
      console.log(`[QuickNode Webhook] Synced initiated trade ID ${trade.id} to COMPLETE`);
    } else {
      const { data: dup } = await supabase
        .from('trades')
        .select('*')
        .eq('tx_hash', txHash)
        .limit(1);
      
      if (dup && dup.length > 0) {
        console.log(`[QuickNode Webhook] Trade for tx ${txHash} already exists, skipping duplicate insert.`);
        return;
      }

      await supabase
        .from('trades')
        .insert({
          user_id: userId,
          tx_id: `ext_${Date.now()}`,
          side,
          usdc_amount: amountUsdc,
          entry_price: entryPrice !== undefined ? entryPrice : (shares !== 0 ? Math.min(0.99, Math.max(0.01, Math.abs(amountUsdc / shares))) : 0.5),
          question: question || 'Prediction Market',
          market_id: marketId,
          state: 'COMPLETE',
          tx_hash: txHash,
        });
      console.log(`[QuickNode Webhook] Inserted new completed trade for tx ${txHash}`);
    }
  } catch (err) {
    console.error('Error syncing completed trade:', err.message);
  }
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
    if (!address) {
      const walletRes = await circle.getWallet({ id: walletId });
      address = walletRes.data.wallet.address;
      walletAddressCache.set(walletId, address);
    }

    let balance = '0.00';
    try {
      const balanceRaw = await publicClient.readContract({
        address: USDC,
        abi: [{
          name: 'balanceOf',
          type: 'function',
          stateMutability: 'view',
          inputs: [{ name: 'account', type: 'address' }],
          outputs: [{ name: '', type: 'uint256' }]
        }],
        functionName: 'balanceOf',
        args: [address]
      });
      balance = (Number(balanceRaw) / 1_000_000).toFixed(2);
    } catch (err) {
      console.warn(`On-chain balance check failed for ${address}:`, err.message);
      try {
        const balRes = await circle.getWalletTokenBalance({ id: walletId });
        const usdcToken = balRes.data.tokenBalances?.find(
          t => t.token?.address?.toLowerCase() === USDC.toLowerCase() || t.token?.symbol === 'USDC'
        );
        balance = parseFloat(usdcToken?.amount ?? '0').toFixed(2);
      } catch (_) {}
    }

    return { walletId, address, usdcBalance: balance };
  } catch (e) {
    console.error('getWalletInfo error:', e.message);
    return { walletId, address: '', usdcBalance: '0.00' };
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
    
    // Cache the address mapping
    if (wallet.address) {
      const lowerAddress = wallet.address.toLowerCase();
      addressToUserIdCache.set(lowerAddress, userId);
      userIdToAddressCache.set(userId, lowerAddress);
      walletAddressCache.set(wallet.id, wallet.address);
    }
    
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
    if (!userId) return res.status(400).json({ error: 'userId required' });

    let userAddress = null;
    if (userId.startsWith('0x')) {
      userAddress = userId;
    } else if (userId.startsWith('eth_0x')) {
      userAddress = userId.replace('eth_', '');
    }

    if (userAddress) {
      let balance = '0.00';
      try {
        const balanceRaw = await publicClient.readContract({
          address: USDC,
          abi: [{
            name: 'balanceOf',
            type: 'function',
            stateMutability: 'view',
            inputs: [{ name: 'account', type: 'address' }],
            outputs: [{ name: '', type: 'uint256' }]
          }],
          functionName: 'balanceOf',
          args: [userAddress]
        });
        balance = (Number(balanceRaw) / 1_000_000).toFixed(2);
      } catch (err) {
        console.warn(`On-chain balance check failed for external wallet ${userAddress}:`, err.message);
      }
      return res.json({ usdcBalance: balance });
    }

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
      rpc: rpcUrl,
      explorer: `https://testnet.arcscan.app/address/${info.address}`,
      note: 'Circle MPC wallet. Private key managed by Circle.',
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── GET /api/markets ──────────────────────────────────────────────────────────
app.get('/api/markets', async (req, res) => {
  try {
    const limit = req.query.limit || 50;
    const offset = req.query.offset || 0;
    
    const pmUrl = `https://gamma-api.polymarket.com/markets?limit=${limit}&active=true&closed=false&order=volume&ascending=false&offset=${offset}`;
    const pmRes = await fetch(pmUrl, { headers: { 'Accept': 'application/json' } });
    
    if (!pmRes.ok) {
      return res.status(500).json({ error: 'Failed to fetch from Polymarket' });
    }
    
    const list = await pmRes.json();
    
    const mergedList = await Promise.all(list.map(async (j) => {
      const slug = j.slug;
      const cached = deployedMarketsCache.get(slug);
      
      let contractAddress = null;
      let poolYes = null;
      let poolNo = null;
      let resolved = false;
      let outcome = null;
      let yesPrice = null;
      let noPrice = null;
      let totalVolume = null;

      if (cached) {
        contractAddress = cached.contractAddress;
        resolved = cached.resolved;
        outcome = cached.outcome;
        
        try {
          const [slugOnChain, deadlineOnChain, resolvedOnChain, outcomeOnChain, yesOutstanding, noOutstanding] = await publicClient.readContract({
            address: contractAddress,
            abi: [
              {
                name: 'getMarketInfo',
                type: 'function',
                stateMutability: 'view',
                inputs: [],
                outputs: [
                  { name: '_slug', type: 'string' },
                  { name: '_deadline', type: 'uint256' },
                  { name: '_resolved', type: 'bool' },
                  { name: '_outcome', type: 'bool' },
                  { name: '_yesOutstanding', type: 'uint256' },
                  { name: '_noOutstanding', type: 'uint256' }
                ]
              }
            ],
            functionName: 'getMarketInfo'
          });

          poolYes = Number(yesOutstanding) / 1_000_000;
          poolNo = Number(noOutstanding) / 1_000_000;
          
          const bVal = 10;
          const maxQ = Math.max(poolYes, poolNo);
          const expYes = Math.exp((poolYes - maxQ) / bVal);
          const expNo = Math.exp((poolNo - maxQ) / bVal);
          yesPrice = expYes / (expYes + expNo);
          noPrice = expNo / (expYes + expNo);
          totalVolume = poolYes + poolNo;
        } catch (err) {
          console.error(`Error reading on-chain market ${contractAddress}:`, err.message);
        }
      }

      let currentPrices = [0.5, 0.5];
      try {
        const rawPrices = j.outcomePrices || '["0.5","0.5"]';
        currentPrices = JSON.parse(rawPrices).map(p => parseFloat(p) || 0.5);
      } catch {}

      return {
        ...j,
        contractAddress,
        yesPrice: yesPrice !== null ? parseFloat(yesPrice.toFixed(4)) : currentPrices[0],
        noPrice: noPrice !== null ? parseFloat(noPrice.toFixed(4)) : currentPrices[1],
        poolYes,
        poolNo,
        resolved,
        outcome,
        totalVolume
      };
    }));

    // Sort: deployed (pre-warmed) markets first for instant trades
    mergedList.sort((a, b) => {
      const aDep = a.contractAddress ? 1 : 0;
      const bDep = b.contractAddress ? 1 : 0;
      return bDep - aDep;
    });

    res.json(mergedList);
  } catch (e) {
    console.error('/api/markets error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// POST /api/market/activate
app.post('/api/market/activate', async (req, res) => {
  try {
    const { slug, deadline } = req.body;
    if (!slug || !deadline) {
      return res.status(400).json({ error: 'slug and deadline required' });
    }
    const contractAddress = await getOrDeployMarket(slug, deadline);
    res.json({ contractAddress });
  } catch (e) {
    console.error('activate market error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// GET /api/market/info
app.get('/api/market/info', async (req, res) => {
  try {
    const { slug } = req.query;
    if (!slug) return res.status(400).json({ error: 'slug required' });
    
    const cached = deployedMarketsCache.get(slug);
    if (!cached) return res.status(404).json({ error: 'Market not deployed' });
    const contractAddress = cached.contractAddress;
    
    const [slugOnChain, deadline, resolved, outcome, yesOutstanding, noOutstanding] = await publicClient.readContract({
      address: contractAddress,
      abi: [
        {
          name: 'getMarketInfo',
          type: 'function',
          stateMutability: 'view',
          inputs: [],
          outputs: [
            { name: '_slug', type: 'string' },
            { name: '_deadline', type: 'uint256' },
            { name: '_resolved', type: 'bool' },
            { name: '_outcome', type: 'bool' },
            { name: '_yesOutstanding', type: 'uint256' },
            { name: '_noOutstanding', type: 'uint256' }
          ]
        }
      ],
      functionName: 'getMarketInfo'
    });

    const poolYesVal = Number(yesOutstanding) / 1_000_000;
    const poolNoVal = Number(noOutstanding) / 1_000_000;
    
    const bVal = 10;
    const maxQ = Math.max(poolYesVal, poolNoVal);
    const expYes = Math.exp((poolYesVal - maxQ) / bVal);
    const expNo = Math.exp((poolNoVal - maxQ) / bVal);
    const yesPrice = expYes / (expYes + expNo);
    const noPrice = expNo / (expYes + expNo);
    const totalPool = poolYesVal + poolNoVal;

    res.json({
      contractAddress,
      question: slug,
      deadline: Number(deadline),
      resolved,
      outcome,
      poolYes: poolYesVal,
      poolNo: poolNoVal,
      yesPrice: parseFloat(yesPrice.toFixed(4)),
      noPrice: parseFloat(noPrice.toFixed(4)),
      totalVolume: totalPool
    });
  } catch (e) {
    console.error('getMarketInfo:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── Trade ─────────────────────────────────────────────────────────────────────

app.post('/api/trade/buy', async (req, res) => {
  try {
    const { userId, side, usdcAmount, question, slug, deadline } = req.body;
    if (!userId || !side || !usdcAmount || !slug || !deadline) return res.status(400).json({ error: 'Missing fields' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    const contractAddress = await getOrDeployMarket(slug, deadline);

    const isYes = side === 'YES';
    const amount = parseFloat(usdcAmount);
    const amountMicro = Math.round(amount * 1_000_000).toString();

    const info = await getWalletInfo(walletId);
    if (parseFloat(info.usdcBalance) < amount) {
      return res.status(400).json({
        error: `Insufficient USDC. Balance: $${info.usdcBalance}, Need: $${amount.toFixed(2)}.`,
      });
    }

    if (!(await isApproved(walletId, contractAddress))) {
      const MAX = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
      try {
        const approveRes = await circle.createContractExecutionTransaction({
          walletId,
          contractAddress: USDC,
          abiFunctionSignature: 'approve(address,uint256)',
          abiParameters: [contractAddress, MAX],
          fee: { type: 'level', config: { feeLevel: 'HIGH' } },
        });
        await new Promise(r => setTimeout(r, 4500));
      } catch (e) {
        console.error('approve error:', e.message);
      }
    }

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: contractAddress,
      abiFunctionSignature: isYes ? 'buyYes(uint256)' : 'buyNo(uint256)',
      abiParameters: [amountMicro],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    const txId = txRes.data.id;

    await saveTrade(userId, {
      tx_id: txId,
      side,
      usdc_amount: amount,
      entry_price: parseFloat(req.body.entryPrice ?? 0.5),
      question: question || 'Prediction Market',
      market_id: contractAddress,
      state: 'INITIATED',
    });

    res.json({ txId, state: txRes.data.state, side, balance: info.usdcBalance });
  } catch (e) {
    console.error('trade buy error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/trade/sell', async (req, res) => {
  try {
    const { userId, side, shares, question, slug, contractAddress: reqContract } = req.body;
    if (!userId || !side || !shares) return res.status(400).json({ error: 'Missing fields' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    // Prefer the position's own contract; fall back to slug -> cache.
    let contractAddress = (reqContract && /^0x[0-9a-fA-F]{40}$/.test(reqContract)) ? reqContract : null;
    if (!contractAddress) {
      const cached = slug ? deployedMarketsCache.get(slug) : null;
      if (!cached) return res.status(400).json({ error: 'Market contract not deployed' });
      contractAddress = cached.contractAddress;
    }

    const isYes = side === 'YES';
    const sharesAmount = parseFloat(shares);
    const sharesMicro = Math.round(sharesAmount * 1_000_000).toString();

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: contractAddress,
      abiFunctionSignature: isYes ? 'sellYes(uint256)' : 'sellNo(uint256)',
      abiParameters: [sharesMicro],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    const txId = txRes.data.id;

    await saveTrade(userId, {
      tx_id: txId,
      side,
      usdc_amount: -sharesAmount,
      entry_price: parseFloat(req.body.entryPrice ?? 0.5),
      question: question || 'Prediction Market',
      market_id: contractAddress,
      state: 'INITIATED',
    });

    res.json({ txId, state: txRes.data.state, side });
  } catch (e) {
    console.error('sell trade error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/trade/claim', async (req, res) => {
  try {
    const { userId, slug, contractAddress: reqContract } = req.body;
    if (!userId) return res.status(400).json({ error: 'Missing fields' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    // Prefer the position's own contract; fall back to slug -> cache.
    let contractAddress = (reqContract && /^0x[0-9a-fA-F]{40}$/.test(reqContract)) ? reqContract : null;
    if (!contractAddress) {
      const cached = slug ? deployedMarketsCache.get(slug) : null;
      if (!cached) return res.status(400).json({ error: 'Market contract not deployed' });
      contractAddress = cached.contractAddress;
    }

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: contractAddress,
      abiFunctionSignature: 'claim()',
      abiParameters: [],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    res.json({ txId: txRes.data.id, state: txRes.data.state });
  } catch (e) {
    console.error('claim error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/trade/status', async (req, res) => {
  try {
    const { txId } = req.query;
    if (!txId) return res.status(400).json({ error: 'txId required' });

    if (txId.startsWith('0x')) {
      // External browser wallet transaction hash
      try {
        const receipt = await publicClient.getTransactionReceipt({ hash: txId });
        if (receipt) {
          const state = receipt.status === 'success' ? 'COMPLETE' : 'FAILED';
          return res.json({ txId, state, txHash: txId });
        }
      } catch (err) {
        // Receipt not found yet (still pending/mining)
        return res.json({ txId, state: 'INITIATED', txHash: txId });
      }
      return res.json({ txId, state: 'INITIATED', txHash: txId });
    }

    const txRes = await circle.getTransaction({ id: txId });
    const tx = txRes.data.transaction;
    res.json({ txId: txRes.data.id, state: tx.state, txHash: tx.txHash });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/trade/save-external', async (req, res) => {
  try {
    const { userId, side, usdcAmount, entryPrice, question, txHash, marketId } = req.body;
    if (!userId || !side || !usdcAmount || !entryPrice || !question || !txHash) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }
    await saveTrade(userId, {
      tx_id: `ext_${Date.now()}`,
      side,
      usdc_amount: parseFloat(usdcAmount),
      entry_price: parseFloat(entryPrice),
      question,
      market_id: marketId,
      state: 'COMPLETE',
      tx_hash: txHash,
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/trade/recent', async (req, res) => {
  try {
    const { limit = 20 } = req.query;
    const limitNum = Math.min(100, parseInt(limit) || 20);
    const { data, error } = await supabase
      .from('trades')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limitNum);

    if (error) {
      console.error('Error fetching recent trades:', error.message);
      return res.status(500).json({ error: error.message });
    }
    res.json(data ?? []);
  } catch (e) {
    console.error('recent trades error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── GET /api/portfolio ────────────────────────────────────────────────────────
app.get('/api/portfolio', async (req, res) => {
  try {
    const { userId } = req.query;
    let userAddress = null;
    if (userId && (userId.startsWith('0x') || userId.startsWith('eth_0x'))) {
      userAddress = userId.replace('eth_', '');
    } else {
      const walletId = await getWalletId(userId);
      const info = walletId ? await getWalletInfo(walletId) : null;
      userAddress = info?.address;
    }

    const rows = await getTrades(userId);

    const terminalStates = ['COMPLETE', 'FAILED', 'CANCELLED', 'DENIED'];
    const pendingRows = rows.filter(r => !r.state || !terminalStates.includes(r.state.toUpperCase()));
    if (pendingRows.length > 0) {
      (async () => {
        for (const r of pendingRows) {
          if (!r.tx_id || r.tx_id.startsWith('ext_')) continue;
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

    let positions = [];
    const uniqueMarkets = [...new Set(rows.map(r => r.market_id).filter(id => id && id.startsWith('0x')))];

    if (userAddress && uniqueMarkets.length > 0) {
      await Promise.all(uniqueMarkets.map(async (marketAddress) => {
        try {
          const [yesSharesRaw, noSharesRaw, claimed] = await publicClient.readContract({
            address: marketAddress,
            abi: [{
              name: 'getUserPosition',
              type: 'function',
              stateMutability: 'view',
              inputs: [{ name: 'user', type: 'address' }],
              outputs: [
                { name: '_yesShares', type: 'uint256' },
                { name: '_noShares', type: 'uint256' },
                { name: '_claimed', type: 'bool' }
              ]
            }],
            functionName: 'getUserPosition',
            args: [userAddress]
          });

          const yesShares = Number(yesSharesRaw) / 1_000_000;
          const noShares = Number(noSharesRaw) / 1_000_000;

          if (yesShares < 0.0001 && noShares < 0.0001) return;

          const slug = contractToSlugCache.get(marketAddress.toLowerCase()) || '';
          
          let question = 'Prediction Market';
          let resolved = false;
          let outcome = null;
          
          const cached = slug ? deployedMarketsCache.get(slug) : null;
          if (cached) {
            resolved = cached.resolved;
            outcome = cached.outcome;
          }

          const tradeForMarket = rows.find(r => r.market_id === marketAddress);
          if (tradeForMarket && tradeForMarket.question) {
            question = tradeForMarket.question;
          }

          const completedTrades = rows.filter(r => r.state === 'COMPLETE' && r.market_id === marketAddress);
          const yesCost = completedTrades.filter(r => r.side === 'YES').reduce((sum, r) => sum + parseFloat(r.usdc_amount ?? 0), 0);
          const noCost = completedTrades.filter(r => r.side === 'NO').reduce((sum, r) => sum + parseFloat(r.usdc_amount ?? 0), 0);

          if (yesShares > 0.0001) {
            const entryPrice = yesCost > 0 ? Math.min(0.99, Math.max(0.01, yesCost / yesShares)) : 0.5;
            positions.push({
              id: `${userId}-${marketAddress}-YES`,
              side: 'YES',
              usdcAmount: yesCost > 0 ? yesCost : yesShares * entryPrice,
              entryPrice: entryPrice,
              shares: yesShares,
              question,
              slug,
              marketId: marketAddress,
              contractAddress: marketAddress,
              state: 'COMPLETE',
              claimed,
              resolved,
              outcome,
              txHash: completedTrades.find(r => r.side === 'YES')?.tx_hash || null,
              timestamp: completedTrades.find(r => r.side === 'YES')?.created_at || new Date().toISOString()
            });
          }

          if (noShares > 0.0001) {
            const entryPrice = noCost > 0 ? Math.min(0.99, Math.max(0.01, noCost / noShares)) : 0.5;
            positions.push({
              id: `${userId}-${marketAddress}-NO`,
              side: 'NO',
              usdcAmount: noCost > 0 ? noCost : noShares * entryPrice,
              entryPrice: entryPrice,
              shares: noShares,
              question,
              slug,
              marketId: marketAddress,
              contractAddress: marketAddress,
              state: 'COMPLETE',
              claimed,
              resolved,
              outcome,
              txHash: completedTrades.find(r => r.side === 'NO')?.tx_hash || null,
              timestamp: completedTrades.find(r => r.side === 'NO')?.created_at || new Date().toISOString()
            });
          }
        } catch (err) {
          console.error(`Failed to read position for user ${userAddress} on market ${marketAddress}:`, err.message);
        }
      }));
    }

    const pendingTrades = rows.filter(r => !r.state || !terminalStates.includes(r.state.toUpperCase()));
    for (const r of pendingTrades) {
      positions.push({
        id: r.id,
        side: r.side,
        usdcAmount: parseFloat(r.usdc_amount ?? 0),
        entryPrice: parseFloat(r.entry_price ?? 0),
        question: r.question,
        marketId: r.market_id,
        contractAddress: r.market_id,
        state: r.state || 'INITIATED',
        txHash: r.tx_hash || null,
        timestamp: r.created_at,
        shares: Math.abs(parseFloat(r.usdc_amount ?? 0)) / parseFloat(r.entry_price ?? 0.5)
      });
    }

    const completed = positions.filter(p => p.state === 'COMPLETE');
    const totalSpent = completed.reduce((s, p) => s + p.usdcAmount, 0).toFixed(2);
    
    res.json({ positions, totalSpent });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/health', (_, res) => res.json({ ok: true }));

// ── Circle Webhook ────────────────────────────────────────────────────────────
app.post('/api/webhook/circle', async (req, res) => {
  res.sendStatus(200);
  try {
    const { notificationType, transaction } = req.body;
    if (notificationType !== 'transactions.outbound' || !transaction) return;
    const { id: txId, state, txHash } = transaction;
    if (!txId) return;
    await supabase.from('trades').update({
      state,
      tx_hash: txHash ?? null,
    }).eq('tx_id', txId);
    console.log(`Webhook: tx ${txId} → ${state}`);
  } catch (e) {
    console.error('webhook error:', e.message);
  }
});

// ── QuickNode Webhook ─────────────────────────────────────────────────────────

async function handleQuickNodeLog(log) {
  try {
    const contractAddress = log.address.toLowerCase();
    const slug = contractToSlugCache.get(contractAddress);
    if (!slug) {
      console.log(`[QuickNode Webhook] Ignoring log from non-market address: ${contractAddress}`);
      return;
    }

    let decoded;
    try {
      decoded = decodeEventLog({
        abi: MARKET_EVENTS_ABI,
        data: log.data,
        topics: log.topics,
      });
    } catch (err) {
      console.warn(`[QuickNode Webhook] Failed to decode event log at address ${contractAddress}:`, err.message);
      return;
    }

    const { eventName, args } = decoded;
    console.log(`[QuickNode Webhook] Received ${eventName} event on market ${slug} (${contractAddress})`);

    let question = slug.split('-').join(' ');
    if (question.length > 0) {
      question = question.charAt(0).toUpperCase() + question.slice(1);
    }

    if (eventName === 'Bought') {
      const userAddress = args.user.toLowerCase();
      const userId = addressToUserIdCache.get(userAddress) || `eth_${userAddress}`;
      const side = args.side ? 'YES' : 'NO';
      const amountUsdc = Number(args.amount) / 1_000_000;
      const shares = Number(args.shares) / 1_000_000;
      const entryPrice = shares !== 0 ? Math.min(0.99, Math.max(0.01, amountUsdc / shares)) : 0.5;

      await syncCompletedTrade(userId, {
        marketId: contractAddress,
        side,
        amountUsdc,
        shares,
        txHash: log.transactionHash,
        question,
        entryPrice
      });
    } else if (eventName === 'Sold') {
      const userAddress = args.user.toLowerCase();
      const userId = addressToUserIdCache.get(userAddress) || `eth_${userAddress}`;
      const side = args.side ? 'YES' : 'NO';
      const shares = Number(args.shares) / 1_000_000;
      const usdcOut = Number(args.usdcOut) / 1_000_000;
      const amountUsdc = -shares; // Sells are stored as negative shares in the database
      const exitPrice = shares !== 0 ? Math.min(0.99, Math.max(0.01, usdcOut / shares)) : 0.5;

      await syncCompletedTrade(userId, {
        marketId: contractAddress,
        side,
        amountUsdc,
        shares,
        txHash: log.transactionHash,
        question,
        entryPrice: exitPrice
      });
    } else if (eventName === 'Resolved') {
      const outcome = args.outcome;
      console.log(`[QuickNode Webhook] Market ${slug} resolved on-chain to outcome: ${outcome ? 'YES' : 'NO'}`);
      
      const { error } = await supabase
        .from('deployed_markets')
        .update({ resolved: true, outcome })
        .eq('contract_address', contractAddress);
        
      if (error) {
        console.error(`[QuickNode Webhook] Failed to update resolved state in Supabase for ${slug}:`, error.message);
      } else {
        const cached = deployedMarketsCache.get(slug);
        if (cached) {
          cached.resolved = true;
          cached.outcome = outcome;
        }
        console.log(`[QuickNode Webhook] Successfully updated resolved state in DB & cache for ${slug}`);
      }
    } else if (eventName === 'Claimed') {
      const userAddress = args.user.toLowerCase();
      const userId = addressToUserIdCache.get(userAddress) || `eth_${userAddress}`;
      const txHash = log.transactionHash;

      const { data: dup } = await supabase
        .from('trades')
        .select('*')
        .eq('tx_hash', txHash)
        .limit(1);

      if (dup && dup.length > 0) {
        console.log(`[QuickNode Webhook] Claim event for tx ${txHash} already exists, skipping.`);
        return;
      }

      const { error } = await supabase
        .from('trades')
        .insert({
          user_id: userId,
          tx_id: `ext_${Date.now()}`,
          side: 'CLAIM',
          usdc_amount: 0,
          entry_price: 0,
          question: 'Claim Winnings',
          market_id: contractAddress,
          state: 'COMPLETE',
          tx_hash: txHash,
        });

      if (error) {
        console.error(`[QuickNode Webhook] Failed to insert CLAIM trade for user ${userId}:`, error.message);
      } else {
        console.log(`[QuickNode Webhook] Successfully recorded CLAIM trade for user ${userId} and tx ${txHash}`);
      }
    }
  } catch (err) {
    console.error(`[QuickNode Webhook] Error processing single log:`, err.message);
  }
}

app.post('/api/webhook/quicknode', async (req, res) => {
  try {
    const webhookSecret = process.env.QUICKNODE_WEBHOOK_SECRET;
    if (webhookSecret) {
      const headerSecret = req.headers['x-qn-secret'];
      const querySecret = req.query.secret;
      if (headerSecret !== webhookSecret && querySecret !== webhookSecret) {
        console.warn(`[QuickNode Webhook] Unauthorized request received. Secret mismatch.`);
        return res.status(401).json({ error: 'Unauthorized' });
      }
    }

    const payload = req.body;
    
    if (Array.isArray(payload)) {
      console.log(`[QuickNode Webhook] Received array of ${payload.length} logs.`);
      for (const log of payload) {
        await handleQuickNodeLog(log);
      }
    } else if (payload && typeof payload === 'object') {
      console.log(`[QuickNode Webhook] Received single log payload.`);
      await handleQuickNodeLog(payload);
    } else {
      console.warn(`[QuickNode Webhook] Unknown or empty payload format received.`);
    }

    res.status(200).json({ ok: true });
  } catch (err) {
    console.error(`[QuickNode Webhook] Error handling request:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Market resolution (owner fallback / manual) ──────────────────────────────
app.post('/api/market/resolve', async (req, res) => {
  try {
    const { userId, slug, outcome } = req.body; // outcome: true=YES wins, false=NO wins
    if (!userId || !slug || outcome === undefined) return res.status(400).json({ error: 'userId, slug and outcome required' });

    const walletId = await getWalletId(userId);
    if (!walletId) return res.status(400).json({ error: 'No wallet' });

    const cached = deployedMarketsCache.get(slug);
    if (!cached) return res.status(400).json({ error: 'Market contract not deployed' });
    const contractAddress = cached.contractAddress;

    const txRes = await circle.createContractExecutionTransaction({
      walletId,
      contractAddress: contractAddress,
      abiFunctionSignature: 'resolve(bool)',
      abiParameters: [outcome],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });

    res.json({ txId: txRes.data.id, state: txRes.data.state });
  } catch (e) {
    console.error('resolve error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

// ── Auto-Resolution Cron ──────────────────────────────────────────────────────
async function checkAndResolveMarkets() {
  console.log('Running auto-resolution cron check...');
  const now = Math.floor(Date.now() / 1000);
  
  const marketsToResolve = [];
  for (const [slug, entry] of deployedMarketsCache.entries()) {
    if (entry.deadline < now && !entry.resolved) {
      marketsToResolve.push({ slug, ...entry });
    }
  }

  if (marketsToResolve.length === 0) {
    console.log('No markets need resolution.');
    return;
  }

  console.log(`Found ${marketsToResolve.length} markets to check for resolution.`);

  for (const market of marketsToResolve) {
    try {
      const pmUrl = `https://gamma-api.polymarket.com/markets?slug=${market.slug}`;
      const res = await fetch(pmUrl);
      if (!res.ok) continue;
      
      const list = await res.json();
      if (!list || list.length === 0) continue;
      
      const pmMarket = list[0];
      const isResolved = pmMarket.closed === true || pmMarket.resolved === true;
      if (!isResolved) {
        console.log(`Market ${market.slug} is past deadline but not yet resolved on Polymarket.`);
        continue;
      }
      
      let outcome = null;
      if (pmMarket.consensusOutcome === 'YES') {
        outcome = true;
      } else if (pmMarket.consensusOutcome === 'NO') {
        outcome = false;
      } else {
        try {
          const prices = JSON.parse(pmMarket.outcomePrices || '[]');
          if (parseFloat(prices[0]) > 0.9) outcome = true;
          else if (parseFloat(prices[1]) > 0.9) outcome = false;
        } catch {}
      }

      if (outcome === null) {
        console.log(`Could not determine outcome for resolved market ${market.slug}`);
        continue;
      }

      console.log(`Resolving on-chain market ${market.contractAddress} for slug ${market.slug} to outcome: ${outcome ? 'YES' : 'NO'}`);

      const { request } = await publicClient.simulateContract({
        account: adminAccount,
        address: market.contractAddress,
        abi: [
          {
            name: 'resolve',
            type: 'function',
            stateMutability: 'nonpayable',
            inputs: [{ name: '_outcome', type: 'bool' }],
            outputs: []
          }
        ],
        functionName: 'resolve',
        args: [outcome]
      });

      const hash = await walletClient.writeContract(request);
      console.log(`Resolution Tx Hash: ${hash}`);
      await publicClient.waitForTransactionReceipt({ hash });
      
      await supabase
        .from('deployed_markets')
        .update({ resolved: true, outcome })
        .eq('slug', market.slug);

      market.resolved = true;
      market.outcome = outcome;
      console.log(`✅ Deployed market ${market.slug} resolved successfully.`);
    } catch (e) {
      console.error(`Failed to resolve market ${market.slug}:`, e.message);
    }
  }
}

// Run resolution check every 5 minutes
setInterval(checkAndResolveMarkets, 5 * 60 * 1000);

async function warmupTopMarkets() {
  console.log('Starting eager market warmup for top active markets...');
  try {
    const limit = 20;
    const pmUrl = `https://gamma-api.polymarket.com/markets?limit=${limit}&active=true&closed=false&order=volume&ascending=false`;
    const pmRes = await fetch(pmUrl, { headers: { 'Accept': 'application/json' } });
    if (!pmRes.ok) {
      console.error('Failed to fetch top markets for warmup:', pmRes.statusText);
      return;
    }
    const list = await pmRes.json();
    console.log(`Fetched ${list.length} top active markets for warmup.`);

    for (const j of list) {
      const slug = j.slug;
      if (!slug) continue;

      if (deployedMarketsCache.has(slug)) {
        // Already deployed
        continue;
      }

      // Parse deadline
      const endRaw = j.endDate || j.endDateIso;
      let deadlineSeconds = Math.floor(Date.now() / 1000) + 30 * 24 * 3600; // default 30 days
      if (endRaw) {
        const parsedDate = new Date(endRaw);
        if (!isNaN(parsedDate.getTime())) {
          deadlineSeconds = Math.floor(parsedDate.getTime() / 1000);
        }
      }

      console.log(`Warming up market: ${slug} (deadline: ${deadlineSeconds})`);
      try {
        await getOrDeployMarket(slug, deadlineSeconds);
      } catch (err) {
        console.error(`Failed to warm up market ${slug}:`, err.message);
      }
    }
    console.log('Eager market warmup completed.');
  } catch (e) {
    console.error('warmupTopMarkets error:', e.message);
  }
}

// ── Agentic Economy (ERC-8004 + autonomous trading) ───────────────────────────

const LLM_URL = (process.env.AGENT_LLM_URL || 'https://opengateway.gitlawb.com/v1/chat/completions').trim();
const LLM_KEY = (process.env.AGENT_LLM_KEY || '').trim();
const LLM_MODEL = (process.env.AGENT_MODEL || 'mimo-v2.5-pro').trim();
const IDENTITY_REGISTRY = '0x8004A818BFB912233c491871b3d84c89A494BD9e';
const AGENT_METADATA_URI = 'ipfs://bafkreibdi6623n3xpf7ymk62ckb4bo75o3qemwkpfvp5i25j66itxvsoei';

async function getAgent(userId) {
  const walletId = await getWalletId(`agent_${userId}`);
  if (!walletId) return null;
  const info = await getWalletInfo(walletId);
  return { walletId, address: info.address, balance: info.usdcBalance };
}

// In-memory guard so we only register each agent on ERC-8004 once per process.
const registeredAgents = new Set();

// Streams an OpenAI-compatible SSE chat completion and returns the full text.
async function llmComplete(messages) {
  if (!LLM_KEY) throw new Error('Agent LLM key not configured');
  const r = await fetch(LLM_URL, {
    method: 'POST',
    headers: { authorization: `Bearer ${LLM_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: LLM_MODEL, messages, stream: true }),
  });
  if (!r.ok) throw new Error(`LLM ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const reader = r.body.getReader();
  const dec = new TextDecoder();
  let buf = '', out = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    const lines = buf.split('\n');
    buf = lines.pop() ?? '';
    for (const line of lines) {
      const s = line.trim();
      if (!s.startsWith('data:')) continue;
      const payload = s.slice(5).trim();
      if (payload === '[DONE]') continue;
      try {
        const j = JSON.parse(payload);
        const c = j.choices?.[0]?.delta?.content;
        if (c) out += c;
      } catch (_) {}
    }
  }
  return out.trim();
}

// Create (or fetch) a separate per-user agent wallet, funded from the user up to budget.
app.post('/api/agent/start', async (req, res) => {
  try {
    const { userId, budget } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    const budgetNum = Math.max(0, parseFloat(budget ?? '0'));
    const agentKey = `agent_${userId}`;

    let agentWalletId = await getWalletId(agentKey);
    let agentAddress;
    if (!agentWalletId) {
      const setId = await ensureWalletSet();
      const createRes = await circle.createWallets({
        accountType: 'EOA', blockchains: ['ARC-TESTNET'], count: 1, walletSetId: setId,
      });
      const w = createRes.data.wallets[0];
      agentWalletId = w.id;
      agentAddress = w.address;
      await saveWallet(agentKey, w.id);
    } else {
      agentAddress = (await getWalletInfo(agentWalletId)).address;
    }

    // Fund the agent wallet from the user's wallet up to the requested budget.
    // The agent's USDC balance IS the budget cap — it cannot spend more than it holds.
    const userWalletId = await getWalletId(userId);
    let funded = 0;
    if (userWalletId && budgetNum > 0) {
      const current = parseFloat((await getWalletInfo(agentWalletId)).usdcBalance) || 0;
      const need = budgetNum - current;
      if (need > 0.01) {
        try {
          const tx = await circle.createTransaction({
            walletId: userWalletId,
            tokenAddress: USDC,
            blockchain: 'ARC-TESTNET',
            destinationAddress: agentAddress,
            amount: [need.toFixed(6)],
            fee: { type: 'level', config: { feeLevel: 'MEDIUM' } },
          });
          funded = need;
          // Wait for the transfer to settle so the agent balance reflects the funds.
          const txId = tx.data?.id;
          for (let i = 0; txId && i < 20; i++) {
            await new Promise(r => setTimeout(r, 1500));
            const st = await circle.getTransaction({ id: txId });
            const s = st.data?.transaction?.state;
            if (s === 'COMPLETE') break;
            if (s === 'FAILED' || s === 'DENIED') { funded = 0; break; }
          }
        } catch (e) {
          console.error('agent funding error:', e.message);
        }
      }
    }

    // ERC-8004: register the agent's onchain identity once per process.
    let registered = registeredAgents.has(agentKey);
    if (!registered) {
      try {
        await circle.createContractExecutionTransaction({
          walletId: agentWalletId,
          contractAddress: IDENTITY_REGISTRY,
          abiFunctionSignature: 'register(string)',
          abiParameters: [AGENT_METADATA_URI],
          fee: { type: 'level', config: { feeLevel: 'MEDIUM' } },
        });
        registeredAgents.add(agentKey);
        registered = true;
      } catch (e) {
        console.error('ERC-8004 register error:', e.message);
      }
    }

    const balance = parseFloat((await getWalletInfo(agentWalletId)).usdcBalance) || 0;
    res.json({
      agentAddress,
      budget: balance + funded, // reflects post-funding balance even before settlement
      balance,
      funded,
      registered,
      identityRegistry: IDENTITY_REGISTRY,
    });
  } catch (e) {
    console.error('agent start error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/agent/status', async (req, res) => {
  try {
    const agent = await getAgent(req.query.userId);
    if (!agent) return res.json({ exists: false });
    res.json({
      exists: true,
      agentAddress: agent.address,
      balance: agent.balance,
      registered: registeredAgents.has(`agent_${req.query.userId}`),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Chat with the agent. The LLM returns a structured intent; the backend validates
// budget + market and executes the buy autonomously from the agent wallet.
app.post('/api/agent/chat', async (req, res) => {
  try {
    const { userId, message } = req.body;
    if (!userId || !message) return res.status(400).json({ error: 'userId and message required' });

    const agent = await getAgent(userId);
    if (!agent) return res.status(400).json({ error: 'Agent not started' });

    // Budget = the agent wallet's own balance (on-chain cap, cannot overspend).
    const remaining = parseFloat(agent.balance) || 0;

    // Pull the live feed (same source as /api/markets) so the agent knows real markets.
    // Mark which are already deployed (instant) and keep their deadline for on-demand deploy.
    let feed = [];
    try {
      const pmRes = await fetch('https://gamma-api.polymarket.com/markets?limit=40&active=true&closed=false&order=volume&ascending=false', { headers: { Accept: 'application/json' } });
      if (pmRes.ok) {
        const list = await pmRes.json();
        feed = list.map(j => {
          const slug = j.slug;
          const cached = deployedMarketsCache.get(slug);
          const endRaw = j.endDate || j.endDateIso;
          const deadline = endRaw ? Math.floor(new Date(endRaw).getTime() / 1000) : Math.floor(Date.now() / 1000) + 30 * 86400;
          return { slug, question: j.question || slug, deployed: !!cached, deadline };
        }).filter(m => m.slug);
        // Deployed-first so the LLM tends to pick instant markets.
        feed.sort((a, b) => (b.deployed ? 1 : 0) - (a.deployed ? 1 : 0));
        feed = feed.slice(0, 25);
      }
    } catch (e) {
      console.error('agent feed fetch error:', e.message);
    }
    const feedBySlug = Object.fromEntries(feed.map(m => [m.slug, m]));

    const marketLines = feed.map(m => `- ${m.slug}: "${m.question}"${m.deployed ? ' [ready]' : ''}`).join('\n');
    const sys = `You are Puls Agent, an autonomous trading agent on Arc Testnet with ${remaining.toFixed(2)} USDC to spend.
These are the live prediction markets you can trade (slug: question):
${marketLines || '(none available)'}
When the user wants you to buy, pick the most relevant market and respond with ONE line of JSON only:
{"action":"buy","slug":"<exact slug from the list>","side":"YES|NO","usdcAmount":<number <= ${remaining.toFixed(2)}>,"reply":"<short explanation of your pick>"}
Otherwise respond: {"action":"none","reply":"<your message>"}
Never exceed your budget. Prefer markets marked [ready]. Output ONLY the JSON object.`;

    let intent = { action: 'none', reply: '' };
    try {
      const raw = await llmComplete([
        { role: 'system', content: sys },
        { role: 'user', content: message },
      ]);
      const m = raw.match(/\{[\s\S]*\}/);
      if (m) intent = JSON.parse(m[0]);
      else intent.reply = raw;
    } catch (e) {
      return res.status(502).json({ error: `LLM error: ${e.message}` });
    }

    // Validate + execute autonomously within budget.
    let trade = null;
    let spentNow = 0;
    if (intent.action === 'buy') {
      const slug = intent.slug;
      const amount = parseFloat(intent.usdcAmount);
      const side = intent.side === 'NO' ? 'NO' : 'YES';
      const market = feedBySlug[slug] || (deployedMarketsCache.has(slug) ? { slug, deadline: deployedMarketsCache.get(slug).deadline } : null);
      if (!market) {
        intent.reply = `I can't trade "${slug}" — it isn't in the live feed.`;
      } else if (!(amount > 0) || amount > remaining) {
        intent.reply = `That would exceed my remaining budget of ${remaining.toFixed(2)} USDC.`;
      } else {
        try {
          // Deploy-on-demand if needed (instant if already deployed).
          const contractAddress = await getOrDeployMarket(slug, market.deadline);
          const amountMicro = Math.round(amount * 1_000_000).toString();
          if (!(await isApproved(agent.walletId, contractAddress))) {
            const MAX = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
            await circle.createContractExecutionTransaction({
              walletId: agent.walletId, contractAddress: USDC,
              abiFunctionSignature: 'approve(address,uint256)', abiParameters: [contractAddress, MAX],
              fee: { type: 'level', config: { feeLevel: 'HIGH' } },
            });
            await new Promise(r => setTimeout(r, 4500));
          }
          const txRes = await circle.createContractExecutionTransaction({
            walletId: agent.walletId, contractAddress,
            abiFunctionSignature: side === 'YES' ? 'buyYes(uint256)' : 'buyNo(uint256)',
            abiParameters: [amountMicro],
            fee: { type: 'level', config: { feeLevel: 'HIGH' } },
          });
          await saveTrade(userId, {
            tx_id: txRes.data.id, side, usdc_amount: amount, entry_price: 0.5,
            question: `🤖 Agent: ${market.question || slug}`, market_id: contractAddress, state: 'INITIATED',
          });
          spentNow = amount;
          trade = { slug, side, usdcAmount: amount, txId: txRes.data.id, contractAddress };
        } catch (e) {
          intent.reply = `Trade failed: ${e.message}`;
        }
      }
    }

    res.json({ reply: intent.reply || 'Done.', trade, remaining: Math.max(0, remaining - spentNow) });
  } catch (e) {
    console.error('agent chat error:', e.message);
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log(`Puls backend :${PORT}`);
  await loadDeployedMarkets();
  loadWalletAddressMapping().catch(console.error);
  checkAndResolveMarkets().catch(console.error);
  warmupTopMarkets().catch(console.error);
});
