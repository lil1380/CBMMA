-- Migração 006 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- Registro de eventos de estudo: cada vez que um assunto é concluído ou
-- revisado vira uma linha com data/hora, pra alimentar o painel pessoal
-- de histórico (calendário + lista por assunto).

create table if not exists public.study_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id text,
  subject text not null,
  area text,
  event_type text not null check (event_type in ('estudado','revisado')),
  at bigint not null
);
alter table public.study_events enable row level security;
drop policy if exists "study_events select own" on public.study_events;
create policy "study_events select own" on public.study_events for select to authenticated using (user_id = auth.uid());
drop policy if exists "study_events insert own" on public.study_events;
create policy "study_events insert own" on public.study_events for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "study_events delete own" on public.study_events;
create policy "study_events delete own" on public.study_events for delete to authenticated using (user_id = auth.uid());
