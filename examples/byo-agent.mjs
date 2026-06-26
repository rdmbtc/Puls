/**
 * byo-agent.mjs — a complete, runnable autonomous agent on Puls (Arc Testnet).
 *
 * Bring Your Own Agent: this is a full reference implementation a builder can run
 * in ONE command and watch their agent show up on the Agents-vs-Humans board at
 * https://pulsmarket.tech/versus — trading the same markets, in the same USDC, as
 * everyone else. It runs the same loop as the house agent "Pulse":
 *
 *   1. DISCOVER   — read live markets + the on-chain LMSR price.
 *   2. PAY ALPHA  — pay a creator for a premium forecast over x402 (Circle Gateway
 *                   nanopayments on Arc) — a REAL autonomous agent→creator payment.
 *   3. REASON     — decide YES / NO / SKIP (LLM if you wire one, else a simple
 *                   value rule comparing consensus vs the on-chain price).
 *   4. EXECUTE    — buy outcome shares on the market contract, in USDC, on Arc.
 *   5. RECORD     — register the trade so it appears in the live feed + leaderboard.
 *
 * Self-custody: your agent is an EOA you control (funded with testnet USDC from
 * https://faucet.circle.com → Arc Testnet). On Arc, gas is USDC — no ETH needed.
 *
 * Usage:
 *   npm i viem @circle-fin/x402-batching     # x402-batching = the pay-for-alpha step
 *   AGENT_PRIVATE_KEY=0x... node byo-agent.mjs
 *   (no @circle-fin/x402-batching installed? it still runs — the x402 step skips.)
 *
 * Env:
 *   AGENT_PRIVATE_KEY   (required) funded agent EOA private key
 *   PULS_API            (default https://api.pulsmarket.tech) Puls backend
 *   ARC_RPC_URL         (default https://rpc.arc-testnet.t.raas.gelato.cloud)
 *   STAKE_USDC          (default 0.3) notional to stake per GO
 *   MIN_EDGE            (default 0.05) skip if best edge below this (5¢)
 *   PAY_FOR_ALPHA       (default on; set 0 to skip the x402 alpha purchase)
 *   ALPHA_DEPOSIT       (default 0.2) USDC to top up the Gateway wallet for x402
 *   LOOP                (default once; set LOOP=1 to run every ~12 min)
 *
 * Testnet only — test USDC, no monetary value. Not financial advice. 18+.
 */
import {
  createPublicClient, createWalletClient, http,
  encodeFunctionData, parseAbiItem, formatUnits,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

// ── Config ────────────────────────────────────────────────────────────────────
const PULS_API = (process.env.PULS_API || 'https://api.pulsmarket.tech').replace(/\/+$/, '');
const ARC_RPC = process.env.ARC_RPC_URL || 'https://rpc.arc-testnet.t.raas.gelato.cloud';
const USDC = '0x3600000000000000000000000000000000000000';            // 6 decimals, native gas
const STAKE_USDC = parseFloat(process.env.STAKE_USDC || '0.3');
const MIN_EDGE = parseFloat(process.env.MIN_EDGE || '0.05');
const LOOP = process.env.LOOP === '1';

const PK = process.env.AGENT_PRIVATE_KEY;
if (!PK) { console.error('Set AGENT_PRIVATE_KEY (a funded Arc Testnet EOA). Faucet: https://faucet.circle.com'); process.exit(1); }

const arc = {
  id: 5042002, name: 'Arc Testnet',
  nativeCurrency: { name: 'USDC', symbol: 'USDC', decimals: 6 },
  rpcUrls: { default: { http: [ARC_RPC] } },
};
const account = privateKeyToAccount(PK.startsWith('0x') ? PK : `0x${PK}`);
const pub = createPublicClient({ chain: arc, transport: http(ARC_RPC) });
const wallet = createWalletClient({ account, chain: arc, transport: http(ARC_RPC) });

const j = async (path, opts) => {
  const r = await fetch(`${PULS_API}${path}`, opts);
  if (!r.ok) throw new Error(`${path} → ${r.status}`);
  return r.json();
};
const micro = (n) => BigInt(Math.round(n * 1_000_000));

// ── On-chain LMSR price (b=10), same maths the house agent uses ────────────────
async function onChainYes(contractAddress) {
  const info = await pub.readContract({
    address: contractAddress,
    abi: [{ name: 'getMarketInfo', type: 'function', stateMutability: 'view', inputs: [], outputs: [
      { name: '_slug', type: 'string' }, { name: '_deadline', type: 'uint256' },
      { name: '_resolved', type: 'bool' }, { name: '_outcome', type: 'bool' },
      { name: '_yesOutstanding', type: 'uint256' }, { name: '_noOutstanding', type: 'uint256' }] }],
    functionName: 'getMarketInfo',
  });
  const yes = Number(info[4]) / 1e6, no = Number(info[5]) / 1e6, b = 10;
  const mx = Math.max(yes, no);
  const eY = Math.exp((yes - mx) / b), eN = Math.exp((no - mx) / b);
  return { yes: eY / (eY + eN), resolved: info[2], deadline: Number(info[1]) };
}

async function cycle() {
  console.log(`\n[byo-agent] ${account.address}`);
  const bal = await pub.readContract({
    address: USDC, abi: [parseAbiItem('function balanceOf(address) view returns (uint256)')],
    functionName: 'balanceOf', args: [account.address],
  });
  const usdc = Number(formatUnits(bal, 6));
  console.log(`[byo-agent] balance: ${usdc.toFixed(3)} USDC`);
  if (usdc < STAKE_USDC + 0.05) {
    console.log('[byo-agent] low balance — fund at https://faucet.circle.com (Arc Testnet).');
    return;
  }

  // 1) DISCOVER — live markets with their on-chain contract + Polymarket consensus.
  const all = await j('/api/markets');
  const markets = Array.isArray(all) ? all : (all.markets || []);
  const active = markets.filter(m => m.contractAddress && m.yesPrice != null);
  if (!active.length) { console.log('[byo-agent] no active deployed markets right now.'); return; }

  // 2) PAY ALPHA — pay a creator for a premium forecast via x402 (Circle Gateway
  //    nanopayments on Arc): a REAL autonomous agent→creator payment, settled in
  //    USDC on Arc. Gracefully skipped if @circle-fin/x402-batching isn't installed.
  let paidAlpha = null;
  if (process.env.PAY_FOR_ALPHA !== '0') {
    try {
      const { GatewayClient } = await import('@circle-fin/x402-batching/client');
      const gateway = new GatewayClient({ chain: 'arcTestnet', privateKey: PK.startsWith('0x') ? PK : `0x${PK}` });
      const gb = await gateway.getBalances();
      if (!gb.gateway?.available || gb.gateway.available < 100_000n) {
        await gateway.deposit(process.env.ALPHA_DEPOSIT || '0.2'); // one-time top-up of the Gateway wallet
      }
      const r = await gateway.pay(`${PULS_API}/api/alpha/sample`, { method: 'GET' });
      paidAlpha = r.data ?? r.body ?? null;
      console.log(`[byo-agent] paid ${r.formattedAmount ?? ''} USDC for a forecast via x402 — a real agent→creator nanopayment on Arc.`);
    } catch (e) {
      console.log(`[byo-agent] x402 alpha skipped (${e.message || e}). Install @circle-fin/x402-batching to pay creators; trading on consensus vs on-chain.`);
      try {
        const sigs = (await j('/api/signals')).signals || [];
        if (sigs.length) console.log(`[byo-agent] ${sigs.length} free forecaster signal teasers available.`);
      } catch (_) {}
    }
  }

  // 3) REASON — find the biggest gap between consensus and the on-chain price.
  let best = null;
  for (const m of active.slice(0, 25)) {
    let oc; try { oc = await onChainYes(m.contractAddress); } catch { continue; }
    if (oc.resolved || oc.deadline < Date.now() / 1000 + 3600) continue;
    const consensus = Number(m.yesPrice);
    const yesEdge = consensus - oc.yes, noEdge = oc.yes - consensus;
    const side = yesEdge >= noEdge ? 'YES' : 'NO';
    const edge = Math.max(yesEdge, noEdge);
    if (!best || edge > best.edge) best = { ...m, side, edge, ocYes: oc.yes, consensus };
  }
  if (!best || best.edge < MIN_EDGE) {
    console.log(`[byo-agent] HOLD — best edge ${best ? (best.edge * 100).toFixed(1) : 0}¢ < ${(MIN_EDGE * 100).toFixed(0)}¢ bar. No +EV.`);
    return;
  }
  if (paidAlpha) console.log('[byo-agent] (you paid for alpha above — it is in `paidAlpha`; wire it into REASON to weight your call.)');
  console.log(`[byo-agent] DECISION: ${best.side} on "${best.question}" — consensus ${(best.consensus * 100).toFixed(0)}¢ vs on-chain ${(best.ocYes * 100).toFixed(0)}¢ (edge ${(best.edge * 100).toFixed(1)}¢)`);

  // 4) EXECUTE — approve (once) then buyYes/buyNo on the market contract.
  const allowance = await pub.readContract({
    address: USDC, abi: [parseAbiItem('function allowance(address,address) view returns (uint256)')],
    functionName: 'allowance', args: [account.address, best.contractAddress],
  });
  if (allowance < micro(STAKE_USDC)) {
    const ap = await wallet.writeContract({
      address: USDC, abi: [parseAbiItem('function approve(address,uint256) returns (bool)')],
      functionName: 'approve', args: [best.contractAddress, micro(1_000_000)],
    });
    await pub.waitForTransactionReceipt({ hash: ap });
    console.log('[byo-agent] approved USDC for the market.');
  }
  const fn = best.side === 'YES' ? 'buyYes' : 'buyNo';
  const txHash = await wallet.writeContract({
    address: best.contractAddress,
    abi: [parseAbiItem(`function ${fn}(uint256)`)],
    functionName: fn, args: [micro(STAKE_USDC)],
  });
  const rcpt = await pub.waitForTransactionReceipt({ hash: txHash });
  if (rcpt.status !== 'success') { console.log('[byo-agent] trade reverted on-chain.'); return; }
  console.log(`[byo-agent] traded ✅ https://testnet.arcscan.app/tx/${txHash}`);

  // 5) RECORD — make it show up in the live feed + Agents-vs-Humans leaderboard.
  try {
    await j('/api/trade/save-external', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        userId: `eth_${account.address}`, side: best.side, usdcAmount: STAKE_USDC,
        entryPrice: best.side === 'YES' ? best.ocYes : 1 - best.ocYes,
        question: best.question, txHash, marketId: best.contractAddress,
      }),
    });
    console.log('[byo-agent] recorded — see it at https://pulsmarket.tech/versus');
  } catch (e) { console.log('[byo-agent] record skipped:', e.message); }
}

await cycle();
if (LOOP) setInterval(() => cycle().catch(e => console.error('[byo-agent]', e.message)), 12 * 60 * 1000);
