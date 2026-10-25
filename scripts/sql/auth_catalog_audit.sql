-- Solo catálogos: no contiene filas Auth, claves, contraseñas ni tokens.
-- Normalizar resolución al serializar expresiones RLS entre distintas bases.
\set QUIET 1
set search_path = pg_catalog;
select jsonb_pretty(jsonb_build_object(
  'version', current_setting('server_version'),
  'roles', (select jsonb_agg(jsonb_build_object('name',rolname,
    'superuser',rolsuper,'bypassrls',rolbypassrls,'inherit',rolinherit,
    'login',rolcanlogin) order by rolname) from pg_roles
    where rolname in ('postgres','supabase_admin','supabase_auth_admin','anon','authenticated','authenticator','service_role')),
  'memberships', (select jsonb_agg(jsonb_build_object('role',pg_get_userbyid(roleid),
    'member',pg_get_userbyid(member),'admin',admin_option,
    'inherit',inherit_option,'set',set_option) order by roleid,member)
    from pg_auth_members),
  'schemas', (select jsonb_agg(jsonb_build_object('name',nspname,
    'owner',pg_get_userbyid(nspowner),'acl',nspacl::text,
    'authenticated_usage',has_schema_privilege('authenticated',oid,'USAGE'),
    'authenticated_create',has_schema_privilege('authenticated',oid,'CREATE'),
    'anon_usage',has_schema_privilege('anon',oid,'USAGE')) order by nspname)
    from pg_namespace where nspname in ('public','auth','storage','extensions','cercly_auth_private')),
  'tables', (select jsonb_agg(jsonb_build_object('name',n.nspname||'.'||c.relname,
    'owner',pg_get_userbyid(c.relowner),'acl',c.relacl::text,
    'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
    'authenticated_select',has_table_privilege('authenticated',c.oid,'SELECT'),
    'authenticated_insert',has_table_privilege('authenticated',c.oid,'INSERT')) order by n.nspname,c.relname)
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where (n.nspname='public' and c.relname in ('usuarios','establecimientos','miembros_establecimiento'))
       or (n.nspname='auth' and c.relname='users')),
  'functions', (select jsonb_agg(jsonb_build_object('name',n.nspname||'.'||p.proname,
    'args',pg_get_function_identity_arguments(p.oid),'owner',pg_get_userbyid(p.proowner),
    'definer',p.prosecdef,'settings',p.proconfig,'acl',p.proacl::text,
    'definition_md5',md5(pg_get_functiondef(p.oid)),
    'definition',pg_get_functiondef(p.oid),
    'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'),
    'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE')) order by n.nspname,p.proname)
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='auth' and p.proname='uid')
       or n.nspname='cercly_auth_private'
       or (n.nspname='public' and p.proname in ('crear_perfil_nuevo_usuario','proteger_rol_usuario','es_administrador','recuperar_mi_perfil'))),
  'policies', (select jsonb_agg(jsonb_build_object('table',polrelid::regclass::text,
    'name',polname,'permissive',polpermissive,'command',polcmd,
    'using',pg_get_expr(polqual,polrelid),'check',pg_get_expr(polwithcheck,polrelid)) order by polname)
    from pg_policy where polrelid='public.usuarios'::regclass)
));
