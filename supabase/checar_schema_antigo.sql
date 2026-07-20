-- Cole isto no SQL Editor do Supabase e rode.
-- Checa se restos do schema antigo (sala sem login, aberta por chave "anon")
-- ainda estão ativos. Não altera nada — é só leitura.

select 'cards anon all (perigosa)' as item,
  exists(select 1 from pg_policies where schemaname='public' and tablename='cards' and policyname='cards anon all') as existe
union all
select 'presence anon all (perigosa)',
  exists(select 1 from pg_policies where schemaname='public' and tablename='presence' and policyname='presence anon all')
union all
select 'stats anon all (perigosa)',
  exists(select 1 from pg_policies where schemaname='public' and tablename='stats' and policyname='stats anon all')
union all
select 'config anon all (perigosa)',
  exists(select 1 from pg_policies where schemaname='public' and tablename='config' and policyname='config anon all')
union all
select 'cards.owner_id ainda é text (schema antigo)',
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='cards' and column_name='owner_id' and data_type='text')
union all
select 'tabela presence existe (obsoleta)',
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='presence')
union all
select 'tabela stats existe (obsoleta)',
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='stats');
