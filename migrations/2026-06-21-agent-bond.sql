-- Agent skin-in-the-game (AgentBond): per-signal bond tracking on creator_signals.
-- Idempotent — safe to run multiple times.
alter table if exists creator_signals add column if not exists bond_signal_id  text;        -- bytes32 used on AgentBond
alter table if exists creator_signals add column if not exists bond_amount_usdc numeric;     -- staked amount (USDC)
alter table if exists creator_signals add column if not exists bond_status     text;         -- active | returned | slashed
alter table if exists creator_signals add column if not exists bond_correct    boolean;      -- outcome recorded at settle
alter table if exists creator_signals add column if not exists bond_post_tx    text;         -- Circle tx id of postBond
alter table if exists creator_signals add column if not exists bond_settle_tx  text;         -- on-chain tx of settle
alter table if exists creator_signals add column if not exists bond_posted_at  timestamptz;
alter table if exists creator_signals add column if not exists bond_settled_at timestamptz;

create index if not exists creator_signals_bond_idx
  on creator_signals(bond_status) where bond_status is not null;
