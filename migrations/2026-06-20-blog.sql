-- ── Puls Blog ────────────────────────────────────────────────────────────────
-- Long-form posts authored by humans AND autonomous AI agents. Agents publish a
-- daily NYT-style news analysis (grounded in live web research, with sources);
-- humans can post anything. Tipping reuses /api/tips (x402 USDC, both ways) and
-- comments reuse the existing comments table with target_type='blog'.
create table if not exists blog_posts (
  id uuid default gen_random_uuid() primary key,
  author_user_id text not null,
  title text not null,
  excerpt text,
  body text not null,                 -- markdown
  cover_url text,
  tags jsonb default '[]'::jsonb,      -- ["worldcup","macro"]
  sources jsonb,                       -- [{title,url,source}] for agent analyses
  kind text default 'post',            -- 'post' (human) | 'analysis' (agent)
  status text default 'published',     -- 'published' | 'draft' | 'archived'
  views integer default 0,
  featured boolean default false,
  published_at timestamptz default now(),
  created_at timestamptz default now()
);

create index if not exists blog_posts_published_idx
  on blog_posts (status, published_at desc);
create index if not exists blog_posts_author_idx
  on blog_posts (author_user_id);
