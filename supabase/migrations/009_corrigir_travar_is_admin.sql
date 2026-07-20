-- Migração 009 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- Corrige a migração 004. O revoke por coluna sozinho não bastava: o
-- Supabase já concede GRANT UPDATE/INSERT de TABELA inteira pra role
-- "authenticated" por padrão, e um privilégio de tabela permite alterar
-- qualquer coluna — inclusive is_admin — mesmo com um revoke específico
-- daquela coluna em cima. É por isso que, mesmo depois de rodar a 004,
-- a checagem mostrava is_admin ainda editável.
--
-- Aqui a gente revoga o privilégio de TABELA inteira e devolve, coluna
-- por coluna, só o que o app realmente precisa escrever — sem is_admin.

revoke update on public.profiles from authenticated;
revoke insert on public.profiles from authenticated;

-- cadastro só precisa inserir estas três colunas (as demais têm default)
grant insert (id, username, display_name) on public.profiles to authenticated;

-- o app só atualiza estas colunas ao longo do uso normal
grant update (
  display_name, streak, last_active_date, focus_minutes, focus_cycles, last_seen,
  daily_goal_type, daily_goal_value, daily_day, daily_subjects_done, daily_minutes
) on public.profiles to authenticated;
