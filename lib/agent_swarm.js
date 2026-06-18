/**
 * Agent Swarm — a colony of autonomous AI actors that LIVE inside Pulsmarket.
 *
 * Each agent has its own persona, LLM "brain" (a preferred model in the failover
 * pool), Circle MPC wallet and ERC-8004 on-chain identity. They are full economic
 * actors, just like humans:
 *   • TRADERS research the open web (vision) + on-chain mispricings, may BUY a
 *     peer's Signal (agent→agent x402 USDC), reason with their persona, then
 *     trade a prediction on Arc — or skip with a visible reason.
 *   • CREATORS publish on-chain-attested Signals (SignalRegistry) on rotating
 *     market questions and EARN USDC when other agents buy them.
 *   • Every agent EVALUATES peers' signals with its LLM and COMMENTS publicly —
 *     "accurate, buying ✅" (and pays for it) or "flawed, skipping ❌" (with a
 *     reason) — and comments on markets it trades.
 *
 * This powers an AI-vs-Humans battle: agents and humans trade the same markets,
 * and /api/agents/roster + /api/agents/battle expose who's winning.
 *
 * Additive + env-gated (AGENT_SWARM=true). Reuses the existing Pulse/Sage plumbing
 * passed in via `deps` — it does NOT touch house_pulse / agent_sage.
 */

// Default roster. Override per-agent model via env AGENT_SWARM_MODEL_<KEY>.
// `brain` is a substring matched against the LLM pool model ids (prefer-first,
// still falls back through the whole pool). Personas drive distinct behavior.
const DEFAULT_ROSTER = [
  // ── Trader agents (distinct strategies + brains) ──
  {
    key: 'vega', name: 'Vega ⚡', role: 'trader', brain: 'gpt-oss',
    category: null, minEdge: 0.03, riskMult: 1.4,
    persona: 'an aggressive momentum trader who hunts the biggest mispricings and presses winners hard. Bold, fast, concise.',
  },
  {
    key: 'cygnus', name: 'Cygnus 🛡️', role: 'trader', brain: 'mistral',
    category: null, minEdge: 0.07, riskMult: 0.6,
    persona: 'a conservative value trader who only acts on high-conviction, large edges and sizes small. Skeptical, disciplined.',
  },
  {
    key: 'orion', name: 'Orion 🔭', role: 'trader', brain: 'deepseek',
    category: null, minEdge: 0.05, riskMult: 1.0,
    persona: 'a balanced quant who weighs web sentiment against on-chain price gaps and explains the convergence trade clearly.',
  },
  // ── Creator agents (publish signals, earn from buyers) ──
  {
    key: 'atlas', name: 'Atlas 📈', role: 'creator', brain: 'gemini',
    category: 'crypto',
    persona: 'a crypto/macro forecaster who publishes sharp, falsifiable signals with clear invalidation levels.',
  },
  {
    key: 'nova', name: 'Nova 🌐', role: 'creator', brain: 'mistral',
    category: 'politics',
    persona: 'a world-events analyst who turns live news into calibrated probability calls.',
  },
];

export function buildSwarmRoster() {
  const enabled = (process.env.AGENT_SWARM || 'false') === 'true';
  if (!enabled) return [];
  // Optional allow-list: AGENT_SWARM_KEYS=vega,cygnus,atlas
  const only = (process.env.AGENT_SWARM_KEYS || '').split(',').map(s => s.trim()).filter(Boolean);
  let roster = DEFAULT_ROSTER.slice();
  if (only.length) roster = roster.filter(a => only.includes(a.key));
  for (const a of roster) {
    const m = (process.env[`AGENT_SWARM_MODEL_${a.key.toUpperCase()}`] || '').trim();
    if (m) a.brain = m;
    a.user = `agent_swarm_${a.key}`;        // profiles/trades/notifications user id
    a.walletKey = `agent_${a.user}`;        // wallets row key (matches existing convention)
  }
  return roster;
}

// Per-agent in-memory risk + identity state.
const state = new Map(); // key -> { streak, spentToday, dayKey, registered, signalId, onchainTx, busy, ensured }
function st(key) {
  if (!state.has(key)) state.set(key, { streak: 0, spentToday: 0, dayKey: '', registered: false, signalId: null, onchainTx: null, busy: false, ensured: false });
  return state.get(key);
}
const _todayKey = () => new Date().toISOString().slice(0, 10);

// ───────────────────────────────────────────────────────────────────────────
// Wire-up: server.js calls registerSwarm(app, deps) once. `deps` carries the
// shared helpers/clients so we never re-implement Circle/viem/Supabase logic.
// ───────────────────────────────────────────────────────────────────────────
export function registerSwarm(app, deps) {
  const {
    supabase, circle, walletClient, publicClient, adminAccount,
    getWalletId, saveWallet, getWalletInfo, ensureWalletSet, WALLET_ACCOUNT_TYPE,
    USDC, IDENTITY_REGISTRY, AGENT_METADATA_URI, SIGNAL_REGISTRY_ADDRESS,
    resolveAgentTokenId, recordAgentReputation, agentTokenIds,
    getTreasuryUsdcBalance, houseAgentResearch, executeAgentTrade,
    researchQuestion, llmComplete, parseLlmJson, formatForApp,
    keccak256, toHex,
  } = deps;

  const ROSTER = buildSwarmRoster();
  const MAX_TRADE = parseFloat(process.env.AGENT_SWARM_MAX_TRADE || '0.4');
  const DAILY_CAP = parseFloat(process.env.AGENT_SWARM_DAILY_CAP || '3');
  const INTERVAL_MIN = Math.max(3, parseInt(process.env.AGENT_SWARM_INTERVAL_MIN || '12', 10));
  const ALPHA_PRICE = parseFloat(process.env.AGENT_SWARM_ALPHA_PRICE || '0.001') || 0.001;
  const BOOTSTRAP_USDC = parseFloat(process.env.AGENT_SWARM_BOOTSTRAP_USDC || '1');

  if (ROSTER.length === 0) {
    console.log('[swarm] disabled (set AGENT_SWARM=true to enable)');
    return { tick: async () => {}, roster: [] };
  }
  console.log(`[swarm] ${ROSTER.length} agent(s): ${ROSTER.map(a => `${a.name}(${a.role}/${a.brain})`).join(', ')}`);

  const usdcTransferAbi = [{
    name: 'transfer', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }], outputs: [{ type: 'bool' }],
  }];

  // ── Lifecycle: wallet + profile + ERC-8004, bootstrap-funded once ──────────
  async function ensureAgent(cfg) {
    const s = st(cfg.key);
    let walletId = await getWalletId(cfg.walletKey);
    if (!walletId) {
      const setId = await ensureWalletSet();
      const createRes = await circle.createWallets({
        accountType: WALLET_ACCOUNT_TYPE, blockchains: ['ARC-TESTNET'], count: 1, walletSetId: setId,
      });
      walletId = createRes.data.wallets[0].id;
      await saveWallet(cfg.walletKey, walletId);
      console.log(`[swarm:${cfg.key}] created wallet`);
    }
    let info = await getWalletInfo(walletId);
    let balance = parseFloat(info.usdcBalance) || 0;

    await supabase.from('profiles').upsert({
      user_id: cfg.user,
      display_name: cfg.name,
      bio: `Autonomous ${cfg.role}-agent on Puls — ${cfg.persona} Lives on Arc with its own wallet + ERC-8004 identity.`,
      avatar_url: `https://api.dicebear.com/7.x/bottts/png?size=128&seed=${encodeURIComponent(cfg.key)}`,
    }, { onConflict: 'user_id' });

    // One-time bootstrap funding so the agent can pay gas-as-USDC for ERC-8004
    // + its first trades. Tops up TOWARD a target balance (so a partially-funded
    // agent still reaches a tradable bankroll). Graceful when the treasury is
    // empty (one log, no spam).
    const target = cfg.role === 'creator' ? Math.min(BOOTSTRAP_USDC, 0.6) : BOOTSTRAP_USDC;
    if (!s.ensured && balance < target - 0.05 && walletClient && adminAccount) {
      const need = Math.ceil((target - balance) * 100) / 100;
      try {
        const treasury = await getTreasuryUsdcBalance();
        if (treasury != null && treasury >= need + 1) {
          await walletClient.writeContract({
            address: USDC, abi: usdcTransferAbi, functionName: 'transfer',
            args: [info.address, BigInt(Math.round(need * 1_000_000))],
          });
          await new Promise(r => setTimeout(r, 3000));
          info = await getWalletInfo(walletId);
          balance = parseFloat(info.usdcBalance) || 0;
          console.log(`[swarm:${cfg.key}] funded +${need} USDC (→ ${balance.toFixed(2)})`);
        } else {
          console.log(`[swarm:${cfg.key}] treasury too low to fund +${need} (have ${treasury}); will retry later`);
        }
      } catch (e) { console.error(`[swarm:${cfg.key}] funding error:`, e.message); }
    }

    // ERC-8004 identity (idempotent; needs a little USDC for gas-as-USDC).
    if (!s.registered) {
      const existing = await resolveAgentTokenId(cfg.walletKey, info.address);
      if (existing) {
        s.registered = true;
      } else if (balance >= 0.2) {
        try {
          await circle.createContractExecutionTransaction({
            walletId, contractAddress: IDENTITY_REGISTRY,
            abiFunctionSignature: 'register(string)', abiParameters: [AGENT_METADATA_URI],
            fee: { type: 'level', config: { feeLevel: 'MEDIUM' } },
          });
          await new Promise(r => setTimeout(r, 4000));
          const id = await resolveAgentTokenId(cfg.walletKey, info.address);
          if (id) { s.registered = true; console.log(`[swarm:${cfg.key}] ERC-8004 identity ${id}`); }
        } catch (e) { console.error(`[swarm:${cfg.key}] ERC-8004 register error:`, e.message); }
      }
    }
    s.ensured = true;
    return { walletId, address: info.address, balance };
  }

  // ── Risk sizing (per-agent persona multiplier) ────────────────────────────
  function sizeStake(cfg, balance) {
    const s = st(cfg.key);
    if (s.dayKey !== _todayKey()) { s.dayKey = _todayKey(); s.spentToday = 0; }
    const remainingDaily = Math.max(0, DAILY_CAP - s.spentToday);
    if (remainingDaily < 0.1) return 0;
    const streakMult = s.streak >= 3 ? 1.4 : s.streak === 2 ? 1.2 : s.streak <= -1 ? 0.6 : 1.0;
    let stake = (balance - 0.1) * 0.12 * (cfg.riskMult || 1) * streakMult;
    stake = Math.min(stake, MAX_TRADE, remainingDaily);
    stake = Math.floor(stake * 10) / 10;
    return stake >= 0.1 ? stake : 0;
  }

  // ── A peer's live signal this agent can read/evaluate/buy ──────────────────
  async function pickPeerSignal(cfg) {
    // Prefer signals from OTHER agents (swarm creators + Sage), newest first.
    const { data: rows } = await supabase
      .from('creator_signals')
      .select('id, creator_user_id, title, market_question, stance, confidence, edge_bps, horizon, thesis, price_usdc, onchain_tx')
      .eq('status', 'published')
      .neq('creator_user_id', cfg.user)
      .order('created_at', { ascending: false })
      .limit(8);
    if (!rows || !rows.length) return null;
    return rows[Math.floor(Math.random() * Math.min(rows.length, 4))];
  }

  async function creatorWalletAddress(creatorUserId) {
    const wid = await getWalletId(`agent_${creatorUserId}`);
    if (!wid) return null;
    return (await getWalletInfo(wid))?.address || null;
  }

  // Pay a peer for their signal (agent→agent x402 USDC) + record the sale.
  async function buySignal(cfg, buyerWalletId, buyerAddress, signal) {
    const toAddr = await creatorWalletAddress(signal.creator_user_id);
    if (!toAddr || toAddr.toLowerCase() === String(buyerAddress).toLowerCase()) return null;
    const price = Number(signal.price_usdc) || ALPHA_PRICE;
    try {
      const txRes = await circle.createContractExecutionTransaction({
        walletId: buyerWalletId, contractAddress: USDC,
        abiFunctionSignature: 'transfer(address,uint256)',
        abiParameters: [toAddr, Math.round(price * 1_000_000).toString()],
        fee: { type: 'level', config: { feeLevel: 'HIGH' } },
      });
      const txId = txRes.data?.id || null;
      // Count it as a real signal sale (analytics + revenue).
      supabase.from('signal_unlocks').insert({
        user_id: cfg.user, signal_id: signal.id, status: 'confirmed',
        amount_usdc: price, tx_id: txId, confirmed_at: new Date().toISOString(),
      }).then(({ error }) => { if (error && !String(error.message).includes('duplicate')) console.warn(`[swarm:${cfg.key}] unlock insert:`, error.message); });
      supabase.from('creator_signals').select('unlocks_count, revenue_usdc').eq('id', signal.id).maybeSingle()
        .then(({ data }) => { if (data) supabase.from('creator_signals').update({
          unlocks_count: (data.unlocks_count ?? 0) + 1, revenue_usdc: Number(data.revenue_usdc ?? 0) + price,
        }).eq('id', signal.id).then(() => {}); });
      supabase.from('x402_payments').insert({
        endpoint: 'agent_to_agent', payer: buyerAddress || null, pay_to: toAddr,
        amount_usdc: price.toString(), network: 'eip155:5042002', gateway_tx: txId,
        raw: { kind: 'agent_to_agent', agent: cfg.user, counterparty: signal.creator_user_id, signalId: signal.id },
      }).then(({ error }) => { if (error) console.warn(`[swarm:${cfg.key}] x402 receipt:`, error.message); });
      console.log(`[swarm:${cfg.key}] bought signal ${signal.id} from ${signal.creator_user_id} — ${price} USDC → ${toAddr} (tx ${txId})`);
      return { price, txId, toAddr };
    } catch (e) {
      console.error(`[swarm:${cfg.key}] buySignal failed:`, e.message);
      return null;
    }
  }

  // Post a public comment from the agent (reuses the comments table directly).
  async function postComment(cfg, targetType, targetId, body) {
    try {
      await supabase.from('comments').insert({
        user_id: cfg.user, target_type: targetType, target_id: targetId, body: String(body).slice(0, 500),
      });
    } catch (e) { console.warn(`[swarm:${cfg.key}] comment failed:`, e.message); }
  }

  // LLM-judge a peer's signal → {verdict:'buy'|'skip', comment}.
  async function evaluateSignal(cfg, signal) {
    const sys = `You are ${cfg.name}, ${cfg.persona} You are evaluating ANOTHER agent's published trading Signal on a prediction market. Decide if it's worth buying. Respond with STRICT JSON only: {"verdict":"buy"|"skip","comment":"<one punchy sentence: if buy say it's accurate and you're buying and why; if skip say it's flawed and you're skipping and why>"}`;
    const u = `Signal: "${signal.title}"\nMarket: ${signal.market_question}\nStance: ${signal.stance} | confidence ${(Number(signal.confidence) * 100).toFixed(0)}% | claimed edge ${signal.edge_bps}bps | horizon ${signal.horizon}\nThesis: ${signal.thesis}`;
    try {
      const raw = await llmComplete([{ role: 'system', content: sys }, { role: 'user', content: u }], { prefer: cfg.brain });
      const j = parseLlmJson(raw);
      const verdict = j.verdict === 'buy' ? 'buy' : 'skip';
      return { verdict, comment: formatForApp(String(j.comment || '').slice(0, 240)) };
    } catch (e) {
      // Deterministic fallback: buy if claimed edge is strong.
      const strong = Number(signal.edge_bps) >= 300 && Number(signal.confidence) >= 0.55;
      return {
        verdict: strong ? 'buy' : 'skip',
        comment: strong
          ? `Solid ${signal.stance} thesis with a real edge — accurate, buying. ✅`
          : `Edge looks thin for the confidence claimed — skipping this one. ❌`,
      };
    }
  }

  // ── Trader behavior ────────────────────────────────────────────────────────
  async function runTrader(cfg) {
    const agent = await ensureAgent(cfg);
    if (agent.balance < 0.2) { console.log(`[swarm:${cfg.key}] balance ${agent.balance} too low`); return; }

    // 1) Evaluate + (maybe) buy a peer's signal, leaving a public comment either way.
    let boughtSignal = null, signalCtx = null;
    const peer = await pickPeerSignal(cfg);
    if (peer) {
      const evalRes = await evaluateSignal(cfg, peer);
      await postComment(cfg, 'signal', String(peer.id), evalRes.comment);
      signalCtx = { ...peer, verdict: evalRes.verdict, note: evalRes.comment };
      if (evalRes.verdict === 'buy') {
        boughtSignal = await buySignal(cfg, agent.walletId, agent.address, peer);
      }
    }

    // 2) Research on-chain mispricings (shared helper) + open-web vision.
    const candidates = await houseAgentResearch();
    if (!candidates.length) { console.log(`[swarm:${cfg.key}] no candidates`); return; }
    const top = candidates.slice(0, 5);
    let research = { brief: '', sources: [] };
    try { research = await researchQuestion(top[0].question, 3); } catch (_) {}

    const stake = sizeStake(cfg, agent.balance);
    const bestEdge = top[0].edge;

    // 3) Decide with the agent's persona + brain.
    let decision;
    if (bestEdge < cfg.minEdge || stake < 0.1) {
      decision = {
        action: 'skip', brain: cfg.brain,
        reasoning: bestEdge < cfg.minEdge
          ? `Best edge ${(bestEdge * 100).toFixed(1)}¢ is under my ${(cfg.minEdge * 100).toFixed(0)}¢ bar — holding, no +EV.`
          : `Edge is there but my risk cap/bankroll won't size a safe stake right now — standing down.`,
      };
    } else {
      try {
        const sys = `You are ${cfg.name}, ${cfg.persona} You trade on Puls (Arc Testnet) by comparing Polymarket consensus vs the on-chain LMSR price.${signalCtx ? ` You just reviewed a peer agent's signal (below) and decided to ${signalCtx.verdict} it.` : ''}${research.brief ? ' You also researched the live web (below).' : ''} Pick the single best trade. STRICT JSON only: {"slug":"...","side":"YES"|"NO","reasoning":"<2 sentences in your voice, cite the prices + any web finding>"}`;
        const cText = top.map((c, i) => `${i + 1}. ${c.question}\n   slug: ${c.slug} | PM YES ${(c.pmYes * 100).toFixed(0)}¢ | Arc YES ${(c.onChainYes * 100).toFixed(0)}¢ | cheap: ${c.side} (edge ${(c.edge * 100).toFixed(1)}¢)`).join('\n');
        const sText = signalCtx ? `\n\nPeer signal you ${signalCtx.verdict}: ${signalCtx.title} — ${signalCtx.stance}. ${signalCtx.thesis}` : '';
        const rText = research.brief ? `\n\nLive web on "${top[0].question}":\n${research.brief}` : '';
        const raw = await llmComplete([{ role: 'system', content: sys }, { role: 'user', content: cText + sText + rText }], { prefer: cfg.brain });
        const parsed = parseLlmJson(raw);
        const chosen = top.find(c => c.slug === parsed.slug) || top[0];
        const side = ['YES', 'NO'].includes(parsed.side) ? parsed.side : chosen.side;
        decision = { ...chosen, action: 'go', side, amount: stake, brain: cfg.brain, reasoning: formatForApp(String(parsed.reasoning || '').slice(0, 400)) };
      } catch (e) {
        const c = top[0];
        decision = { ...c, action: 'go', amount: stake, brain: cfg.brain,
          reasoning: `${c.side} is cheap on Arc (${((c.side === 'YES' ? c.onChainYes : 1 - c.onChainYes) * 100).toFixed(0)}¢) vs consensus — capturing the ${(c.edge * 100).toFixed(1)}¢ edge.` };
      }
    }

    const sources = (research.sources || []).slice(0, 3);
    const payload = {
      action: decision.action,
      question: decision.question ?? top[0].question,
      side: decision.side ?? null,
      amount: decision.amount ?? null,
      reasoning: decision.reasoning,
      brain: decision.brain,
      agentKey: cfg.key, agentName: cfg.name, role: 'trader',
      pmYes: decision.pmYes ?? null, onChainYes: decision.onChainYes ?? null, edge: decision.edge ?? null,
      contractAddress: decision.contractAddress ?? null,
      // Signal review + agent→agent buy economics.
      signalReview: signalCtx ? { id: signalCtx.id, title: signalCtx.title, creator: signalCtx.creator_user_id, verdict: signalCtx.verdict, note: signalCtx.note } : null,
      alphaPaid: boughtSignal ? boughtSignal.price : null,
      alphaTxId: boughtSignal ? boughtSignal.txId : null,
      alphaCreator: boughtSignal ? boughtSignal.toAddr : null,
      sources,
    };

    if (decision.action === 'skip') {
      console.log(`[swarm:${cfg.key}] SKIP — ${decision.reasoning}`);
      await supabase.from('notifications').insert({
        user_id: cfg.user, title: 'No +EV trade', type: 'agent_decision', read: true,
        message: JSON.stringify(payload),
      });
      return;
    }

    console.log(`[swarm:${cfg.key}] ${decision.side} $${decision.amount} on ${decision.slug}`);
    const result = await executeAgentTrade(cfg.user, agent.walletId, decision.contractAddress, decision.side, decision.amount, decision.slug);
    if (!result) { console.error(`[swarm:${cfg.key}] trade failed`); return; }
    st(cfg.key).spentToday += Number(decision.amount) || 0;
    payload.txHash = result.txHash;
    await supabase.from('notifications').insert({
      user_id: cfg.user, title: decision.slug, type: 'agent_decision', read: true,
      message: JSON.stringify(payload),
    });
    // Comment on the market it just traded (it lives here like a human).
    await postComment(cfg, 'market', String(decision.contractAddress),
      `Took ${decision.side} here. ${decision.reasoning}`);
    console.log(`[swarm:${cfg.key}] published decision, tx ${result.txHash}`);
  }

  // ── Creator behavior: publish/refresh an on-chain-attested signal ──────────
  const CRYPTO_QS = [
    { t: 'BTC stays above $90k this quarter', q: 'Will BTC hold above $90k through the quarter?', s: 'YES', c: 0.6, e: 420, h: 'this quarter' },
    { t: 'ETH outperforms BTC this month', q: 'Will ETH/BTC rise over the next 30 days?', s: 'NO', c: 0.55, e: 300, h: '30 days' },
  ];
  const POLI_QS = [
    { t: 'Incumbent wins the next major election', q: 'Will the incumbent party retain power in the next major election?', s: 'YES', c: 0.57, e: 350, h: 'next cycle' },
    { t: 'A new global ceasefire holds 30 days', q: 'Will the latest ceasefire hold for 30 days?', s: 'NO', c: 0.58, e: 360, h: '30 days' },
  ];

  async function runCreator(cfg) {
    const agent = await ensureAgent(cfg);
    const s = st(cfg.key);
    // Keep ONE live signal per creator; rotate it occasionally.
    const { data: existing } = await supabase
      .from('creator_signals')
      .select('id, onchain_tx, created_at')
      .eq('creator_user_id', cfg.user).eq('status', 'published')
      .order('created_at', { ascending: false }).limit(1).maybeSingle();
    const ageMs = existing ? Date.now() - new Date(existing.created_at).getTime() : Infinity;
    if (existing && ageMs < 6 * 60 * 60 * 1000) { s.signalId = existing.id; s.onchainTx = existing.onchain_tx; return; }
    if (existing) { // retire the old one before publishing fresh
      await supabase.from('creator_signals').update({ status: 'archived' }).eq('id', existing.id);
    }

    const pool = cfg.category === 'politics' ? POLI_QS : CRYPTO_QS;
    const pick = pool[Math.floor(Math.random() * pool.length)];
    // Let the LLM write the thesis in the creator's voice (best-effort).
    let thesis = `Order-flow and live signals favor ${pick.s} while the implied probability lags. Invalidation: a regime shift against the thesis.`;
    try {
      const raw = await llmComplete([
        { role: 'system', content: `You are ${cfg.name}, ${cfg.persona} Write a 2-sentence falsifiable thesis (with an invalidation level) for this prediction. Plain text only.` },
        { role: 'user', content: `${pick.t} — ${pick.q} (stance ${pick.s})` },
      ], { prefer: cfg.brain });
      if (raw && raw.length > 20) thesis = formatForApp(raw.slice(0, 600));
    } catch (_) {}

    const body = {
      creator_user_id: cfg.user, title: pick.t, market_question: pick.q, stance: pick.s,
      confidence: pick.c, edge_bps: pick.e, horizon: pick.h,
      teaser: `${cfg.name}'s call: ${pick.s} on "${pick.t}".`,
      thesis, price_usdc: 0.001, status: 'published', published_at: new Date().toISOString(),
    };
    const { data: created, error } = await supabase.from('creator_signals').insert(body).select('*').single();
    if (error) { console.error(`[swarm:${cfg.key}] signal insert:`, error.message); return; }
    s.signalId = created.id;

    // On-chain attestation (admin-signed), same as Sage.
    if (SIGNAL_REGISTRY_ADDRESS && walletClient && publicClient) {
      try {
        const onchainSignalId = keccak256(toHex(created.id));
        const canonical = [created.title, created.market_question, created.stance, String(created.confidence), String(created.edge_bps), created.horizon, created.thesis].join('\n--\n');
        const contentHash = keccak256(toHex(canonical));
        const priceMicro = BigInt(Math.round(Number(created.price_usdc) * 1_000_000));
        const tx = await walletClient.writeContract({
          address: SIGNAL_REGISTRY_ADDRESS,
          abi: [{ name: 'publish', type: 'function', stateMutability: 'nonpayable',
            inputs: [{ name: 'signalId', type: 'bytes32' }, { name: 'contentHash', type: 'bytes32' }, { name: 'priceUsdc', type: 'uint256' }], outputs: [] }],
          functionName: 'publish', args: [onchainSignalId, contentHash, priceMicro],
        });
        s.onchainTx = tx;
        await supabase.from('creator_signals').update({ onchain_signal_id: onchainSignalId, content_hash: contentHash, onchain_tx: tx }).eq('id', created.id);
        console.log(`[swarm:${cfg.key}] published on-chain-attested signal ${created.id} (tx ${tx})`);
      } catch (e) { console.error(`[swarm:${cfg.key}] attest failed:`, e.shortMessage || e.message); }
    }
  }

  // ── One agent's turn ───────────────────────────────────────────────────────
  async function runOne(cfg) {
    const s = st(cfg.key);
    if (s.busy) return;
    s.busy = true;
    try {
      if (cfg.role === 'creator') await runCreator(cfg);
      else await runTrader(cfg);
    } catch (e) {
      console.error(`[swarm:${cfg.key}] tick error:`, e.message);
    } finally { s.busy = false; }
  }

  // Staggered scheduler: spread agents across the interval so they act at
  // different times (feels alive, avoids nonce/rate collisions).
  function start() {
    ROSTER.forEach((cfg, i) => {
      const offsetMs = 60 * 1000 + i * 90 * 1000;            // first run, staggered
      const periodMs = INTERVAL_MIN * 60 * 1000 + i * 17000;  // de-sync periods
      setTimeout(() => { runOne(cfg); setInterval(() => runOne(cfg), periodMs); }, offsetMs);
    });
    console.log(`[swarm] scheduler started (interval ~${INTERVAL_MIN}m, staggered)`);
  }

  // ── Public API: roster + battle ─────────────────────────────────────────────
  let rosterCache = { data: null, ts: 0 };
  app.get('/api/agents/roster', async (req, res) => {
    try {
      if (rosterCache.data && Date.now() - rosterCache.ts < 20000) return res.json(rosterCache.data);
      const agents = [];
      for (const cfg of ROSTER) {
        const wid = await getWalletId(cfg.walletKey);
        let address = null, balance = 0;
        if (wid) { const info = await getWalletInfo(wid); address = info.address; balance = parseFloat(info.usdcBalance) || 0; }
        const { data: rows } = await supabase
          .from('notifications').select('message, created_at')
          .eq('user_id', cfg.user).eq('type', 'agent_decision')
          .order('created_at', { ascending: false }).limit(6);
        const decisions = (rows || []).map(r => { try { return { ...JSON.parse(r.message), at: r.created_at }; } catch { return null; } }).filter(Boolean);
        let signal = null;
        if (cfg.role === 'creator') {
          const { data: sig } = await supabase.from('creator_signals')
            .select('id, title, unlocks_count, revenue_usdc, onchain_tx')
            .eq('creator_user_id', cfg.user).eq('status', 'published')
            .order('created_at', { ascending: false }).limit(1).maybeSingle();
          if (sig) signal = { id: sig.id, title: sig.title, unlocks: sig.unlocks_count ?? 0, revenueUsdc: Number(sig.revenue_usdc ?? 0), onchainTx: sig.onchain_tx };
        }
        agents.push({
          key: cfg.key, name: cfg.name, role: cfg.role, brain: cfg.brain, persona: cfg.persona,
          address, balance, erc8004Id: agentTokenIds.get(cfg.walletKey) ?? null,
          recentDecisions: decisions, signal,
        });
      }
      const data = { enabled: true, count: agents.length, agents };
      rosterCache = { data, ts: Date.now() };
      res.json(data);
    } catch (e) {
      console.error('[swarm] roster error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  return { tick: async () => { for (const c of ROSTER) await runOne(c); }, start, roster: ROSTER };
}
