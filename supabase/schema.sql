-- Sala de Estudos — Painel de Prontidão (CBM-MA)
-- Rode este script inteiro no Supabase: Dashboard > SQL Editor > New query > Run.
-- Cria as tabelas do quadro compartilhado e libera leitura/escrita para a chave "anon"
-- (a sala não tem login — qualquer pessoa com o link participa, por design).

create table if not exists public.cards (
  id text primary key,
  subject text not null,
  area text,
  status text not null default 'todo' check (status in ('todo','doing','done','review')),
  owner_id text not null,
  owner_name text not null,
  active_name text,
  completed_by_id text,
  completed_by_name text,
  reviews_done int not null default 0,
  review_cycle boolean not null default false,
  created_at bigint not null,
  moved_at bigint not null
);
alter table public.cards enable row level security;
drop policy if exists "cards anon all" on public.cards;
create policy "cards anon all" on public.cards for all to anon using (true) with check (true);

create table if not exists public.presence (
  user_id text primary key,
  name text not null,
  at bigint not null
);
alter table public.presence enable row level security;
drop policy if exists "presence anon all" on public.presence;
create policy "presence anon all" on public.presence for all to anon using (true) with check (true);

create table if not exists public.stats (
  user_id text primary key,
  name text not null,
  focus_minutes numeric not null default 0,
  focus_cycles int not null default 0,
  streak int not null default 0,
  last_active_date text
);
alter table public.stats enable row level security;
drop policy if exists "stats anon all" on public.stats;
create policy "stats anon all" on public.stats for all to anon using (true) with check (true);

create table if not exists public.config (
  id int primary key default 1,
  sala text not null default 'Sala CBM-MA',
  exam_date date not null default '2026-10-18',
  seeded boolean not null default false
);
alter table public.config enable row level security;
drop policy if exists "config anon all" on public.config;
create policy "config anon all" on public.config for all to anon using (true) with check (true);

insert into public.config (id, sala, exam_date, seeded)
values (1, 'Sala CBM-MA', '2026-10-18', false)
on conflict (id) do nothing;
