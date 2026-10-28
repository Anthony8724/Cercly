-- Limita privilegios amplios heredados del esquema inicial.
-- RLS sigue definiendo las filas accesibles; la capa SQL además niega DML
-- anónimo y privilegios DDL innecesarios para clientes autenticados.
-- es_administrador() conserva EXECUTE para anon porque las políticas SELECT
-- públicas la invocan; auth.uid() nulo hace que devuelva false para anon.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

revoke insert, update, delete, truncate, references, trigger, maintain
  on all tables in schema public from anon;

revoke truncate, references, trigger, maintain
  on all tables in schema public from authenticated;

commit;
