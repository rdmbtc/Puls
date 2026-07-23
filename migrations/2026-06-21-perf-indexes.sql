-- Performance indexes for Puls hot paths (Supabase / Postgres).
-- Safe + idempotent: CREATE INDEX IF NOT EXISTS (no-op if already present).
-- Run in the Supabase SQL editor. The tables are small enough that the brief
-- lock is negligible; if you prefer zero-lock on a busy table, replace
-- "CREATE INDEX IF NOT EXISTS" with "CREATE INDEX CONCURRENTLY IF NOT EXISTS"
-- and run each statement on its own (CONCURRENTLY can't run in a transaction).

-- ── trades (hottest table: profile, points, leaderboard, recent feed, charts) ──
-- Recent-trades live feed: ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_trades_created_at        ON trades (created_at DESC);
-- Per-user history + points counts (eq user_id [+ gte created_at])
CREATE INDEX IF NOT EXISTS idx_trades_user_created      ON trades (user_id, created_at DESC);
-- Market price-history / chart endpoint (eq market_id + gte/order created_at)
CREATE INDEX IF NOT EXISTS idx_trades_market_created    ON trades (market_id, created_at);

-- ── deployed_markets (markets list, agent creation, bond settle lookups) ──────
-- /api/markets pulls is_user_created = true (partial index keeps it tiny)
CREATE INDEX IF NOT EXISTS idx_dm_user_created          ON deployed_markets (is_user_created) WHERE is_user_created = true;
-- Agent-created market cap/dedupe (eq created_by_agent [+ created_at])
CREATE INDEX IF NOT EXISTS idx_dm_agent_created         ON deployed_markets (created_by_agent, created_at);
-- Slug lookups (bond settle does WHERE slug IN (...)); harmless if slug is already unique
CREATE INDEX IF NOT EXISTS idx_dm_slug                  ON deployed_markets (slug);

-- ── creator_signals (signals marketplace + per-creator) ──────────────────────
CREATE INDEX IF NOT EXISTS idx_cs_creator_created       ON creator_signals (creator_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cs_status_created        ON creator_signals (status, created_at DESC);

-- ── notifications (agent decisions feed + roster: user_id + type + recent) ────
CREATE INDEX IF NOT EXISTS idx_notif_user_type_created  ON notifications (user_id, type, created_at DESC);

-- ── unlocks (per-user paid-content checks) ───────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_signal_unlocks_user      ON signal_unlocks (user_id, signal_id);
CREATE INDEX IF NOT EXISTS idx_alpha_unlocks_user       ON alpha_unlocks (user_id, signal_id);

-- ── comments (threads by target, ordered) ────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_comments_target_created  ON comments (target_type, target_id, created_at);

-- After running, optionally refresh planner stats:
-- ANALYZE trades; ANALYZE deployed_markets; ANALYZE creator_signals;
