-- Link a creator Signal to its on-app prediction (/m/<slug>) so readers can
-- jump straight to the market. Nullable: legacy + free-form signals just won't
-- render a "View prediction" link.
alter table if exists creator_signals
  add column if not exists market_slug text;
