-- Critical performance indexes — reduces Supabase egress by accelerating
-- the most frequent query patterns. Safe to run on a live database.

-- 1. trades(state) WHERE state = 'COMPLETE' — accelerates /api/live,
--    /api/stats, /api/leaderboard, /api/profile, updateLeaderboard.
--    This is the single biggest performance win.
CREATE INDEX IF NOT EXISTS idx_trades_state_complete
  ON trades(created_at DESC)
  WHERE state = 'COMPLETE';

-- 2. trades(tx_hash) — accelerates every QuickNode webhook handler's
--    dedup check (eq('tx_hash', txHash)).
CREATE INDEX IF NOT EXISTS idx_trades_tx_hash
  ON trades(tx_hash)
  WHERE tx_hash IS NOT NULL;

-- 3. trades(state, created_at DESC) — accelerates /api/live's latest-trade
--    query (.eq('state','COMPLETE').order('created_at', desc).limit(1)).
CREATE INDEX IF NOT EXISTS idx_trades_state_created
  ON trades(state, created_at DESC);

-- 4. deployed_markets(resolved) WHERE resolved = true — accelerates
--    agent_bond.settlePass and agent_duel.settlePass which both scan
--    resolved markets to build the outcome map.
CREATE INDEX IF NOT EXISTS idx_dm_resolved
  ON deployed_markets(slug)
  WHERE resolved = true;

-- 5. notifications(type, title, created_at DESC) — accelerates
--    /api/oracle/:slug which filters by type='agent_decision' + title=slug.
CREATE INDEX IF NOT EXISTS idx_notif_type_title_created
  ON notifications(type, title, created_at DESC);
