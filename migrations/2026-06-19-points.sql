-- Points Engine + Onboarding Quests (PLAN_POINTS_QUESTS_AGENTS.md)
-- Run in the Supabase SQL editor. Off-chain XP only — NOT a token, not redeemable.

-- Append-only ledger = source of truth (idempotent, auditable).
create table if not exists points_ledger (
  id uuid default gen_random_uuid() primary key,
  user_id text not null,
  delta integer not null,                   -- can be negative (clawback)
  reason text not null,                      -- see EARN table in lib/points.js
  ref_type text,                             -- 'trade'|'signal'|'unlock'|'referral'|'quest'|'streak'
  ref_id text,                               -- source row id (for dedupe)
  season text not null default 's1',
  created_at timestamptz default now(),
  unique (user_id, reason, ref_id)           -- one-time awards can't double-count
);
create index if not exists points_ledger_user_idx on points_ledger(user_id, created_at desc);
create index if not exists points_ledger_season_idx on points_ledger(season, created_at desc);

-- Denormalised totals for cheap reads.
create table if not exists user_points (
  user_id text primary key,
  total_points integer not null default 0,
  season text not null default 's1',
  season_points integer not null default 0,
  level integer not null default 1,
  streak_days integer not null default 0,
  last_active_date date,
  updated_at timestamptz default now()
);
create index if not exists user_points_season_idx on user_points(season, season_points desc);

-- Quest progress (quest config lives in code, not here).
create table if not exists quest_progress (
  user_id text not null,
  quest_key text not null,
  progress integer not null default 0,
  target integer not null default 1,
  status text not null default 'in_progress', -- 'in_progress'|'completed'|'claimed'
  completed_at timestamptz,
  claimed_at timestamptz,
  primary key (user_id, quest_key)
);
