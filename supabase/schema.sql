-- Sala de Estudos — Painel de Prontidão (CBM-MA)
-- Rode este script inteiro no Supabase: Dashboard > SQL Editor > New query > Run.
--
-- Este arquivo é a referência do schema completo (útil para uma instalação
-- do zero). Depois da primeira vez, NÃO rode este arquivo de novo — ele
-- apaga tudo (contas, assuntos, estatísticas) para recriar as tabelas.
-- Ajustes seguintes vão em supabase/migrations/*.sql, que só alteram o que
-- mudou, sem apagar dados existentes.
--
-- Login por usuário + senha, sem e-mail e sem SMTP. Recuperação de senha por
-- dois caminhos, os dois sem depender de nenhum serviço externo:
--   1) Códigos de recuperação (5 códigos fixos, gerados no cadastro —
--      continuam válidos mesmo depois de usados).
--   2) Reset pelo administrador (código temporário de 24h, entregue fora do
--      sistema — WhatsApp, presencial).
--
-- IMPORTANTE — passo manual no painel do Supabase:
-- Authentication > Providers > Email > desmarque "Confirm email".
-- Sem isso, o Supabase tenta confirmar um e-mail que não existe de verdade
-- (usamos um e-mail sintético só para o login funcionar por baixo dos panos)
-- e ninguém consegue entrar depois de se cadastrar.

create extension if not exists pgcrypto;

drop function if exists public.delete_my_account();
drop function if exists public.admin_delete_user(text);
drop function if exists public.reset_password_with_code(text, text, text);
drop function if exists public.reset_password_with_admin_code(text, text, text);
drop function if exists public.admin_generate_reset_code(text);
drop table if exists public.recovery_attempts;
drop table if exists public.admin_reset_codes;
drop table if exists public.recovery_codes;
drop table if exists public.presence;
drop table if exists public.stats;
drop table if exists public.cards;
drop table if exists public.config;
drop table if exists public.profiles;

-- Perfil público de cada conta: usuário de login, nome exibido, se é admin,
-- estatísticas pessoais e presença (last_seen).
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  is_admin boolean not null default false,
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
-- RLS só controla linha, não coluna: sem isto, qualquer pessoa logada
-- poderia editar a própria is_admin direto pela API e virar administrador.
revoke update (is_admin) on public.profiles from authenticated;
revoke insert (is_admin) on public.profiles from authenticated;

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
create policy "cards delete admin" on public.cards for delete to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

-- Config da sala (nome, data da prova) — uma linha só.
create table public.config (
  id int primary key default 1,
  sala text not null default 'Sala CBM-MA',
  exam_date date not null default '2026-10-18'
);
alter table public.config enable row level security;
create policy "config select all logados" on public.config for select to authenticated using (true);
create policy "config update logados" on public.config for update to authenticated using (true);
insert into public.config (id, sala, exam_date) values (1, 'Sala CBM-MA', '2026-10-18');

-- Sessões de foco (pomodoro) registradas individualmente, para poder
-- excluir uma sessão que não foi cumprida de verdade. Cada linha também
-- soma em profiles.focus_minutes/focus_cycles (feito pelo cliente).
create table public.pomodoro_sessions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  minutes numeric not null,
  completed_at bigint not null
);
alter table public.pomodoro_sessions enable row level security;
create policy "pomodoro select own" on public.pomodoro_sessions for select to authenticated using (user_id = auth.uid());
create policy "pomodoro insert own" on public.pomodoro_sessions for insert to authenticated with check (user_id = auth.uid());
create policy "pomodoro delete own" on public.pomodoro_sessions for delete to authenticated using (user_id = auth.uid());

-- ===== Recuperação de senha sem e-mail =====

-- Códigos de recuperação: gerados no cadastro, mostrados 1x, guardados só
-- como hash+salt. INSERT é permitido pelo próprio dono (feito logo após o
-- cadastro, com sessão ativa); a verificação (sem sessão) passa só pela
-- função abaixo — não existe policy de SELECT, então ninguém lê hash de
-- ninguém pela API.
create table public.recovery_codes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  code_salt text not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.recovery_codes enable row level security;
create policy "recovery_codes insert own" on public.recovery_codes for insert to authenticated with check (user_id = auth.uid());

-- Códigos de reset gerados por um administrador para outra pessoa (válidos
-- 24h). Também sem policy de SELECT — só a função abaixo mexe aqui.
create table public.admin_reset_codes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  code_salt text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz
);
alter table public.admin_reset_codes enable row level security;

-- Controle de tentativas para travar força bruta nos códigos de recuperação.
create table public.recovery_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  attempts int not null default 0,
  locked_until timestamptz
);
alter table public.recovery_attempts enable row level security;

-- Confere um código de recuperação e, se bater, troca a senha direto
-- (mesmo formato bcrypt que o Supabase Auth usa). Chamável sem estar
-- logado — é exatamente o caso de uso de "esqueci minha senha".
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

  -- Os códigos são fixos (reutilizáveis) por pedido do usuário: não marcamos
  -- used_at, então os 5 continuam valendo para sempre.
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

-- Gera um código de reset de 24h para outra pessoa. Só quem é admin
-- (profiles.is_admin) pode chamar. Retorna o código em texto puro — a
-- ÚNICA vez que ele existe fora do hash — para o admin repassar por fora.
create or replace function public.admin_generate_reset_code(p_username text)
returns text
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_is_admin boolean;
  v_user_id uuid;
  v_code text;
  v_salt text;
begin
  select is_admin into v_is_admin from public.profiles where id = auth.uid();
  if not coalesce(v_is_admin, false) then
    raise exception 'Apenas administradores podem gerar códigos de reset.';
  end if;

  select id into v_user_id from public.profiles where username = lower(trim(p_username));
  if v_user_id is null then
    raise exception 'Usuário não encontrado.';
  end if;

  v_code := upper(regexp_replace(encode(gen_random_bytes(8), 'base64'), '[^A-Za-z0-9]', '', 'g'));
  v_code := substr(v_code, 1, 8);
  v_salt := encode(gen_random_bytes(16), 'hex');

  insert into public.admin_reset_codes (user_id, code_hash, code_salt, created_by, expires_at)
  values (v_user_id, encode(digest(v_salt || '::' || v_code, 'sha256'), 'hex'), v_salt, auth.uid(), now() + interval '24 hours');

  return v_code;
end;
$$;
grant execute on function public.admin_generate_reset_code(text) to authenticated;

-- Confere um código de reset emitido por admin e troca a senha. Também
-- chamável sem estar logado.
create or replace function public.reset_password_with_admin_code(p_username text, p_code text, p_new_password text)
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

  select id, code_hash, code_salt into v_row from public.admin_reset_codes
    where user_id = v_user_id and used_at is null and expires_at > now()
    order by created_at desc limit 1;
  if v_row is null then
    return false;
  end if;

  v_hash := encode(digest(v_row.code_salt || '::' || upper(trim(p_code)), 'sha256'), 'hex');
  if v_hash <> v_row.code_hash then
    return false;
  end if;

  update public.admin_reset_codes set used_at = now() where id = v_row.id;
  update auth.users set encrypted_password = crypt(p_new_password, gen_salt('bf')) where id = v_user_id;
  return true;
end;
$$;
grant execute on function public.reset_password_with_admin_code(text, text, text) to anon, authenticated;

-- Autoexclusão de conta: só apaga a PRÓPRIA conta (auth.uid()).
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

-- Admin exclui a conta de outra pessoa (nunca a própria — use delete_my_account).
create or replace function public.admin_delete_user(p_username text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_is_admin boolean;
  v_target uuid;
begin
  select is_admin into v_is_admin from public.profiles where id = auth.uid();
  if not coalesce(v_is_admin, false) then
    raise exception 'Apenas administradores podem excluir contas de outras pessoas.';
  end if;

  select id into v_target from public.profiles where username = lower(trim(p_username));
  if v_target is null then
    raise exception 'Usuário não encontrado.';
  end if;

  if v_target = auth.uid() then
    raise exception 'Use "Excluir minha conta" para apagar a própria conta.';
  end if;

  delete from auth.users where id = v_target;
end;
$$;
grant execute on function public.admin_delete_user(text) to authenticated;

-- Depois de rodar este script e criar sua conta pelo site, torne-se admin
-- rodando (troque 'seu_usuario' pelo usuário que você escolheu):
--   update public.profiles set is_admin = true where username = 'seu_usuario';
