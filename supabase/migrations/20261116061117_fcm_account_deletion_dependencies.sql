-- Classify only the three FCM references whose exact schema and cascading
-- deletion behavior were reviewed. Any other FK to an identity stays blocking.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $guard$
declare expected integer;
begin
  select count(*) into expected
  from pg_catalog.pg_constraint c
  where c.contype = 'f'
    and c.confrelid = 'auth.users'::regclass
    and c.confdeltype = 'c'
    and c.convalidated
    and (
      (c.conrelid = 'public.push_preferences'::regclass and c.conname = 'push_preferences_user_id_fkey') or
      (c.conrelid = 'public.fcm_installations'::regclass and c.conname = 'fcm_installations_user_id_fkey') or
      (c.conrelid = 'public.promotion_push_reservations'::regclass and c.conname = 'promotion_push_reservations_user_id_fkey')
    )
    and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a
      where a.attrelid = c.conrelid and a.attname = 'user_id' and not a.attisdropped)]
    and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a
      where a.attrelid = c.confrelid and a.attname = 'id' and not a.attisdropped)];
  if expected <> 3 then
    raise exception 'FCM account-deletion constraints differ from reviewed schema';
  end if;
end;
$guard$;

create or replace function cercly_account_private.es_referencia_fcm_cascada(p_constraint oid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1 from pg_catalog.pg_constraint c
    where c.oid=p_constraint and c.contype='f'
      and c.confrelid='auth.users'::regclass and c.confdeltype='c' and c.convalidated
      and (
        (c.conrelid='public.push_preferences'::regclass and c.conname='push_preferences_user_id_fkey') or
        (c.conrelid='public.fcm_installations'::regclass and c.conname='fcm_installations_user_id_fkey') or
        (c.conrelid='public.promotion_push_reservations'::regclass and c.conname='promotion_push_reservations_user_id_fkey')
      )
      and c.conkey=array[(select a.attnum::smallint from pg_catalog.pg_attribute a
        where a.attrelid=c.conrelid and a.attname='user_id' and not a.attisdropped)]
      and c.confkey=array[(select a.attnum::smallint from pg_catalog.pg_attribute a
        where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]
  );
$$;
alter function cercly_account_private.es_referencia_fcm_cascada(oid) owner to postgres;
revoke all on function cercly_account_private.es_referencia_fcm_cascada(oid) from public,anon,authenticated,service_role;

-- Known platform/private identity references, matched by complete signature.
-- Unknown foreign keys in any schema remain blockers.
create or replace function cercly_account_private.es_referencia_identidad_plataforma(p_constraint oid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists (
  select 1 from pg_catalog.pg_constraint c
  join pg_catalog.pg_class t on t.oid=c.conrelid
  join pg_catalog.pg_namespace n on n.oid=t.relnamespace
  join (values
    ('auth','identities','identities_user_id_fkey','user_id','c'),
    ('auth','mfa_factors','mfa_factors_user_id_fkey','user_id','c'),
    ('auth','mfa_recovery_code_sets','mfa_recovery_code_sets_user_id_fkey','user_id','c'),
    ('auth','oauth_authorizations','oauth_authorizations_user_id_fkey','user_id','c'),
    ('auth','oauth_consents','oauth_consents_user_id_fkey','user_id','c'),
    ('auth','one_time_tokens','one_time_tokens_user_id_fkey','user_id','c'),
    ('auth','scim_users','scim_users_user_id_fkey','user_id','n'),
    ('auth','sessions','sessions_user_id_fkey','user_id','c'),
    ('auth','webauthn_challenges','webauthn_challenges_user_id_fkey','user_id','c'),
    ('auth','webauthn_credentials','webauthn_credentials_user_id_fkey','user_id','c'),
    ('cercly_account_private','planes_supresion','planes_supresion_revisor_id_fkey','revisor_id','c'),
    ('cercly_account_private','planes_supresion','planes_supresion_sujeto_id_fkey','sujeto_id','c'),
    ('cercly_account_private','sujetos_qa_supresion','sujetos_qa_supresion_usuario_id_fkey','usuario_id','c')
  ) known(schema_name,table_name,constraint_name,column_name,delete_action)
   on n.nspname=known.schema_name and t.relname=known.table_name and c.conname=known.constraint_name
  where c.oid=p_constraint and c.contype='f' and c.convalidated
   and c.confrelid='auth.users'::regclass and c.confdeltype::text=known.delete_action
   and c.conkey=array[(select a.attnum::smallint from pg_catalog.pg_attribute a
     where a.attrelid=c.conrelid and a.attname=known.column_name and not a.attisdropped)]
   and c.confkey=array[(select a.attnum::smallint from pg_catalog.pg_attribute a
     where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]
 );
$$;
alter function cercly_account_private.es_referencia_identidad_plataforma(oid) owner to postgres;
revoke all on function cercly_account_private.es_referencia_identidad_plataforma(oid) from public,anon,authenticated,service_role;

create or replace function cercly_account_private.tiene_dependencias(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.establecimientos where propietario_id=p_id or verificado_por=p_id)
 or exists(select 1 from public.solicitudes_establecimientos where solicitante_id=p_id or revisado_por=p_id)
 or exists(select 1 from public.correcciones_aplicadas where solicitante_id=p_id or revisado_por=p_id)
 or exists(select 1 from public.auditoria_moderacion_establecimientos where actor_id=p_id)
 or exists(select 1 from cercly_account_private.auditoria_eliminacion a
   where (a.sujeto_id=p_id or a.actor_id=p_id or a.destino_id=p_id)
   and not (a.sujeto_id=p_id and a.actor_id is not null and a.actor_id<>p_id
    and a.accion='aprobar' and a.establecimiento_id is null and a.destino_id is null
    and a.solicitud_id is not distinct from (select solicitud_id from cercly_account_private.solicitudes_eliminacion where usuario_id=p_id)))
 or exists(select 1 from pg_catalog.pg_constraint c
   join pg_catalog.pg_class t on t.oid=c.conrelid
   join pg_catalog.pg_namespace n on n.oid=t.relnamespace
   where c.contype='f' and c.confrelid in
     ('public.usuarios'::regclass,'auth.users'::regclass)
   and not cercly_account_private.es_referencia_fcm_cascada(c.oid)
   and not cercly_account_private.es_referencia_identidad_plataforma(c.oid)
   and not ((c.conrelid = 'public.usuarios'::regclass and c.conname = 'usuarios_id_fkey' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.miembros_establecimiento'::regclass and c.conname = 'miembros_establecimiento_usuario_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='usuario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.establecimientos'::regclass and c.conname = 'establecimientos_propietario_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'r' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='propietario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.solicitudes_establecimientos'::regclass and c.conname = 'solicitudes_establecimientos_solicitante_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'r' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='solicitante_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.establecimientos'::regclass and c.conname = 'establecimientos_verificado_por_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'n' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='verificado_por' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.solicitudes_establecimientos'::regclass and c.conname = 'solicitudes_establecimientos_revisado_por_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'n' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='revisado_por' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.preferencias_usuario'::regclass and c.conname = 'preferencias_usuario_usuario_id_fkey' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='usuario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)])))
 or exists(select 1 from storage.objects where owner_id=p_id::text
   or (bucket_id in ('establecimientos-imagenes','promociones-imagenes') and name like p_id::text||'/%'));
$$;

-- El flujo de supresión revisada usa un detector independiente de bloqueos
-- externos: debe reconocer las mismas tres FK exactas y seguir bloqueando el resto.
create or replace function cercly_account_private.bloqueo_externo_supresion(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.establecimientos where propietario_id=p_id)
 or exists(select 1 from storage.objects where owner_id=p_id::text or name like p_id::text||'/%')
 or exists(select 1 from public.evidencias_solicitud where solicitud_id in
   (select id from public.solicitudes_establecimientos where solicitante_id=p_id or revisado_por=p_id))
 or exists(select 1 from cercly_auth_private.superadministradores where usuario_id=p_id or otorgado_por=p_id or revocado_por=p_id)
 or exists(select 1 from cercly_auth_private.auditoria_superadministradores where usuario_id=p_id or actor_id=p_id)
 or exists(select 1 from public.usuarios where id=p_id and rol='administrador')
 or exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_class t on t.oid=c.conrelid
   join pg_catalog.pg_namespace n on n.oid=t.relnamespace where c.contype='f'
   and c.confrelid in ('public.usuarios'::regclass,'auth.users'::regclass)
   and not cercly_account_private.es_referencia_fcm_cascada(c.oid)
   and not cercly_account_private.es_referencia_identidad_plataforma(c.oid)
   and not ((c.conrelid = 'public.usuarios'::regclass and c.conname = 'usuarios_id_fkey' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.miembros_establecimiento'::regclass and c.conname = 'miembros_establecimiento_usuario_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='usuario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.establecimientos'::regclass and c.conname = 'establecimientos_propietario_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'r' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='propietario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.solicitudes_establecimientos'::regclass and c.conname = 'solicitudes_establecimientos_solicitante_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'r' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='solicitante_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.establecimientos'::regclass and c.conname = 'establecimientos_verificado_por_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'n' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='verificado_por' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.solicitudes_establecimientos'::regclass and c.conname = 'solicitudes_establecimientos_revisado_por_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'n' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='revisado_por' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.preferencias_usuario'::regclass and c.conname = 'preferencias_usuario_usuario_id_fkey' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='usuario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)])));
$$;
alter function cercly_account_private.bloqueo_externo_supresion(uuid) owner to postgres;
revoke all on function cercly_account_private.bloqueo_externo_supresion(uuid) from public,anon,authenticated,service_role;

commit;
