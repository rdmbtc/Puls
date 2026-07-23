-- Mark prediction markets that an autonomous agent created from its own web
-- research (autonomous market creation). Lets the UI badge them and lets the
-- swarm cap how many it spins up per day.
alter table if exists deployed_markets
  add column if not exists created_by_agent boolean default false;
