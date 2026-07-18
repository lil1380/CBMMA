-- Migração 007 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- Bloco de notas pessoal: motivação, sonhos, conquistas, mensagens pra
-- lembrar. Só o próprio dono vê — nem outros usuários, nem admin.

create table if not exists public.personal_notes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  created_at bigint not null
);
alter table public.personal_notes enable row level security;
drop policy if exists "personal_notes select own" on public.personal_notes;
create policy "personal_notes select own" on public.personal_notes for select to authenticated using (user_id = auth.uid());
drop policy if exists "personal_notes insert own" on public.personal_notes;
create policy "personal_notes insert own" on public.personal_notes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "personal_notes delete own" on public.personal_notes;
create policy "personal_notes delete own" on public.personal_notes for delete to authenticated using (user_id = auth.uid());
