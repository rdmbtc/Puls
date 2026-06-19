/**
 * Puls Agent Oracle — the "AI layer" on top of every market.
 *
 * Three innovation surfaces, all read-mostly and grounded in the swarm's live
 * behaviour + web research:
 *
 *   GET  /api/oracle/:slug            AI Oracle Panel — aggregate the swarm's
 *                                     YES probability for a market (consensus of
 *                                     several agent brains), shown next to the
 *                                     crowd (Polymarket) and the market price.
 *   POST /api/oracle/ask              Ask an agent to DEFEND a stance on a market
 *                                     with live sources before you trade.
 *   GET  /api/oracle/correlations/:slug  AI predict-to-predict correlations:
 *                                     "if this resolves YES, here's the knock-on
 *                                     effect on related markets."
 *
 * Wiring (server.js):
 *   registerAgentOracle(app, { supabase, deployedMarketsCache, researchQuestion,
 *     llmComplete, parseLlmJson, formatForApp, authenticateUser, strictLimiter,
 *     generalLimiter, pmConsensusFor });
 */

export function registerAgentOracle(app, deps) {
  const {
    supabase,
    researchQuestion,
    llmComplete,
    parseLlmJson,
    formatForApp,
    authenticateUser,
    strictLimiter,
    generalLimiter,
    pmConsensusFor,          // async (slug) -> { question, yesPct } | null
    listMarketSummaries,     // () -> [{ slug, question, yesPct }]
  } = deps;

  const pass = (_q, _s, n) => n();
  const gLimit = generalLimiter || pass;
  const sLimit = strictLimiter || pass;

  // Collect the swarm's most recent stance per agent for a given market slug,
  // from the stored agent_decision notifications. Returns agent votes + an
  // aggregate YES probability (the "AI Oracle" consensus).
  async function agentConsensus(slug) {
    // agent_decision rows are keyed by the market slug in `title`.
    const { data: rows } = await supabase
      .from('notifications')
      .select('user_id, message, created_at')
      .eq('type', 'agent_decision')
      .eq('title', slug)
      .order('created_at', { ascending: false })
      .limit(40);
    const latestByAgent = new Map();
    for (const r of rows || []) {
      let m; try { m = JSON.parse(r.message); } catch { continue; }
      if (!m || (m.action !== 'go' && m.side == null)) continue;
      if (!latestByAgent.has(r.user_id)) {
        latestByAgent.set(r.user_id, { ...m, at: r.created_at });
      }
    }
    const votes = [];
    for (const [userId, m] of latestByAgent) {
      // Convert each agent's stance + confidence into a YES probability.
      const conf = Number(m.conviction ?? 0.6);
      const lean = Math.min(0.97, Math.max(0.53, 0.5 + Math.abs(conf) / 2));
      const yes = m.side === 'NO' ? 1 - lean : lean;
      votes.push({
        agent: m.agentName || userId,
        side: m.side || null,
        yes,
        reasoning: m.reasoning || null,
        at: m.at,
      });
    }
    const aiYes = votes.length
      ? votes.reduce((a, v) => a + v.yes, 0) / votes.length
      : null;
    return { aiYes, votes };
  }

  // GET /api/oracle/:slug — AI Oracle Panel.
  app.get('/api/oracle/:slug', gLimit, async (req, res) => {
    try {
      const slug = String(req.params.slug || '').trim();
      if (!slug) return res.status(400).json({ error: 'slug required' });
      const { aiYes, votes } = await agentConsensus(slug);
      let crowdYes = null, question = null;
      try {
        const pm = await pmConsensusFor(slug);
        if (pm) { crowdYes = pm.yesPct; question = pm.question; }
      } catch (_) {}
      res.json({
        ok: true,
        slug,
        question,
        crowdYes,                 // Polymarket consensus (the crowd)
        aiYes,                    // swarm consensus (the AI panel)
        agentCount: votes.length,
        votes: votes.slice(0, 8),
      });
    } catch (e) {
      console.error('[oracle] panel error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // POST /api/oracle/ask — an agent defends a stance with live sources.
  // Body: { slug, question?, side? ('YES'|'NO'), agentName? }
  app.post('/api/oracle/ask', authenticateUser, sLimit, async (req, res) => {
    try {
      const slug = String(req.body.slug || '').trim();
      let question = String(req.body.question || '').trim();
      const side = ['YES', 'NO'].includes(String(req.body.side || '').toUpperCase())
        ? String(req.body.side).toUpperCase() : null;
      if (!slug && !question) return res.status(400).json({ error: 'slug or question required' });

      if (!question) {
        try { const pm = await pmConsensusFor(slug); if (pm) question = pm.question; } catch (_) {}
      }
      question = question || slug.replace(/-/g, ' ');

      // If no explicit side, default to the swarm consensus side.
      let defendSide = side;
      if (!defendSide && slug) {
        const { aiYes } = await agentConsensus(slug);
        if (aiYes != null) defendSide = aiYes >= 0.5 ? 'YES' : 'NO';
      }
      defendSide = defendSide || 'YES';

      let brief = '', sources = [];
      try { const r = await researchQuestion(question, 3); brief = r?.brief || ''; sources = Array.isArray(r?.sources) ? r.sources.slice(0, 4) : []; } catch (_) {}

      const agentName = String(req.body.agentName || 'Pulse').slice(0, 24);
      let answer = '';
      try {
        const sys = `You are ${agentName}, an autonomous forecasting agent on Puls. A user is about to trade and asks you to DEFEND the ${defendSide} side of a prediction with EVIDENCE. Be concise (3-4 sentences), specific, and cite the live research provided. If the evidence is weak, say so honestly. Plain text, no preamble.`;
        const u = `Market: "${question}"\nYou are defending: ${defendSide}.${brief ? `\n\nLive research:\n${brief}` : ''}`;
        const raw = await llmComplete([{ role: 'system', content: sys }, { role: 'user', content: u }], {});
        answer = formatForApp(String(raw || '').slice(0, 900));
      } catch (e) {
        answer = `I'd lean ${defendSide}, but I couldn't fetch fresh evidence right now — trade with caution.`;
      }
      res.json({ ok: true, slug, question, side: defendSide, answer, sources, agent: agentName });
    } catch (e) {
      console.error('[oracle] ask error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // GET /api/oracle/correlations/:slug — predict-to-predict knock-on effects.
  app.get('/api/oracle/correlations/:slug', gLimit, async (req, res) => {
    try {
      const slug = String(req.params.slug || '').trim();
      let question = null;
      try { const pm = await pmConsensusFor(slug); if (pm) question = pm.question; } catch (_) {}
      question = question || slug.replace(/-/g, ' ');

      // Candidate related markets (other live markets the LLM can map against).
      let others = [];
      try { others = (listMarketSummaries ? listMarketSummaries() : []) || []; } catch (_) {}
      others = others.filter((m) => m.slug !== slug).slice(0, 25);
      if (!others.length) return res.json({ ok: true, slug, question, correlations: [] });

      let correlations = [];
      try {
        const sys = `You are a markets analyst. Given a SOURCE prediction market and a list of OTHER live markets, identify up to 3 that are genuinely correlated. For each, state the direction (positive = both move together, negative = inverse) and a one-sentence why. STRICT JSON only: {"correlations":[{"slug":"...","direction":"positive"|"negative","strength":"high"|"medium"|"low","why":"..."}]}`;
        const list = others.map((m, i) => `${i + 1}. slug:${m.slug} | ${m.question}`).join('\n');
        const u = `SOURCE: "${question}" (slug:${slug})\n\nOTHER MARKETS:\n${list}`;
        const raw = await llmComplete([{ role: 'system', content: sys }, { role: 'user', content: u }], {});
        const j = parseLlmJson(raw);
        const bySlug = Object.fromEntries(others.map((m) => [m.slug, m]));
        correlations = (j.correlations || [])
          .filter((c) => c && bySlug[c.slug])
          .slice(0, 3)
          .map((c) => ({
            slug: c.slug,
            question: bySlug[c.slug].question,
            direction: c.direction === 'negative' ? 'negative' : 'positive',
            strength: ['high', 'medium', 'low'].includes(c.strength) ? c.strength : 'medium',
            why: formatForApp(String(c.why || '').slice(0, 200)),
          }));
      } catch (e) {
        console.warn('[oracle] correlations llm:', e.message);
      }
      res.json({ ok: true, slug, question, correlations });
    } catch (e) {
      console.error('[oracle] correlations error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  console.log('[oracle] AI Oracle Panel + ask-agent + correlations routes registered');
}
