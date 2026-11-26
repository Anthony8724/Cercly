-- Preparación local UGC. No desplegar ni aprobar textos legales implícitamente.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
create schema cercly_ugc_privado;
revoke all on schema cercly_ugc_privado from public,anon,authenticated,service_role;
create table cercly_ugc_privado.normas (
 version text primary key, texto text not null, huella text not null,
 vigente boolean not null default false, creada_en timestamptz not null default now()
);
create unique index normas_una_vigente on cercly_ugc_privado.normas(vigente) where vigente;
insert into cercly_ugc_privado.normas(version,texto,huella,vigente)
select 'ugc-2026-11-20-v1',texto,encode(extensions.digest(texto,'sha256'),'hex'),true
from (values ('Normas de publicación de Cercly
Publica únicamente información veraz de negocios que estés autorizado a gestionar y fotografías, textos y promociones sobre los que tengas derechos.
Se prohíben contenido ofensivo, acoso, amenazas, odio, discriminación, violencia, explotación sexual, material sexual explícito, actividades ilegales, suplantación, fraude, publicidad engañosa, spam y vulneraciones de derechos de autor, marcas, intimidad o derechos de terceros.
No publiques datos privados de clientes o de otras personas sin autorización ni credenciales.
Puedes denunciar fichas, fotografías, promociones y responsables dentro de Cercly y bloquear al responsable de una publicación. El bloqueo oculta para tu cuenta sus establecimientos y publicaciones; puedes revertirlo en Seguridad y contenido.
Los administradores revisan denuncias y pueden retirar contenido del catálogo, dejando un registro mínimo de la decisión. Denunciar no retira automáticamente el contenido ni autoriza borrados de datos compartidos.
Al aceptar confirmas que has leído estas normas antes de aportar contenido. La aceptación se registra para tu cuenta con versión, huella y fecha del servidor.')) n(texto);
create table cercly_ugc_privado.aceptaciones (
 usuario_id uuid not null references auth.users(id) on delete cascade,
 version text not null references cercly_ugc_privado.normas(version), huella text not null,
 aceptada_en timestamptz not null default now(), primary key(usuario_id,version)
);
create table cercly_ugc_privado.bloqueos (
 usuario_id uuid not null references auth.users(id) on delete cascade,
 bloqueado_id uuid not null references auth.users(id) on delete cascade,
 referencia text not null check(char_length(referencia) between 1 and 120),
 creado_en timestamptz not null default now(), primary key(usuario_id,bloqueado_id),
 check(usuario_id<>bloqueado_id)
);
create table cercly_ugc_privado.denuncias (
 id uuid primary key default gen_random_uuid(),
 denunciante_id uuid references auth.users(id) on delete set null,
 tipo text not null check(tipo in ('establecimiento','fotografia','promocion','propietario')),
 objetivo_id uuid not null,
 responsable_id uuid references auth.users(id) on delete set null,
 motivo text not null check(motivo in ('ofensivo','ilegal','enganoso','discriminatorio','derechos','privacidad','spam','otro')),
 detalle text not null check(char_length(detalle) between 0 and 500),
 estado text not null default 'nueva' check(estado in ('nueva','en_revision','retirada','desestimada')),
 creada_en timestamptz not null default now(), actualizada_en timestamptz not null default now()
);
create unique index denuncia_abierta_unica on cercly_ugc_privado.denuncias(denunciante_id,tipo,objetivo_id) where estado in ('nueva','en_revision');
create index denuncias_cuota on cercly_ugc_privado.denuncias(denunciante_id,creada_en);
create table cercly_ugc_privado.retirados (
 tipo text not null, objetivo_id uuid not null,
 responsable_id uuid references auth.users(id) on delete set null,
 retirada_en timestamptz not null default now(), primary key(tipo,objetivo_id)
);
create table cercly_ugc_privado.revisiones (
 id bigint generated always as identity primary key,
 denuncia_id uuid not null references cercly_ugc_privado.denuncias(id),
 revisor_id uuid references auth.users(id) on delete set null,
 estado_anterior text not null, estado_nuevo text not null,
 motivo text not null check(char_length(motivo) between 10 and 500), creada_en timestamptz not null default now()
);
do $$ declare t text; begin
 foreach t in array array['normas','aceptaciones','bloqueos','denuncias','retirados','revisiones'] loop
 execute format('alter table cercly_ugc_privado.%I enable row level security',t);
 execute format('revoke all on cercly_ugc_privado.%I from public,anon,authenticated,service_role',t);
 end loop;
end $$;

create function cercly_ugc_privado.exigir_sesion() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s uuid;
begin
 if u is null or not exists(select 1 from auth.users where id=u) then raise exception using errcode='28000',message='Sesión requerida'; end if;
 begin s:=(auth.jwt()->>'session_id')::uuid; exception when invalid_text_representation then s:=null; end;
 if s is null or not exists(select 1 from auth.sessions where id=s and user_id=u) then raise exception using errcode='28000',message='Sesión no vigente'; end if;
 return u;
end $$;
create function public.ugc_normas_publicacion() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('version',version,'texto',texto,'huella',huella,
 'aceptadas',exists(select 1 from cercly_ugc_privado.aceptaciones a where a.usuario_id=auth.uid() and a.version=n.version and a.huella=n.huella))
 from cercly_ugc_privado.normas n where vigente;
$$;
create function public.ugc_aceptar_normas(p_version text,p_huella text) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); n cercly_ugc_privado.normas;
begin
 select * into n from cercly_ugc_privado.normas where vigente for share;
 if n.version is null or p_version is distinct from n.version or p_huella is distinct from n.huella then raise exception using errcode='22023',message='Las normas han cambiado. Vuelve a leerlas.'; end if;
 insert into cercly_ugc_privado.aceptaciones(usuario_id,version,huella) values(u,n.version,n.huella) on conflict do nothing;
end $$;
create function public.ugc_exigir_normas() returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion();
begin
 if not exists(select 1 from cercly_ugc_privado.aceptaciones a join cercly_ugc_privado.normas n using(version,huella) where a.usuario_id=u and n.vigente) then
 raise exception using errcode='42501',message='Debes aceptar las normas de publicación vigentes antes de aportar contenido.'; end if;
 return true;
end $$;

-- El responsable es la cuenta propietaria del negocio, también para aportes
-- de colaboradores en su nombre. No inferir identidades de correos o del cliente.
create function cercly_ugc_privado.negocio(p_tipo text,p_id uuid) returns uuid language sql stable security definer set search_path='' as $$
 select case when p_tipo in ('establecimiento','propietario') then (select id from public.establecimientos where id=p_id)
 when p_tipo='fotografia' then (select establecimiento_id from public.fotos_establecimiento where id=p_id)
 when p_tipo='promocion' then (select establecimiento_id from public.promociones where id=p_id) end;
$$;
-- Los predicados SELECT evalúan la fila actual, incluida INSERT ... RETURNING.
-- El helper lee solo la moderación privada y los bloqueos de la sesión.
create function cercly_ugc_privado.visible_fila(
 p_tipo text, p_id uuid, p_negocio uuid, p_responsable uuid
) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(auth.uid()=p_responsable,false) or public.es_administrador() or (
   not exists(select 1 from cercly_ugc_privado.retirados r where
     (r.tipo='establecimiento' and r.objetivo_id=p_negocio)
     or (r.tipo=p_tipo and r.objetivo_id=p_id)
     or (r.tipo='propietario' and r.responsable_id=p_responsable))
   and not exists(select 1 from cercly_ugc_privado.bloqueos b
     where b.usuario_id=auth.uid() and b.bloqueado_id=p_responsable)
 );
$$;

-- Solo para los RPC autorizados que resuelven un objetivo ya confirmado.
create function cercly_ugc_privado.visible_objetivo(p_tipo text,p_id uuid)
returns boolean language sql stable set search_path='' as $$
 select coalesce((
   select cercly_ugc_privado.visible_fila(p_tipo,p_id,e.id,e.propietario_id)
   from public.establecimientos e
   where e.id=cercly_ugc_privado.negocio(p_tipo,p_id)
     and (p_tipo<>'promocion' or exists (
       select 1 from public.promociones p
       where p.id=p_id and p.activa and now() between p.fecha_inicio and p.fecha_fin
     ))
 ),false);
$$;

create policy ugc_catalogo on public.establecimientos as restrictive
for select to anon,authenticated using (
 cercly_ugc_privado.visible_fila('establecimiento',id,id,propietario_id)
);
create policy ugc_fotos on public.fotos_establecimiento as restrictive
for select to anon,authenticated using (
 exists (select 1 from public.establecimientos e
   where e.id=establecimiento_id
     and cercly_ugc_privado.visible_fila('fotografia',fotos_establecimiento.id,e.id,e.propietario_id))
);
create policy ugc_promociones on public.promociones as restrictive
for select to anon,authenticated using (
 exists (select 1 from public.establecimientos e
   where e.id=establecimiento_id
     and cercly_ugc_privado.visible_fila('promocion',promociones.id,e.id,e.propietario_id))
);
create policy ugc_destacadas on public.promociones_destacadas as restrictive
for select to anon,authenticated using (
 exists (select 1 from public.promociones p where p.id=promocion_id)
);

-- Las políticas SELECT existentes de Storage ya consultan fotos y
-- promociones aplicando el RLS del solicitante. Conservan sus excepciones
-- para propietario, administración y gestión delegada.
create policy ugc_storage_subida on storage.objects as restrictive for insert to authenticated with check(bucket_id not in ('establecimientos-imagenes','promociones-imagenes') or public.ugc_exigir_normas());
create policy ugc_storage_actualizacion on storage.objects as restrictive for update to authenticated using(true) with check(bucket_id not in ('establecimientos-imagenes','promociones-imagenes') or public.ugc_exigir_normas());

create function cercly_ugc_privado.proteger_publicacion() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 -- SQL de mantenimiento/servicios confiables no tiene identidad de cliente.
 -- RLS/grants anteriores siguen siendo obligatorios; no se da acceso anónimo.
 if auth.uid() is null then return new; end if;
 -- Desactivar una promoción existente reduce la publicación.
 if tg_op='UPDATE' and tg_table_name='promociones' and to_jsonb(new)->>'activa'='false'
 and (to_jsonb(new)-array['activa','actualizado_en'])=(to_jsonb(old)-array['activa','actualizado_en'])
 then return new; end if;
 -- Aprobar una solicitud ya presentada no equivale a aportar contenido.
 -- Los RPC existentes validan al administrador antes de escribir como su dueño.
 if current_user in ('postgres','supabase_admin') and public.es_administrador()
 and tg_table_name in ('establecimientos','horarios_establecimiento','solicitudes_establecimientos')
 then return new; end if;
 if tg_op='UPDATE' and tg_table_name='establecimientos' and
 (to_jsonb(new)-array['estado','publicable','verificado_por','verificado_en','actualizado_en'])
 = (to_jsonb(old)-array['estado','publicable','verificado_por','verificado_en','actualizado_en']) then return new; end if;
 perform public.ugc_exigir_normas();
 return new;
end $$;
do $$ declare t text; begin
 foreach t in array array['establecimientos','fotos_establecimiento','promociones','horarios_establecimiento','solicitudes_establecimientos'] loop
 execute format('create trigger ugc_aceptacion before insert or update on public.%I for each row execute function cercly_ugc_privado.proteger_publicacion()',t);
 end loop;
end $$;

create function public.ugc_denunciar(p_tipo text,p_objetivo_id uuid,p_motivo text,p_detalle text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); b uuid; responsable uuid; r uuid;
begin
 if p_tipo not in ('establecimiento','fotografia','promocion','propietario') or p_tipo is null
 or p_motivo not in ('ofensivo','ilegal','enganoso','discriminatorio','derechos','privacidad','spam','otro') or p_motivo is null
 or p_detalle is null or char_length(p_detalle)>500 then raise exception using errcode='22023',message='Denuncia inválida'; end if;
 b:=cercly_ugc_privado.negocio(p_tipo,p_objetivo_id);
 select propietario_id into responsable from public.establecimientos where id=b and estado='aprobado' and publicable;
 if not found or not cercly_ugc_privado.visible_objetivo(p_tipo,p_objetivo_id) or responsable=u or (p_tipo='propietario' and responsable is null) then raise exception using errcode='42501',message='Contenido no disponible para denunciar'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,20261120));
 select id into r from cercly_ugc_privado.denuncias where denunciante_id=u and tipo=p_tipo and objetivo_id=p_objetivo_id and estado in ('nueva','en_revision');
 if found then return r; end if;
 if (select count(*) from cercly_ugc_privado.denuncias where denunciante_id=u and creada_en>now()-interval '1 hour')>=10
 or (select count(*) from cercly_ugc_privado.denuncias where denunciante_id=u and creada_en>now()-interval '1 day')>=20 then
 raise exception using errcode='P0001',message='Límite de denuncias alcanzado. Inténtalo más tarde.'; end if;
 insert into cercly_ugc_privado.denuncias(denunciante_id,tipo,objetivo_id,responsable_id,motivo,detalle) values(u,p_tipo,p_objetivo_id,responsable,p_motivo,trim(p_detalle)) returning id into r;
 return r;
end $$;
create function public.ugc_bloquear_responsable(p_tipo text,p_objetivo_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); v uuid; referencia text;
begin
 select propietario_id,left(nombre,120) into v,referencia from public.establecimientos where id=cercly_ugc_privado.negocio(p_tipo,p_objetivo_id) and estado='aprobado' and publicable;
 if v is null or v=u or not cercly_ugc_privado.visible_objetivo(p_tipo,p_objetivo_id) then raise exception using errcode='42501',message='No hay responsable disponible para bloquear'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,20261120));
 if (select count(*) from cercly_ugc_privado.bloqueos where usuario_id=u)>=500 then raise exception using errcode='P0001',message='Límite de bloqueos alcanzado'; end if;
 insert into cercly_ugc_privado.bloqueos(usuario_id,bloqueado_id,referencia) values(u,v,referencia) on conflict do nothing;
end $$;
create function public.ugc_mis_bloqueos() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); begin
 return coalesce((select jsonb_agg(jsonb_build_object('id',bloqueado_id,'fecha',creado_en,'referencia',referencia)) from cercly_ugc_privado.bloqueos where usuario_id=u),'[]');
end $$;
create function public.ugc_desbloquear(p_bloqueado_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); begin delete from cercly_ugc_privado.bloqueos where usuario_id=u and bloqueado_id=p_bloqueado_id; end $$;
create function public.ugc_mis_denuncias() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); begin
 return coalesce((select jsonb_agg(to_jsonb(d)-array['denunciante_id','responsable_id']) from (select * from cercly_ugc_privado.denuncias where denunciante_id=u order by creada_en desc limit 100)d),'[]'); end $$;
create function public.ugc_denuncias_admin(p_estado text default 'nueva') returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform cercly_ugc_privado.exigir_sesion();
 if not public.es_administrador() then raise exception using errcode='42501',message='Administrador requerido'; end if;
 return coalesce((select jsonb_agg(to_jsonb(d)) from (select * from cercly_ugc_privado.denuncias where estado=p_estado order by creada_en limit 100)d),'[]'); end $$;
create function public.ugc_revisar_denuncia(p_denuncia_id uuid,p_estado text,p_motivo text) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=cercly_ugc_privado.exigir_sesion(); d cercly_ugc_privado.denuncias;
begin
 if not public.es_administrador() or not cercly_account_private.sesion_reciente(u) then raise exception using errcode='42501',message='Administrador con sesión reciente requerido'; end if;
 select * into d from cercly_ugc_privado.denuncias where id=p_denuncia_id for update;
 if not found or d.responsable_id=u or d.denunciante_id=u then raise exception using errcode='42501',message='Revisión independiente requerida'; end if;
 if p_estado is null or p_estado not in ('en_revision','retirada','desestimada') or d.estado in ('retirada','desestimada')
 or (p_estado='en_revision' and d.estado<>'nueva') or p_motivo is null or char_length(trim(p_motivo)) not between 10 and 500 then raise exception using errcode='22023',message='Transición o motivo inválido'; end if;
 if p_estado='retirada' then insert into cercly_ugc_privado.retirados(tipo,objetivo_id,responsable_id) values(d.tipo,d.objetivo_id,d.responsable_id) on conflict do nothing; end if;
 update cercly_ugc_privado.denuncias set estado=p_estado,actualizada_en=now() where id=d.id;
 insert into cercly_ugc_privado.revisiones(denuncia_id,revisor_id,estado_anterior,estado_nuevo,motivo) values(d.id,u,d.estado,p_estado,trim(p_motivo));
end $$;

create function public.ugc_contexto_denuncia(p_denuncia_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d cercly_ugc_privado.denuncias; e public.establecimientos; contenido jsonb;
begin
 perform cercly_ugc_privado.exigir_sesion();
 if not public.es_administrador() then raise exception using errcode='42501',message='Administrador requerido'; end if;
 select * into d from cercly_ugc_privado.denuncias where id=p_denuncia_id;
 if not found then raise exception using errcode='22023',message='Denuncia inexistente'; end if;
 select * into e from public.establecimientos where id=cercly_ugc_privado.negocio(d.tipo,d.objetivo_id);
 contenido:=jsonb_build_object('establecimiento_id',e.id,'nombre',e.nombre,'descripcion',e.descripcion);
 if d.tipo='fotografia' then contenido:=contenido||coalesce((select jsonb_build_object('ruta',ruta_storage,'bucket','establecimientos-imagenes') from public.fotos_establecimiento where id=d.objetivo_id),'{}');
 elsif d.tipo='promocion' then contenido:=contenido||coalesce((select jsonb_build_object('titulo',titulo,'texto',descripcion,'ruta',imagen_ruta_storage,'bucket','promociones-imagenes') from public.promociones where id=d.objetivo_id),'{}'); end if;
 return contenido||jsonb_build_object('historial',coalesce((select jsonb_agg(jsonb_build_object('anterior',estado_anterior,'nuevo',estado_nuevo,'motivo',motivo,'fecha',creada_en) order by id) from cercly_ugc_privado.revisiones where denuncia_id=d.id),'[]'));
end $$;
-- Cierre explícito de todas las funciones: los helpers privados nunca son API.
do $$ declare f record; begin
 for f in select p.oid::regprocedure firma,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='cercly_ugc_privado' or (n.nspname='public' and p.proname like 'ugc_%') loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',f.firma);
 if f.nspname='public' then execute format('grant execute on function %s to authenticated',f.firma); end if;
 end loop;
end $$;
grant execute on function public.ugc_normas_publicacion() to anon;
grant execute on function cercly_ugc_privado.visible_fila(text,uuid,uuid,uuid) to anon,authenticated;
-- Continúa la definición exacta del detector de cascadas de identidad abajo.

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
    ('cercly_account_private','sujetos_qa_supresion','sujetos_qa_supresion_usuario_id_fkey','usuario_id','c'),
    ('cercly_rutas_privado','rutas_limites_usuarios','rutas_limites_usuarios_usuario_id_fkey','usuario_id','c'),
    ('cercly_ugc_privado','aceptaciones','aceptaciones_usuario_id_fkey','usuario_id','c'),
    ('cercly_ugc_privado','bloqueos','bloqueos_usuario_id_fkey','usuario_id','c'),
    ('cercly_ugc_privado','bloqueos','bloqueos_bloqueado_id_fkey','bloqueado_id','c'),
    ('cercly_ugc_privado','denuncias','denuncias_denunciante_id_fkey','denunciante_id','n'),
    ('cercly_ugc_privado','denuncias','denuncias_responsable_id_fkey','responsable_id','n'),
    ('cercly_ugc_privado','retirados','retirados_responsable_id_fkey','responsable_id','n'),
    ('cercly_ugc_privado','revisiones','revisiones_revisor_id_fkey','revisor_id','n')
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
   or (bucket_id in ('establecimientos-imagenes','promociones-imagenes') and name like p_id::text||'/%'))
 or exists(select 1 from cercly_ugc_privado.denuncias where denunciante_id=p_id or responsable_id=p_id)
 or exists(select 1 from cercly_ugc_privado.revisiones where revisor_id=p_id)
 or exists(select 1 from cercly_ugc_privado.retirados where responsable_id=p_id);
$$;
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
   and not ((c.conrelid = 'public.usuarios'::regclass and c.conname = 'usuarios_id_fkey' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.miembros_establecimiento'::regclass and c.conname = 'miembros_establecimiento_usuario_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='usuario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.establecimientos'::regclass and c.conname = 'establecimientos_propietario_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'r' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='propietario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.solicitudes_establecimientos'::regclass and c.conname = 'solicitudes_establecimientos_solicitante_id_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'r' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='solicitante_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.establecimientos'::regclass and c.conname = 'establecimientos_verificado_por_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'n' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='verificado_por' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.solicitudes_establecimientos'::regclass and c.conname = 'solicitudes_establecimientos_revisado_por_fkey' and c.confrelid = 'public.usuarios'::regclass and c.confdeltype = 'n' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='revisado_por' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]) or (c.conrelid = 'public.preferencias_usuario'::regclass and c.conname = 'preferencias_usuario_usuario_id_fkey' and c.confrelid = 'auth.users'::regclass and c.confdeltype = 'c' and c.convalidated and c.conkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.conrelid and a.attname='usuario_id' and not a.attisdropped)] and c.confkey = array[(select a.attnum::smallint from pg_catalog.pg_attribute a where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)])))
 or exists(select 1 from cercly_ugc_privado.denuncias where denunciante_id=p_id or responsable_id=p_id)
 or exists(select 1 from cercly_ugc_privado.revisiones where revisor_id=p_id)
 or exists(select 1 from cercly_ugc_privado.retirados where responsable_id=p_id);
$$;
commit;
