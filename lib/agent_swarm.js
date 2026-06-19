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
  {
    key: 'striker', name: 'Striker ⚽', role: 'creator', brain: 'gemini',
    category: 'worldcup', alsoTrades: true, minEdge: 0.05, riskMult: 1.0,
    persona: 'a football analyst for the 2026 FIFA World Cup who turns live Polymarket odds + form/news into sharp, falsifiable calls with clear invalidation — and backs his own calls with small trades.',
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
    keccak256, toHex, encodeFunctionData, parseAbiItem, stringToHex,
  } = deps;

  // Arc predeployed Memo contract — wraps a call and emits on-chain metadata
  // (memoId + memo bytes) while preserving the original sender for the inner
  // call. Lets every agent USDC payment carry an on-chain, indexable reason.
  const MEMO_CONTRACT = '0x5294E9927c3306DcBaDb03fe70b92e01cCede505';
  const MEMO_ENABLED = (process.env.AGENT_MEMO || 'true') === 'true' && encodeFunctionData && parseAbiItem && stringToHex;

  // Transfer USDC from a Circle SCA agent wallet, wrapped in an Arc memo so the
  // payment reason (e.g. "signal:<id>") is attested on-chain. Falls back to a
  // plain transfer if memo is unavailable/reverts — the payment never breaks.
  async function usdcTransferWithMemo(walletId, toAddr, amountMicro, memoKey, memoObj) {
    if (MEMO_ENABLED) {
      try {
        const innerData = encodeFunctionData({
          abi: [parseAbiItem('function transfer(address,uint256) returns (bool)')],
          functionName: 'transfer', args: [toAddr, BigInt(amountMicro)],
        });
        const memoId = keccak256(toHex(String(memoKey)));
        const memoData = stringToHex(JSON.stringify(memoObj).slice(0, 400));
        const res = await circle.createContractExecutionTransaction({
          walletId, contractAddress: MEMO_CONTRACT,
          abiFunctionSignature: 'memo(address,bytes,bytes32,bytes)',
          abiParameters: [USDC, innerData, memoId, memoData],
          fee: { type: 'level', config: { feeLevel: 'HIGH' } },
        });
        return { txId: res.data?.id || null, memo: true };
      } catch (e) {
        console.warn(`[swarm] memo transfer fell back to plain: ${e.message}`);
      }
    }
    const res = await circle.createContractExecutionTransaction({
      walletId, contractAddress: USDC,
      abiFunctionSignature: 'transfer(address,uint256)',
      abiParameters: [toAddr, String(amountMicro)],
      fee: { type: 'level', config: { feeLevel: 'HIGH' } },
    });
    return { txId: res.data?.id || null, memo: false };
  }

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
    // alsoTrades creators (e.g. Striker) need a real bankroll to size trades;
    // pure creators only need a little for gas + attestation.
    const target = (cfg.role === 'creator' && !cfg.alsoTrades) ? Math.min(BOOTSTRAP_USDC, 0.6) : BOOTSTRAP_USDC;
    if (!s.ensured && balance < target - 0.05 && walletClient && adminAccount) {
      const need = Math.ceil((target - balance) * 100) / 100;
      try {
        const treasury = await getTreasuryUsdcBalance();
        if (treasury != null && treasury >= need + 1) {
          const microNeed = BigInt(Math.round(need * 1_000_000));
          let funded = false;
          // Treasury → agent funding carries an on-chain memo (reason = which
          // agent + why). Admin is an EOA, so the memo path is fully supported.
          if (MEMO_ENABLED && walletClient) {
            try {
              const innerData = encodeFunctionData({
                abi: [parseAbiItem('function transfer(address,uint256) returns (bool)')],
                functionName: 'transfer', args: [info.address, microNeed],
              });
              await walletClient.writeContract({
                address: MEMO_CONTRACT,
                abi: [{ name: 'memo', type: 'function', stateMutability: 'nonpayable', inputs: [
                  { name: 'target', type: 'address' }, { name: 'data', type: 'bytes' },
                  { name: 'memoId', type: 'bytes32' }, { name: 'memoData', type: 'bytes' } ], outputs: [] }],
                functionName: 'memo',
                args: [USDC, innerData, keccak256(toHex(`fund:${cfg.user}`)),
                  stringToHex(JSON.stringify({ kind: 'agent_funding', agent: cfg.user, role: cfg.role, usdc: need }))],
              });
              funded = true;
              console.log(`[swarm:${cfg.key}] funded +${need} USDC with on-chain memo`);
            } catch (e) { console.warn(`[swarm:${cfg.key}] memo funding fell back to plain: ${e.message}`); }
          }
          if (!funded) {
            await walletClient.writeContract({
              address: USDC, abi: usdcTransferAbi, functionName: 'transfer',
              args: [info.address, microNeed],
            });
          }
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

  // ── Live World Cup 2026 markets (real Polymarket consensus odds) ───────────
  // Used by the football creator to ground signals in real prices, and by
  // traders to comment on real WC predicts. Cached ~5 min.
  let _wcCache = { at: 0, markets: [] };
  async function worldCupMarkets() {
    if (Date.now() - _wcCache.at < 5 * 60 * 1000 && _wcCache.markets.length) return _wcCache.markets;
    const out = [];
    const pushFromEvent = (ev) => {
      const evTitle = ev?.title || '';
      const mkts = ev?.markets || [];
      for (const m of mkts) {
        if (m.closed === true || m.active === false) continue;
        let yes = 0.5;
        try { yes = parseFloat(JSON.parse(m.outcomePrices || '[]')[0]); } catch { continue; }
        if (!Number.isFinite(yes) || yes <= 0.005) continue; // skip dead longshots
        out.push({
          id: String(m.id), slug: m.slug, question: m.question,
          team: m.groupItemTitle || m.question, yesPct: yes,
          eventTitle: evTitle,
          volume: parseFloat(m.volume || '0') || 0,
        });
      }
    };
    try {
      // All live World Cup events (winner, top scorer, golden boot/ball, goals
      // records, group winners, player goals, etc.) — real Polymarket markets.
      const r = await fetch('https://gamma-api.polymarket.com/events?limit=60&closed=false&active=true&order=volume&ascending=false&tag_slug=world-cup', { headers: { Accept: 'application/json' } });
      if (r.ok) {
        const events = await r.json();
        for (const ev of (events || [])) pushFromEvent(ev);
      }
      // Always include the flagship winner event explicitly (in case the tag
      // page paginated it out).
      if (!out.some(m => m.slug?.includes('win-the-2026-fifa-world-cup'))) {
        const r2 = await fetch('https://gamma-api.polymarket.com/events?slug=world-cup-winner', { headers: { Accept: 'application/json' } });
        if (r2.ok) { const e2 = await r2.json(); if (e2?.[0]) pushFromEvent(e2[0]); }
      }
    } catch (_) {}
    // De-dup by market id, keep liquid/contested ones first.
    const seen = new Set();
    const uniq = out.filter(m => (m.id && !seen.has(m.id)) ? seen.add(m.id) : false);
    uniq.sort((a, b) => b.volume - a.volume);
    if (uniq.length) _wcCache = { at: Date.now(), markets: uniq };
    return uniq;
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
      const pay = await usdcTransferWithMemo(
        buyerWalletId, toAddr, Math.round(price * 1_000_000),
        `signal:${signal.id}`,
        { kind: 'agent_to_agent', buyer: cfg.user, seller: signal.creator_user_id, signalId: signal.id },
      );
      const txId = pay.txId;
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
        raw: { kind: 'agent_to_agent', agent: cfg.user, counterparty: signal.creator_user_id, signalId: signal.id, onchainMemo: pay.memo },
      }).then(({ error }) => { if (error) console.warn(`[swarm:${cfg.key}] x402 receipt:`, error.message); });
      console.log(`[swarm:${cfg.key}] bought signal ${signal.id} from ${signal.creator_user_id} — ${price} USDC → ${toAddr}${pay.memo ? ' (on-chain memo)' : ''} (tx ${txId})`);
      return { price, txId, toAddr, memo: pay.memo };
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

  // A trader agent picks a LIVE World Cup market and posts an analysis comment
  // on it (keyed to the market's Polymarket id, so it shows in the app's market
  // comments). Grounds the take in the real consensus price + light web research.
  async function commentOnWorldCup(cfg) {
    try {
      const wc = await worldCupMarkets();
      if (!wc.length) return;
      const m = wc.slice(0, 14)[Math.floor(Math.random() * Math.min(14, wc.length))];
      // Don't spam: skip if this agent already commented on this market recently.
      const { data: existing } = await supabase
        .from('comments').select('id')
        .eq('user_id', cfg.user).eq('target_type', 'market').eq('target_id', m.id)
        .gte('created_at', new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString())
        .limit(1);
      if (existing && existing.length) return;
      let brief = '';
      try { const r = await researchQuestion(`${m.team} 2026 World Cup form chances`, 2); brief = r?.brief || ''; } catch (_) {}
      let text;
      try {
        const sys = `You are ${cfg.name}, ${cfg.persona} Give a ONE-sentence sharp take on this 2026 World Cup market for other traders. Mention whether the ${Math.round(m.yesPct * 100)}% YES price looks high or low and why. Plain text, no preamble.`;
        const u = `${m.question} — consensus ${Math.round(m.yesPct * 100)}% YES.${brief ? `\n\nLive: ${brief}` : ''}`;
        const raw = await llmComplete([{ role: 'system', content: sys }, { role: 'user', content: u }], { prefer: cfg.brain });
        text = formatForApp(String(raw || '').slice(0, 240));
      } catch (_) {
        text = `${m.team} at ${Math.round(m.yesPct * 100)}% to win it all — ${m.yesPct > 0.12 ? 'priced like a real contender' : 'a longshot; value only as a dark horse'}.`;
      }
      if (text && text.length > 8) {
        await postComment(cfg, 'market', m.id, `⚽ ${text}`);
        console.log(`[swarm:${cfg.key}] commented on WC market ${m.slug}`);
      }
    } catch (e) { console.warn(`[swarm:${cfg.key}] WC comment failed:`, e.message); }
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
        action: 'skip', brain: 'AI',
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
        decision = { ...chosen, action: 'go', side, amount: stake, brain: 'AI', reasoning: formatForApp(String(parsed.reasoning || '').slice(0, 400)) };
      } catch (e) {
        const c = top[0];
        decision = { ...c, action: 'go', amount: stake, brain: 'AI',
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
      alphaMemo: boughtSignal ? (boughtSignal.memo === true) : null,
      sources,
    };

    if (decision.action === 'skip') {
      console.log(`[swarm:${cfg.key}] SKIP — ${decision.reasoning}`);
      await supabase.from('notifications').insert({
        user_id: cfg.user, title: 'No +EV trade', type: 'agent_decision', read: true,
        message: JSON.stringify(payload),
      });
      // Even on a hold, a trader can still weigh in on a live World Cup market.
      if (Math.random() < 0.6) await commentOnWorldCup(cfg);
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
    // Then chime in on a live World Cup market (~half the time) so the WC
    // predicts get real AI analysis in their comments.
    if (Math.random() < 0.6) await commentOnWorldCup(cfg);
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

    if (cfg.category === 'worldcup') {
      // World Cup creator builds a LIBRARY of signals (winner, scorer, golden
      // boot, goals, groups…). Publish a fresh one each cooldown until we hit a
      // cap, so Striker accrues many distinct calls rather than just one.
      const WC_MAX = parseInt(process.env.AGENT_SWARM_WC_MAX_SIGNALS || '12', 10);
      const WC_COOLDOWN_MS = parseInt(process.env.AGENT_SWARM_WC_SIGNAL_COOLDOWN_MIN || '8', 10) * 60 * 1000;
      const { data: live } = await supabase
        .from('creator_signals')
        .select('id, created_at')
        .eq('creator_user_id', cfg.user).eq('status', 'published')
        .order('created_at', { ascending: false });
      const count = (live || []).length;
      const lastAt = count ? Date.now() - new Date(live[0].created_at).getTime() : Infinity;
      if (count >= WC_MAX) {
        // Library full — rotate the OLDEST out occasionally to keep it fresh.
        if (lastAt < WC_COOLDOWN_MS) return;
        const oldest = live[live.length - 1];
        await supabase.from('creator_signals').update({ status: 'archived' }).eq('id', oldest.id);
      } else if (lastAt < WC_COOLDOWN_MS) {
        return; // wait out the cooldown before adding the next one
      }
      // fall through to publish a new WC signal (no single-signal archiving)
    } else {
      // Other creators keep ONE live signal; rotate it occasionally.
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
    }

    const pool = cfg.category === 'politics' ? POLI_QS : CRYPTO_QS;
    let pick;
    let researchBrief = '';
    if (cfg.category === 'worldcup') {
      // REAL World Cup signal: pick a live Polymarket market + its real odds
      // across event types (winner, top scorer, golden boot, goals records,
      // group winners…), research it, and let the LLM write the call.
      const wc = await worldCupMarkets();
      if (!wc.length) { console.log(`[swarm:${cfg.key}] no WC markets available`); return; }
      // Avoid re-signalling a question we already have live.
      const { data: mine } = await supabase
        .from('creator_signals').select('market_question')
        .eq('creator_user_id', cfg.user).eq('status', 'published');
      const taken = new Set((mine || []).map(r => r.market_question));
      // Pick among the most liquid markets so signals vary + stay real.
      const cand = wc.slice(0, 30).filter(x => !taken.has(x.question));
      if (!cand.length) { console.log(`[swarm:${cfg.key}] all top WC markets already signalled`); return; }
      const m = cand[Math.floor(Math.random() * cand.length)];
      const yesPct = Math.round(m.yesPct * 100);
      // Generic falsifiable stance: side with the higher consensus probability,
      // but lean slightly contrarian on near-coin-flips so it's a real call.
      const stance = m.yesPct >= 0.5 ? 'YES' : 'NO';
      const label = m.eventTitle && !/winner/i.test(m.eventTitle) ? m.eventTitle.replace(/^World Cup:?\s*/i, '') : m.team;
      try {
        const res = await researchQuestion(`${m.question} 2026 FIFA World Cup`, 3);
        researchBrief = res?.brief || '';
      } catch (_) {}
      pick = {
        t: `${label} — 2026 World Cup`,
        q: m.question,
        s: stance,
        c: Math.min(0.82, Math.max(0.52, stance === 'YES' ? m.yesPct + 0.03 : (1 - m.yesPct) + 0.03)),
        e: Math.max(150, Math.round(Math.abs(m.yesPct - 0.5) * 600)),
        h: 'July 2026',
        marketId: m.id, marketSlug: m.slug, yesPct,
      };
    } else {
      pick = pool[Math.floor(Math.random() * pool.length)];
    }
    // Let the LLM write the thesis in the creator's voice (best-effort).
    let thesis = `Order-flow and live signals favor ${pick.s} while the implied probability lags. Invalidation: a regime shift against the thesis.`;
    try {
      const sys = cfg.category === 'worldcup'
        ? `You are ${cfg.name}, ${cfg.persona} Polymarket consensus currently prices "${pick.q}" at ${pick.yesPct}% YES.${researchBrief ? ' Live research below.' : ''} Write a sharp 2-sentence falsifiable ${pick.s} thesis with a clear invalidation (form, injuries, or draw). Plain text only.`
        : `You are ${cfg.name}, ${cfg.persona} Write a 2-sentence falsifiable thesis (with an invalidation level) for this prediction. Plain text only.`;
      const u = cfg.category === 'worldcup'
        ? `${pick.t} — ${pick.q} (your stance ${pick.s})${researchBrief ? `\n\nLive research:\n${researchBrief}` : ''}`
        : `${pick.t} — ${pick.q} (stance ${pick.s})`;
      const raw = await llmComplete([{ role: 'system', content: sys }, { role: 'user', content: u }], { prefer: cfg.brain });
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
      if (cfg.role === 'creator') {
        await runCreator(cfg);
        // Creators flagged alsoTrades back their calls with real trades, so they
        // also earn a spot on the Agents-vs-Humans leaderboard.
        if (cfg.alsoTrades) await runTrader(cfg);
      } else {
        await runTrader(cfg);
      }
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
        const decisions = (rows || []).map(r => { try { const d = JSON.parse(r.message); if (d.brain) d.brain = 'AI'; return { ...d, at: r.created_at }; } catch { return null; } }).filter(Boolean);
        let signal = null;
        if (cfg.role === 'creator') {
          const { data: sig } = await supabase.from('creator_signals')
            .select('id, title, unlocks_count, revenue_usdc, onchain_tx')
            .eq('creator_user_id', cfg.user).eq('status', 'published')
            .order('created_at', { ascending: false }).limit(1).maybeSingle();
          if (sig) signal = { id: sig.id, title: sig.title, unlocks: sig.unlocks_count ?? 0, revenueUsdc: Number(sig.revenue_usdc ?? 0), onchainTx: sig.onchain_tx };
        }
        agents.push({
          key: cfg.key, name: cfg.name, role: cfg.role, brain: 'AI', persona: cfg.persona,
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

  // ── AI Colony feed: one reverse-chronological stream of the whole swarm's
  // actions (research → pay peer → reason → trade), each tagged with the agent.
  let feedCache = { data: null, ts: 0 };
  app.get('/api/agents/feed', async (req, res) => {
    try {
      if (feedCache.data && Date.now() - feedCache.ts < 15000) return res.json(feedCache.data);
      const limit = Math.min(60, Math.max(5, parseInt(req.query.limit || '40', 10)));
      const byUser = Object.fromEntries(ROSTER.map(c => [c.user, c]));
      const userIds = ROSTER.map(c => c.user);
      const { data: rows } = await supabase
        .from('notifications').select('user_id, message, created_at')
        .in('user_id', userIds).eq('type', 'agent_decision')
        .order('created_at', { ascending: false }).limit(limit);
      const events = (rows || []).map(r => {
        let m = {}; try { m = JSON.parse(r.message); } catch { return null; }
        const cfg = byUser[r.user_id] || {};
        return {
          agentKey: cfg.key || null,
          agentName: cfg.name || m.agentName || 'Agent',
          role: cfg.role || m.role || 'trader',
          brain: (cfg.brain || m.brain) ? 'AI' : null,
          action: m.action || null,                 // 'go' | 'skip'
          question: m.question || null,
          side: m.side || null,
          amount: m.amount ?? null,
          reasoning: m.reasoning || null,
          // peer-signal review (agent judging another agent's alpha)
          signalReview: m.signalReview || null,
          // agent→agent x402 alpha payment (+ on-chain memo)
          alphaPaid: m.alphaPaid ?? null,
          alphaTxId: m.alphaTxId || null,
          alphaCreator: m.alphaCreator || null,
          alphaMemo: m.alphaMemo === true,
          // open-web research the agent read (vision)
          sources: Array.isArray(m.sources) ? m.sources.slice(0, 3) : [],
          // trade receipt
          txHash: m.txHash || null,
          contractAddress: m.contractAddress || null,
          at: r.created_at,
        };
      }).filter(Boolean);
      const data = { enabled: true, count: events.length, events, updatedAt: new Date().toISOString() };
      feedCache = { data, ts: Date.now() };
      res.json(data);
    } catch (e) {
      console.error('[swarm] feed error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  return { tick: async () => { for (const c of ROSTER) await runOne(c); }, start, roster: ROSTER };
}
