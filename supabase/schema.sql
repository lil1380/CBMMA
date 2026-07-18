-- Sala de Estudos — Painel de Prontidão (CBM-MA)
-- Rode este script inteiro no Supabase: Dashboard > SQL Editor > New query > Run.
--
-- Este script SUBSTITUI o schema anterior (chave anon sem login). Se você já
-- rodou o schema.sql antigo, este comando apaga aquelas tabelas e os dados de
-- teste nelas (não tem problema, era só o teste inicial).
--
-- Modelo novo: contas de verdade via Supabase Auth (e-mail + senha, com
-- recuperação de senha por e-mail já embutida). Qualquer pessoa logada vê o
-- quadro inteiro, mas só cria/move/apaga os próprios assuntos.

drop table if exists public.presence;
drop table if exists public.stats;
drop table if exists public.cards;
drop table if exists public.config;
drop function if exists public.delete_my_account();

-- Perfil público de cada conta: nome exibido + estatísticas pessoais +
-- presença (last_seen). Uma linha por usuário, criada por ele mesmo no
-- primeiro login.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  streak int not null default 0,
  last_active_date date,
  focus_minutes numeric not null default 0,
  focus_cycles int not null default 0,
  last_seen bigint not null default 0
);
alter table public.profiles enable row level security;
create policy "profiles select all logados" on public.profiles for select to authenticated using (true);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid());
create policy "profiles delete own" on public.profiles for delete to authenticated using (id = auth.uid());

-- Assuntos do quadro. Visíveis a todos os logados; só o dono cria/move/apaga.
create table public.cards (
  id text primary key,
  subject text not null,
  area text,
  status text not null default 'todo' check (status in ('todo','doing','done','review')),
  owner_id uuid not null references auth.users(id) on delete cascade,
  reviews_done int not null default 0,
  review_cycle boolean not null default false,
  created_at bigint not null,
  moved_at bigint not null
);
alter table public.cards enable row level security;
create policy "cards select all logados" on public.cards for select to authenticated using (true);
create policy "cards insert own" on public.cards for insert to authenticated with check (owner_id = auth.uid());
create policy "cards update own" on public.cards for update to authenticated using (owner_id = auth.uid());
create policy "cards delete own" on public.cards for delete to authenticated using (owner_id = auth.uid());

-- Config da sala (nome, data da prova) — uma linha só, editável por qualquer
-- pessoa logada (é uma salinha de estudo entre poucas pessoas, sem hierarquia).
create table public.config (
  id int primary key default 1,
  sala text not null default 'Sala CBM-MA',
  exam_date date not null default '2026-10-18'
);
alter table public.config enable row level security;
create policy "config select all logados" on public.config for select to authenticated using (true);
create policy "config update logados" on public.config for update to authenticated using (true);
insert into public.config (id, sala, exam_date) values (1, 'Sala CBM-MA', '2026-10-18');

-- Autoexclusão de conta: só apaga a PRÓPRIA conta (auth.uid()), nunca aceita
-- um id de fora. profiles/cards somem juntos via "on delete cascade" acima.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;
grant execute on function public.delete_my_account() to authenticated;
