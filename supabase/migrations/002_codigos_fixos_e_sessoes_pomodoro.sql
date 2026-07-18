-- Migração 002 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- 1) Torna os códigos de recuperação fixos (não são mais consumidos ao usar).
-- 2) Cria a tabela de sessões de pomodoro, para poder excluir uma sessão
--    que não foi cumprida de verdade.

create or replace function public.reset_password_with_code(p_username text, p_code text, p_new_password text)
returns boolean
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_user_id uuid;
  v_row record;
  v_hash text;
begin
  select id into v_user_id from public.profiles where username = lower(trim(p_username));
  if v_user_id is null then
    perform pg_sleep(0.3);
    return false;
  end if;

  if exists (select 1 from public.recovery_attempts where user_id = v_user_id and locked_until > now()) then
    return false;
  end if;

  -- Códigos fixos: não marcamos used_at, os 5 continuam valendo para sempre.
  for v_row in select id, code_hash, code_salt from public.recovery_codes
               where user_id = v_user_id
  loop
    v_hash := encode(digest(v_row.code_salt || '::' || upper(trim(p_code)), 'sha256'), 'hex');
    if v_hash = v_row.code_hash then
      update auth.users set encrypted_password = crypt(p_new_password, gen_salt('bf')) where id = v_user_id;
      delete from public.recovery_attempts where user_id = v_user_id;
      return true;
    end if;
  end loop;

  insert into public.recovery_attempts (user_id, attempts, locked_until)
  values (v_user_id, 1, null)
  on conflict (user_id) do update set
    attempts = recovery_attempts.attempts + 1,
    locked_until = case when recovery_attempts.attempts + 1 >= 5
                        then now() + interval '15 minutes' else null end;
  return false;
end;
$$;
grant execute on function public.reset_password_with_code(text, text, text) to anon, authenticated;

create table if not exists public.pomodoro_sessions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  minutes numeric not null,
  completed_at bigint not null
);
alter table public.pomodoro_sessions enable row level security;
drop policy if exists "pomodoro select own" on public.pomodoro_sessions;
create policy "pomodoro select own" on public.pomodoro_sessions for select to authenticated using (user_id = auth.uid());
drop policy if exists "pomodoro insert own" on public.pomodoro_sessions;
create policy "pomodoro insert own" on public.pomodoro_sessions for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "pomodoro delete own" on public.pomodoro_sessions;
create policy "pomodoro delete own" on public.pomodoro_sessions for delete to authenticated using (user_id = auth.uid());
