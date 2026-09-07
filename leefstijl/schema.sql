-- Neefjes Aandelenspel — database schema
-- Run this in the Supabase SQL editor (Project → SQL Editor → New query).

create extension if not exists "pgcrypto";

create table profiles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  token text not null unique,
  -- Real, admin-managed mandje: mirrors the actual DeGiro/EasyBroker basket.
  cash_balance numeric(12, 2) not null default 0,
  -- Fictional, nephew-tradeable mandje: starts as a copy of the real one
  -- plus €500 extra play money. Admin can top this up; nephews trade freely.
  fictional_cash_balance numeric(12, 2) not null default 0,
  created_at timestamptz not null default now()
);

-- Real mandje holdings (admin-managed, mirrors the actual broker basket).
create table holdings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  ticker text not null,
  shares numeric(14, 4) not null default 0,
  avg_cost numeric(12, 4) not null default 0,
  unique (profile_id, ticker)
);

-- Fictional mandje holdings (nephew-tradeable, no admin approval needed).
create table fictional_holdings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  ticker text not null,
  shares numeric(14, 4) not null default 0,
  avg_cost numeric(12, 4) not null default 0,
  unique (profile_id, ticker)
);

create table transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  ticker text not null,
  type text not null check (type in ('buy', 'sell')),
  shares numeric(14, 4) not null,
  price numeric(12, 4) not null,
  executed_at timestamptz not null default now()
);

create table portfolio_snapshots (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  date date not null,
  value numeric(12, 2) not null,
  unique (profile_id, date)
);

create table real_portfolio_entries (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles (id) on delete cascade,
  date date not null,
  value numeric(12, 2) not null,
  note text
);

create table quote_cache (
  ticker text primary key,
  price numeric(12, 4) not null,
  previous_close numeric(12, 4) not null,
  updated_at timestamptz not null default now()
);

-- Prices for tickers Finnhub's free tier can't cover correctly (e.g.
-- European/LSE-listed ETFs). When a ticker has a row here, it always wins
-- over a live Finnhub quote. Admin-maintained via /admin.
create table manual_prices (
  ticker text primary key,
  price numeric(12, 4) not null,
  updated_at timestamptz not null default now()
);

create index holdings_profile_id_idx on holdings (profile_id);
create index fictional_holdings_profile_id_idx on fictional_holdings (profile_id);
create index transactions_profile_id_idx on transactions (profile_id);
create index portfolio_snapshots_profile_id_idx on portfolio_snapshots (profile_id);
create index real_portfolio_entries_profile_id_idx on real_portfolio_entries (profile_id);

-- Row Level Security: all access goes through server-side API routes using
-- the service role key, so client-side (anon key) access is locked down.
alter table profiles enable row level security;
alter table holdings enable row level security;
alter table fictional_holdings enable row level security;
alter table transactions enable row level security;
alter table portfolio_snapshots enable row level security;
alter table real_portfolio_entries enable row level security;
alter table quote_cache enable row level security;
alter table manual_prices enable row level security;
