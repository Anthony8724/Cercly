-- Preflight de catálogo. Ejecutar con la conexión Staging verificada por separado.
-- No lee filas de Auth de usuarios reales ni escribe datos.
begin read only;
select
    current_setting('server_version') as postgres,
    to_regnamespace('cercly_ugc_privado') is not null as esquema_ugc,
    to_regprocedure('public.ugc_normas_publicacion()') is not null as rpc_normas,
    to_regclass('cercly_rutas_privado.rutas_limites_usuarios') is not null as tabla_cuota,
    to_regprocedure('cercly_account_private.es_referencia_identidad_plataforma(oid)') is not null as detector_fk,
    cercly_account_private.tiene_dependencias('00000000-0000-0000-0000-000000000000') as bloqueo_sin_usuario,
    exists (
        select from pg_catalog.pg_constraint c
        where c.conrelid=to_regclass('cercly_rutas_privado.rutas_limites_usuarios')
            and c.contype='f'
            and cercly_account_private.es_referencia_identidad_plataforma(c.oid)
    ) as cuota_reconocida,
    (
        select jsonb_object_agg(id,public)
        from storage.buckets
        where id in ('establecimientos-imagenes','promociones-imagenes')
    ) as buckets_publicos;

select
    p.oid::regprocedure as rutina,
    pg_catalog.pg_get_userbyid(p.proowner) as propietario,
    p.prosecdef as privilegios_definidor,
    p.proacl as acl,
    p.proconfig as opciones,
    md5(pg_catalog.pg_get_functiondef(p.oid)) as huella_definicion
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where n.nspname='cercly_account_private'
    and p.proname in ('es_referencia_identidad_plataforma','tiene_dependencias','bloqueo_externo_supresion')
order by p.proname;
rollback;
