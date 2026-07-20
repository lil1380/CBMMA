-- Migração 008 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- Links de estudo: (1) um link opcional por assunto (videoaula, lista de
-- questões etc.), visível pra sala inteira junto do card, só o dono edita;
-- (2) uma lista de links pessoais, só o próprio dono vê.

alter table public.cards add column if not exists link text;

create table if not exists public.personal_links (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  url text not null,
  created_at bigint not null
);
alter table public.personal_links enable row level security;
drop policy if exists "personal_links select own" on public.personal_links;
create policy "personal_links select own" on public.personal_links for select to authenticated using (user_id = auth.uid());
drop policy if exists "personal_links insert own" on public.personal_links;
create policy "personal_links insert own" on public.personal_links for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "personal_links delete own" on public.personal_links;
create policy "personal_links delete own" on public.personal_links for delete to authenticated using (user_id = auth.uid());
