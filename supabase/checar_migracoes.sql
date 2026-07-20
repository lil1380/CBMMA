-- Cole isto no SQL Editor do Supabase e rode.
-- Cada linha mostra "true" (já aplicada) ou "false" (falta rodar).
-- Não altera nada — é só leitura.

select '002 - tabela pomodoro_sessions' as item,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='pomodoro_sessions') as ok
union all
select '003 - policy "cards delete admin"',
  exists(select 1 from pg_policies where schemaname='public' and tablename='cards' and policyname='cards delete admin')
union all
select '003 - função admin_delete_user',
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='admin_delete_user')
union all
select '004 - is_admin protegido (revoke aplicado)',
  not has_column_privilege('authenticated', 'public.profiles', 'is_admin', 'UPDATE')
union all
select '005 - coluna profiles.daily_goal_type',
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='daily_goal_type')
union all
select '006 - tabela study_events',
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='study_events')
union all
select '007 - tabela personal_notes',
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='personal_notes')
union all
select '008 - coluna cards.link',
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='cards' and column_name='link')
union all
select '008 - tabela personal_links',
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='personal_links')
union all
select '009 - is_admin sem privilégio de tabela',
  not has_column_privilege('authenticated', 'public.profiles', 'is_admin', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.profiles', 'is_admin', 'INSERT')
union all
select '010 - coluna cards.archived',
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='cards' and column_name='archived')
union all
select '010 - coluna profiles.avatar_emoji (com grant de update)',
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='avatar_emoji')
  and has_column_privilege('authenticated', 'public.profiles', 'avatar_emoji', 'UPDATE');
