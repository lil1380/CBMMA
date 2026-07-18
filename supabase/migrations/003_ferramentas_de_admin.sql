-- Migração 003 — rode isto no SQL Editor do Supabase (não apaga dados por si só).
--
-- Dá ao administrador (profiles.is_admin) ferramentas de limpeza:
--   1) Apagar qualquer assunto (não só os próprios) — via policy de RLS.
--   2) Excluir a conta de outra pessoa por completo (perfil, assuntos,
--      estatísticas, sessões de pomodoro somem juntos pelo ON DELETE CASCADE).
--   3) "Resetar a sala" (apagar todos os assuntos de todo mundo) usa a
--      mesma policy do item 1, sem precisar de função nova.

drop policy if exists "cards delete admin" on public.cards;
create policy "cards delete admin" on public.cards for delete to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

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
