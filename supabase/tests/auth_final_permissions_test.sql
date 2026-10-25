-- Solo instancia local aislada. Comprueba permisos efectivos, incluidos PUBLIC
-- y grants de columna; el arnés puede inyectarlos antes de las migraciones.
begin;
select plan(19);
select ok(has_schema_privilege('authenticated','auth','USAGE'), 'plataforma permite resolver auth.uid');
select ok(has_function_privilege('authenticated','auth.uid()','EXECUTE'), 'plataforma permite ejecutar auth.uid');
select ok(not has_any_column_privilege('anon','public.usuarios','SELECT'), 'anon sin lectura de columnas');
select ok(not has_any_column_privilege('anon','public.usuarios','INSERT'), 'anon sin inserción de columnas');
select ok(not has_any_column_privilege('anon','public.usuarios','UPDATE'), 'anon sin actualización de columnas');
select ok(not has_any_column_privilege('authenticated','public.usuarios','INSERT'), 'authenticated sin inserción de columnas');
select ok(not has_any_column_privilege('authenticated','public.usuarios','REFERENCES'), 'authenticated sin referencias de columnas');
select ok(has_column_privilege('authenticated','public.usuarios','nombre','UPDATE'), 'conserva edición de nombre');
select ok(not exists (
  select 1 from pg_attribute where attrelid='public.usuarios'::regclass
    and attnum>0 and not attisdropped and attname<>'nombre'
    and has_column_privilege('authenticated',attrelid,attnum,'UPDATE')
), 'ninguna otra columna editable');
select ok(not exists (
  select 1 from unnest(array['anon','authenticated']) r,
    unnest(array['usuarios','establecimientos','solicitudes_establecimientos','miembros_establecimiento','promociones']) t
  where has_table_privilege(r, 'public.'||t, 'MAINTAIN')
), 'clientes sin MAINTAIN en las cinco tablas');
select ok(not has_schema_privilege('anon','cercly_auth_private','USAGE'), 'anon sin esquema privado');
select ok(not has_schema_privilege('authenticated','cercly_auth_private','CREATE'), 'cliente no crea funciones privadas');
select ok(not has_function_privilege('anon','cercly_auth_private.recuperar_perfil_actual()','EXECUTE'), 'anon sin helper privilegiado');
select ok(not exists (
  select 1 from pg_proc where oid in (
    'public.crear_perfil_nuevo_usuario()'::regprocedure,
    'public.convertir_en_propietario()'::regprocedure,
    'cercly_auth_private.recuperar_perfil_actual()'::regprocedure)
  and (not prosecdef or not ('search_path=""'=any(proconfig))
       or proowner <> (select relowner from pg_class where oid='public.usuarios'::regclass)
       or pg_get_userbyid(proowner) not in ('postgres','supabase_admin'))
), 'definers del propietario de usuarios y search_path vacío');
select ok(exists (select 1 from pg_trigger where tgrelid='auth.users'::regclass
  and tgname='crear_perfil_despues_del_registro' and tgenabled='O'
  and tgtype=5 and tgfoid='public.crear_perfil_nuevo_usuario()'::regprocedure),
  'trigger Auth activo AFTER INSERT por fila');
select ok(exists (select 1 from pg_policy where polrelid='public.establecimientos'::regclass
  and polname='alta sin verificacion autoconcedida' and not polpermissive and polcmd='a'),
  'barrera restrictiva de verificación instalada');
set local role authenticated;
select throws_ok('select count(*) from auth.users', '42501',null,
  'resolver auth.uid no permite leer cuentas Auth');
select throws_ok($$select cercly_auth_private.insertar_perfil_basico(gen_random_uuid(),'{}',null)$$,
  '42501',null,'helper parametrizado inaccesible incluso por SQL directo');
reset role;
set local role anon;
select throws_ok('select * from public.recuperar_mi_perfil()',
  '42501',null,'RPC deniega ejecución anónima real');
reset role;
select * from finish();
rollback;
