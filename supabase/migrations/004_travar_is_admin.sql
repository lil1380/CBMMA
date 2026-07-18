-- Migração 004 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- Fecha uma falha real: a policy "profiles update own" libera a pessoa
-- editar a PRÓPRIA linha inteira, e RLS só controla LINHA, não COLUNA — ou
-- seja, qualquer usuário logado podia rodar, direto pelo console do
-- navegador, algo como:
--   supabase.from('profiles').update({is_admin:true}).eq('id', suaId)
-- e virar administrador sozinho, mesmo sem nenhum botão pra isso existir
-- na interface.
--
-- A partir daqui, a coluna is_admin fica bloqueada para update/insert por
-- qualquer usuário comum — só é alterável rodando SQL diretamente no painel
-- do Supabase (que roda como dono do banco, ignorando essa trava), do jeito
-- que já é feito hoje para promover o primeiro admin.

revoke update (is_admin) on public.profiles from authenticated;
revoke insert (is_admin) on public.profiles from authenticated;
