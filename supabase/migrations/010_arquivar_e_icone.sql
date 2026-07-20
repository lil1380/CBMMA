-- Migração 010 — rode isto no SQL Editor do Supabase (não apaga dados).
--
-- 1) Arquivar assuntos concluídos: coluna "archived" em cards, pra sumir
--    da coluna "Concluído" sem apagar de vez (evita poluição visual).
-- 2) Ícone do usuário: coluna "avatar_emoji" em profiles, pra escolher
--    qualquer emoji no lugar das iniciais. A migração 009 já travou o
--    UPDATE de profiles coluna por coluna, então essa coluna nova precisa
--    de um grant explícito, senão ninguém consegue salvar o próprio ícone.

alter table public.cards add column if not exists archived boolean not null default false;

alter table public.profiles add column if not exists avatar_emoji text;
grant update (avatar_emoji) on public.profiles to authenticated;
