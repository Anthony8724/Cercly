-- The preferences RPC is a user-facing operation and is invoked with the
-- authenticated user's JWT. Remove the legacy explicit server-role grant.
revoke execute on function public.guardar_preferencias_usuario(
  pg_catalog.uuid[], pg_catalog.int4, pg_catalog.bool, pg_catalog.int8
) from service_role;
