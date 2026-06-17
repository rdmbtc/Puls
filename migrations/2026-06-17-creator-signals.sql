-- ════════════════════════════════════════════════════════════════════════════
-- Creator Signals — full creator-economy content layer (run in Supabase SQL editor)
-- ════════════════════════════════════════════════════════════════════════════
--
-- A "signal" is a premium prediction-market forecast authored by a creator
-- (human or agent). It is created as a `draft`, then `published` — publishing
-- writes an on-chain attestation to the SignalRegistry contract (content hash +
-- creator + price + timestamp), and the row stores the proof (tx hash + the
-- bytes32 signal id used on-chain).
--
-- Readers pay a per-read USDC nanopayment to unlock the full thesis (x402),
-- mirroring alpha_unlocks' exactly-once semantics. Analytics counters
-- (views / unlocks / revenue) are denormalised onto creator_signals for cheap
-- per-signal + per-creator reads.
--
-- Idempotent: safe to re-run.

create table if not exists creator_signals (
  id uuid default gen_random_uuid() primary key,
  creator_user_id text not null,             -- supabase_<uuid> | agent_... | eth_0x...
  title text not null,
  market_question text,                       -- the prediction this signal is about
  stance text not null default 'YES',         -- 'YES' | 'NO'
  confidence numeric default 0.6,             -- 0..1
  edge_bps integer default 0,                 -- claimed edge in basis points
  horizon text,                               -- e.g. '2026', 'Q3', 'by election day'
  teaser text,                                -- always-public hook
  thesis text not null,                       -- gated full content
  price_usdc numeric not null default 0.001,  -- per-read unlock price
  status text not null default 'draft',       -- 'draft' | 'published' | 'archived'

  -- on-chain attestation proof (filled at publish)
  onchain_signal_id text,                     -- bytes32 (keccak256 of this row id) used on SignalRegistry
  content_hash text,                          -- keccak256 of canonical content
  onchain_tx text,                            -- publish tx hash on Arc
  published_at timestamptz,

  -- denormalised analytics counters
  views integer not null default 0,
  unlocks_count integer not null default 0,
  revenue_usdc numeric not null default 0,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists creator_signals_creator_idx
  on creator_signals(creator_user_id, status, updated_at desc);
create index if not exists creator_signals_status_idx
  on creator_signals(status, published_at desc);

-- Paid per-read access. unique(user_id, signal_id) is the idempotency key that
-- guarantees a reader is charged at most once per signal (same pattern as
-- alpha_unlocks): RESERVE pending → pay creator → mark confirmed.
create table if not exists signal_unlocks (
  id uuid default gen_random_uuid() primary key,
  user_id text not null,
  signal_id uuid not null references creator_signals(id) on delete cascade,
  status text not null default 'pending',     -- 'pending' | 'confirmed'
  amount_usdc numeric,
  tx_id text,
  created_at timestamptz default now(),
  confirmed_at timestamptz,
  unique (user_id, signal_id)
);

create index if not exists signal_unlocks_user_idx on signal_unlocks(user_id);
create index if not exists signal_unlocks_signal_idx on signal_unlocks(signal_id);

-- For existing databases (no-op if columns already exist):
alter table creator_signals add column if not exists onchain_signal_id text;
alter table creator_signals add column if not exists content_hash text;
alter table creator_signals add column if not exists onchain_tx text;
alter table creator_signals add column if not exists revenue_usdc numeric not null default 0;
