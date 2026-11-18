begin;
select plan(13);

select ok((select relrowsecurity from pg_class where oid='public.push_preferences'::regclass),
  'push preferences have RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.fcm_installations'::regclass),
  'FCM installations have RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.promotion_push_reservations'::regclass),
  'push reservations have RLS enabled');

select ok(not has_any_column_privilege('anon','public.push_preferences','SELECT')
  and not has_any_column_privilege('authenticated','public.push_preferences','SELECT'),
  'clients cannot read consent or quiet-hour records directly');
select ok(not has_any_column_privilege('anon','public.fcm_installations','SELECT')
  and not has_any_column_privilege('authenticated','public.fcm_installations','SELECT'),
  'clients cannot read FCM tokens directly');
select ok(not has_any_column_privilege('anon','public.promotion_push_reservations','SELECT')
  and not has_any_column_privilege('authenticated','public.promotion_push_reservations','SELECT'),
  'clients cannot read other users notification history');

select ok(has_table_privilege('service_role','public.push_preferences','SELECT,INSERT,UPDATE,DELETE')
  and has_table_privilege('service_role','public.fcm_installations','SELECT,INSERT,UPDATE,DELETE')
  and has_table_privilege('service_role','public.promotion_push_reservations','SELECT,INSERT,UPDATE,DELETE'),
  'only the server role receives table access');

select ok(has_function_privilege('authenticated',
  'public.configurar_mis_alertas_push_promociones(boolean,boolean,smallint,smallint,smallint,smallint)','EXECUTE'),
  'authenticated users can update only their own preferences through the RPC');
select ok(has_function_privilege('authenticated',
  'public.registrar_mi_instalacion_fcm(uuid,text,text)','EXECUTE'),
  'authenticated users can register an installation through the owner-checked RPC');
select ok(has_function_privilege('authenticated',
  'public.retirar_mi_instalacion_fcm(uuid)','EXECUTE'),
  'authenticated users can request owner-scoped installation revocation');
select ok(not has_function_privilege('authenticated',
  'public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)','EXECUTE')
  and not has_function_privilege('service_role',
  'public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)','EXECUTE')
  and has_function_privilege('service_role',
  'public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint,uuid)','EXECUTE'),
  'only the server role can reserve a promotional push');
select ok(not has_function_privilege('authenticated',
  'public.finalizar_reserva_promocion_push(uuid,text,text)','EXECUTE')
  and has_function_privilege('service_role',
  'public.finalizar_reserva_promocion_push(uuid,text,text)','EXECUTE'),
  'only the server role can finalize a delivery');

select ok(not exists (
  select 1 from (values
    ('public.configurar_mis_alertas_push_promociones(boolean,boolean,smallint,smallint,smallint,smallint)'::regprocedure, 'search_path=pg_catalog, public'),
    ('public.registrar_mi_instalacion_fcm(uuid,text,text)'::regprocedure, 'search_path=pg_catalog, public'),
    ('public.retirar_mi_instalacion_fcm(uuid)'::regprocedure, 'search_path=pg_catalog, public'),
    ('public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)'::regprocedure, 'search_path=pg_catalog, public, extensions'),
    ('public.finalizar_reserva_promocion_push(uuid,text,text)'::regprocedure, 'search_path=pg_catalog, public')
  ) expected(function_oid, expected_path)
  join pg_proc p on p.oid = expected.function_oid
  where not p.prosecdef or p.proconfig is null
     or not (expected.expected_path = any(p.proconfig))
), 'SECURITY DEFINER functions pin their expected safe search_path');

select * from finish();
rollback;
