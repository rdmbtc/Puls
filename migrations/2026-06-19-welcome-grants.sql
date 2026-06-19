-- Welcome bonus grants — one-time USDC float for new verified users.
-- The unique user_id is the idempotency key (can't double-grant).
create table if not exists welcome_grants (
  user_id text primary key,
  amount_usdc numeric not null,
  address text,
  tx_hash text,
  created_at timestamptz default now()
);
create index if not exists welcome_grants_created_idx on welcome_grants(created_at desc);
