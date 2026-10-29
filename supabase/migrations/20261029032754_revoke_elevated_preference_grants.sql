begin;

-- Los grants predeterminados de Supabase pueden conceder privilegios elevados
-- sobre tablas creadas después de la migración global de mínimo privilegio.
-- RLS no protege frente a TRUNCATE ni debe permitirse crear triggers o FKs.
revoke truncate, references, trigger, maintain
  on table public.preferencias_usuario,
           public.preferencias_usuario_categorias
  from public, anon, authenticated;

commit;
