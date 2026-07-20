-- Cole isto no SQL Editor do Supabase e rode.
-- Lista quais colunas de public.profiles a role "authenticated" pode
-- alterar (UPDATE/INSERT). "is_admin" NÃO deveria aparecer na lista.

select table_name, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public'
  and table_name = 'profiles'
  and grantee = 'authenticated'
  and privilege_type in ('UPDATE','INSERT')
order by column_name, privilege_type;
