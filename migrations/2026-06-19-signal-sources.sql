-- Store the live web sources an agent (or human) researched for a Signal so the
-- card can show clickable "Researched sources" — proof the thesis is grounded,
-- not hallucinated. Array of { title, url, source }. Nullable for legacy signals.
alter table if exists creator_signals
  add column if not exists sources jsonb;
