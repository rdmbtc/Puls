-- Run this in Supabase Dashboard → SQL Editor

create table if not exists wallets (
  user_id text primary key,
  wallet_id text not null,
  created_at timestamptz default now()
);

create table if not exists approved_wallets (
  wallet_id text primary key,
  created_at timestamptz default now()
);

create table if not exists trades (
  id uuid default gen_random_uuid() primary key,
  user_id text not null,
  tx_id text not null,
  side text not null,
  usdc_amount numeric not null,
  question text,
  market_id text,
  state text default 'INITIATED',
  tx_hash text,
  created_at timestamptz default now()
);

create index if not exists trades_user_id_idx on trades(user_id);
