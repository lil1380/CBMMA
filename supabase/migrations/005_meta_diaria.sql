-- Migração 005 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- Meta diária pessoal: cada um escolhe se quer acompanhar por quantidade de
-- assuntos concluídos no dia, ou por minutos de foco no dia (via pomodoro).

alter table public.profiles add column if not exists daily_goal_type text not null default 'subjects'
  check (daily_goal_type in ('subjects','time'));
alter table public.profiles add column if not exists daily_goal_value numeric not null default 3;
alter table public.profiles add column if not exists daily_day date;
alter table public.profiles add column if not exists daily_subjects_done int not null default 0;
alter table public.profiles add column if not exists daily_minutes numeric not null default 0;
