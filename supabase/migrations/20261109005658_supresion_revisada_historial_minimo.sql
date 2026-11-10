-- PROPUESTA LOCAL UNIFICADA. No desplegar sin autorización independiente.
-- Archivo generado por Supabase CLI. Integra la propuesta local previa, todavía
-- no desplegada. Requiere las 27 migraciones y autorización nueva de despliegue.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Conservar el detector de las 27 migraciones y añadir el historial privado
-- de eliminación, cuyos UUID no tienen FK y también son datos personales.
create or replace function cercly_account_private.tiene_dependencias(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.establecimientos where propietario_id=p_id or verificado_por=p_id)
 or exists(select 1 from public.solicitudes_establecimientos where solicitante_id=p_id or revisado_por=p_id)
 or exists(select 1 from public.correcciones_aplicadas where solicitante_id=p_id or revisado_por=p_id)
 or exists(select 1 from public.auditoria_moderacion_establecimientos where actor_id=p_id)
 or exists(select 1 from cercly_account_private.auditoria_eliminacion a
   where (a.sujeto_id=p_id or a.actor_id=p_id or a.destino_id=p_id)
   -- Solo la aprobación mínima del CASO ACTUAL puede cerrarse junto con él.
   -- Otras acciones, actores, negocios y casos históricos siguen en revisión.
   and not (a.sujeto_id=p_id and a.actor_id is not null and a.actor_id<>p_id
    and a.accion='aprobar' and a.establecimiento_id is null and a.destino_id is null
    and a.solicitud_id is not distinct from (select solicitud_id from cercly_account_private.solicitudes_eliminacion where usuario_id=p_id)))
 or exists(select 1 from pg_catalog.pg_constraint c
   join pg_catalog.pg_class t on t.oid=c.conrelid
   join pg_catalog.pg_namespace n on n.oid=t.relnamespace
   where n.nspname='public' and c.contype='f' and c.confrelid in
     ('public.usuarios'::regclass,'auth.users'::regclass)
   and c.conname not in ('usuarios_id_fkey','miembros_establecimiento_usuario_id_fkey',
    'establecimientos_propietario_id_fkey','solicitudes_establecimientos_solicitante_id_fkey',
    'establecimientos_verificado_por_fkey','solicitudes_establecimientos_revisado_por_fkey',
    'preferencias_usuario_usuario_id_fkey'))
 or exists(select 1 from storage.objects where owner_id=p_id::text
   or (bucket_id in ('establecimientos-imagenes','promociones-imagenes') and name like p_id::text||'/%'));
$$;

-- NOT IN sobre NULL no entra en IF. Una solicitud ausente debe denegarse.
-- CREATE OR REPLACE conserva propietario y ACL ya restringidas a service_role.
create or replace function public.validar_eliminacion_cuenta(p_usuario_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare estado_actual text; rol_actual public.rol_usuario;
begin
 select estado into estado_actual from cercly_account_private.solicitudes_eliminacion
   where usuario_id=p_usuario_id for update;
 if estado_actual is null or estado_actual not in ('pendiente','aprobada') then return false; end if;
 select rol into rol_actual from public.usuarios where id=p_usuario_id for update;
 if rol_actual is null or cercly_account_private.tiene_dependencias(p_usuario_id) then return false; end if;
 if rol_actual='administrador' and (estado_actual<>'aprobada' or
   (select count(*) from public.usuarios where rol='administrador')<=1) then return false; end if;
 return true;
end;
$$;

create or replace function public.finalizar_eliminacion_cuenta(p_usuario_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from auth.users where id=p_usuario_id) then
  raise exception using errcode='42501',message='Identidad Auth todavia existente';
 end if;
 delete from cercly_account_private.solicitudes_eliminacion where usuario_id=p_usuario_id;
end;
$$;

-- Informe acotado a un caso existente. No devuelve contenidos, correos,
-- identidades Auth ni valores anteriores/propuestos del negocio.
create function public.preparar_revision_privacidad(p_usuario_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or auth.uid()=p_usuario_id
   or not public.es_administrador()
   or not exists(select 1 from auth.users where id=auth.uid())
   or not cercly_account_private.sesion_reciente(auth.uid()) then
  raise exception using errcode='42501',message='Revisor autorizado con sesion reciente requerido';
 end if;
 if cercly_account_private.es_identidad_qa(auth.uid()) or cercly_account_private.es_identidad_qa(p_usuario_id) then
  if not cercly_account_private.sujeto_qa_autorizado(p_usuario_id)
   or not cercly_account_private.sujeto_qa_autorizado(auth.uid(),
    (select ensayo_id from cercly_account_private.sujetos_qa_supresion where usuario_id=p_usuario_id)) then
   raise exception using errcode='42501',message='Identidad fuera del ensayo QA autorizado';
  end if;
 end if;
 if not exists(select 1 from cercly_account_private.solicitudes_eliminacion
   where usuario_id=p_usuario_id) then
  raise exception using errcode='22023',message='Caso de privacidad inexistente';
 end if;
 return jsonb_build_object(
  'propiedades',(select count(*) from public.establecimientos where propietario_id=p_usuario_id),
  'membresias_activas',(select count(*) from public.miembros_establecimiento where usuario_id=p_usuario_id and activo),
  'solicitudes_pendientes',(select count(*) from public.solicitudes_establecimientos
    where (solicitante_id=p_usuario_id or revisado_por=p_usuario_id) and estado='pendiente'),
  'solicitudes_cerradas',(select count(*) from public.solicitudes_establecimientos
    where (solicitante_id=p_usuario_id or revisado_por=p_usuario_id) and estado<>'pendiente'),
  'correcciones',(select count(*) from public.correcciones_aplicadas
    where solicitante_id=p_usuario_id or revisado_por=p_usuario_id),
  'moderaciones',(select count(*) from public.auditoria_moderacion_establecimientos where actor_id=p_usuario_id),
  'auditorias_privacidad',(select count(*) from cercly_account_private.auditoria_eliminacion
    where sujeto_id=p_usuario_id or actor_id=p_usuario_id or destino_id=p_usuario_id),
  'objetos_storage',(select count(*) from storage.objects where owner_id=p_usuario_id::text
    or (bucket_id in ('establecimientos-imagenes','promociones-imagenes') and name like p_usuario_id::text||'/%')),
  'dependencias_sin_resolver',cercly_account_private.tiene_dependencias(p_usuario_id),
  'decision_de_privacidad_pendiente',not exists(select 1 from cercly_account_private.planes_supresion where sujeto_id=p_usuario_id),
  'supresion_de_historial_habilitada',exists(select 1 from cercly_account_private.politicas_supresion where habilitada
   and cercly_account_private.sujeto_qa_autorizado(p_usuario_id,ensayo_qa)));
end;
$$;
alter function public.preparar_revision_privacidad(uuid) owner to postgres;
revoke all on function public.preparar_revision_privacidad(uuid) from public,anon,authenticated,service_role;
grant execute on function public.preparar_revision_privacidad(uuid) to authenticated;

-- La revisión RPC y Auth.deleteUser son transacciones distintas. Esta barrera
-- comprueba de nuevo el caso y las dependencias dentro del DELETE de Auth.
create function cercly_account_private.proteger_supresion_auth()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if public.validar_eliminacion_cuenta(old.id) is distinct from true then
  raise exception using errcode='42501',message='Supresion requiere caso autorizado sin dependencias';
 end if;
 return old;
end;
$$;
alter function cercly_account_private.proteger_supresion_auth() owner to postgres;
revoke all on function cercly_account_private.proteger_supresion_auth() from public,anon,authenticated,service_role;
create trigger proteger_supresion_auth before delete on auth.users
 for each row execute function cercly_account_private.proteger_supresion_auth();

-- Una nueva referencia sin FK no debe aparecer mientras se elimina al actor.
-- FOR KEY SHARE serializa INSERT del historial con DELETE de auth.users.
-- No se añaden ni alteran referencias históricas que ya pudieran ser huérfanas.
create function cercly_account_private.proteger_identidades_historial()
returns trigger language plpgsql security definer set search_path='' as $$
declare sujeto uuid; sujetos uuid[];
begin
 if tg_table_schema='public' and tg_table_name='correcciones_aplicadas' then
  sujetos:=array[new.solicitante_id,new.revisado_por];
 elsif tg_table_schema='public' and tg_table_name='auditoria_moderacion_establecimientos' then
  sujetos:=array[new.actor_id];
 elsif tg_table_schema='cercly_account_private' and tg_table_name='auditoria_eliminacion' then
  sujetos:=array[new.sujeto_id,new.actor_id,new.destino_id];
 else
  raise exception using errcode='42501',message='Destino de auditoria no autorizado';
 end if;
 for sujeto in select distinct x from unnest(sujetos) x where x is not null order by x loop
  perform 1 from auth.users where id=sujeto for key share;
  if not found then
   raise exception using errcode='23503',message='Identidad de auditoria inexistente';
  end if;
 end loop;
 return new;
end;
$$;
alter function cercly_account_private.proteger_identidades_historial() owner to postgres;
revoke all on function cercly_account_private.proteger_identidades_historial() from public,anon,authenticated,service_role;
create trigger proteger_identidades_historial before insert on public.correcciones_aplicadas
 for each row execute function cercly_account_private.proteger_identidades_historial();
create trigger proteger_identidades_historial before insert on public.auditoria_moderacion_establecimientos
 for each row execute function cercly_account_private.proteger_identidades_historial();
create trigger proteger_identidades_historial before insert on cercly_account_private.auditoria_eliminacion
 for each row execute function cercly_account_private.proteger_identidades_historial();

-- Las salvaguardas anteriores no autorizan por sí solas la redacción. El bloque
-- siguiente añade la operación revisada; no aprueba una base o plazo legal.


-- Un caso revisado puede suprimir contenidos sin destruir el hecho histórico.
-- No se activa ninguna política jurídica desde esta migración.
-- Guarda experimental cerrada: registro explícito por UUID, no por correo/prefijo.
-- Vacío al instalar; sin RPC de autoinscripción ni permiso para service_role.
create table cercly_account_private.sujetos_qa_supresion (
 usuario_id uuid primary key references auth.users(id) on delete cascade,
 ensayo_id uuid not null,
 auth_creado_en timestamptz not null,
 vence_en timestamptz not null,
 habilitado boolean not null default false
);
alter table cercly_account_private.sujetos_qa_supresion enable row level security;
revoke all on cercly_account_private.sujetos_qa_supresion from public,anon,authenticated,service_role;

create function cercly_account_private.sujeto_qa_autorizado(p_id uuid,p_ensayo uuid default null)
returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from cercly_account_private.sujetos_qa_supresion q
 join auth.users a on a.id=q.usuario_id
 where q.usuario_id=p_id and q.habilitado and q.vence_en>clock_timestamp()
 and a.created_at=q.auth_creado_en
 and (p_ensayo is null or q.ensayo_id=p_ensayo)
 and a.raw_app_meta_data->'cercly_qa_privacidad'->'autorizada'='true'::jsonb
 and a.raw_app_meta_data->'cercly_qa_privacidad'->>'ensayo_id'=q.ensayo_id::text);
$$;
alter function cercly_account_private.sujeto_qa_autorizado(uuid,uuid) owner to postgres;
revoke all on function cercly_account_private.sujeto_qa_autorizado(uuid,uuid) from public,anon,authenticated,service_role;

create table cercly_account_private.politicas_supresion (
 codigo text primary key check(codigo ~ '^[A-Z0-9_-]{6,80}$'),
 referencia_decision text not null check(referencia_decision ~ '^[A-Z0-9_-]{6,100}$'),
 habilitada boolean not null default false,
 ensayo_qa uuid not null
);
create table cercly_account_private.planes_supresion (
 sujeto_id uuid primary key references auth.users(id) on delete cascade,
 politica text not null references cercly_account_private.politicas_supresion(codigo),
 huella text not null check(huella ~ '^[0-9a-f]{64}$'),
 revisor_id uuid not null references auth.users(id) on delete cascade,
 aprobado_en timestamptz not null default now(),
 check(sujeto_id<>revisor_id)
);
-- Capacidades solo dentro de la transacción Auth DELETE, nunca GUC del cliente.
create table cercly_account_private.ejecuciones_supresion (
 xid bigint primary key, sujeto_id uuid not null
);
create table cercly_account_private.resultados_supresion (
 recibo uuid primary key default gen_random_uuid(),
 fecha date not null default current_date,
 resultado text not null check(resultado='auth_y_datos_desvinculados')
);
-- Recibo sin ID de usuario, hash del usuario, correo, expediente ni vínculo al plan.
do $ddl$ declare t text; begin
 foreach t in array array['politicas_supresion','planes_supresion','ejecuciones_supresion','resultados_supresion'] loop
 execute format('alter table cercly_account_private.%I enable row level security',t);
 execute format('revoke all on cercly_account_private.%I from public,anon,authenticated,service_role',t);
 end loop;
end $ddl$;

alter table public.solicitudes_establecimientos alter column solicitante_id drop not null;
alter table public.solicitudes_establecimientos add column datos_suprimidos boolean not null default false;
alter table public.solicitudes_establecimientos add constraint solicitud_identidad_o_supresion
 check(solicitante_id is not null or datos_suprimidos);
alter table public.correcciones_aplicadas alter column solicitante_id drop not null,
 alter column revisado_por drop not null;
alter table public.correcciones_aplicadas add column datos_suprimidos boolean not null default false;
alter table public.auditoria_moderacion_establecimientos add column datos_suprimidos boolean not null default false;
alter table cercly_account_private.auditoria_eliminacion alter column sujeto_id drop not null,
 alter column actor_id drop not null;

-- Inventario en el servidor: no devuelve contactos, textos ni snapshots a la API.
create function cercly_account_private.inventario_supresion(p_id uuid)
returns jsonb language sql volatile security definer set search_path='' as $$
 select jsonb_build_object(
 'perfil',(select to_jsonb(u) from public.usuarios u where id=p_id),
 'solicitudes',coalesce((select jsonb_agg(to_jsonb(s) order by s.id) from public.solicitudes_establecimientos s where solicitante_id=p_id or revisado_por=p_id),'[]'),
 'correcciones',coalesce((select jsonb_agg(to_jsonb(a) order by solicitud_id) from public.correcciones_aplicadas a where solicitante_id=p_id or revisado_por=p_id or solicitud_id in
   (select id from public.solicitudes_establecimientos where solicitante_id=p_id or revisado_por=p_id)),'[]'),
 'moderacion',coalesce((select jsonb_agg(to_jsonb(a) order by id) from public.auditoria_moderacion_establecimientos a where actor_id=p_id),'[]'),
 'privacidad',coalesce((select jsonb_agg(to_jsonb(a) order by id) from cercly_account_private.auditoria_eliminacion a where sujeto_id=p_id or actor_id=p_id or destino_id=p_id),'[]'));
$$;
create function cercly_account_private.huella_supresion(p_id uuid)
returns text language sql volatile security definer set search_path='' as $$
 select encode(extensions.digest(convert_to(cercly_account_private.inventario_supresion(p_id)::text,'UTF8'),'sha256'),'hex');
$$;

-- Bloqueos que esta operación NO resuelve: transferencias, documentos/binarios,
-- contenido en fichas compartidas, gobernanza superadmin o referencias desconocidas.
create function cercly_account_private.bloqueo_externo_supresion(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.establecimientos where propietario_id=p_id)
 or exists(select 1 from storage.objects where owner_id=p_id::text or name like p_id::text||'/%')
 or exists(select 1 from public.evidencias_solicitud where solicitud_id in
   (select id from public.solicitudes_establecimientos where solicitante_id=p_id or revisado_por=p_id))
 or exists(select 1 from cercly_auth_private.superadministradores where usuario_id=p_id or otorgado_por=p_id or revocado_por=p_id)
 or exists(select 1 from cercly_auth_private.auditoria_superadministradores where usuario_id=p_id or actor_id=p_id)
 or exists(select 1 from public.usuarios where id=p_id and rol='administrador')
 or exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_class t on t.oid=c.conrelid
   join pg_catalog.pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and c.contype='f'
   and c.confrelid in ('public.usuarios'::regclass,'auth.users'::regclass)
   and c.conname not in ('usuarios_id_fkey','miembros_establecimiento_usuario_id_fkey',
    'establecimientos_propietario_id_fkey','solicitudes_establecimientos_solicitante_id_fkey',
    'establecimientos_verificado_por_fkey','solicitudes_establecimientos_revisado_por_fkey','preferencias_usuario_usuario_id_fkey'));
$$;

create function public.obtener_huella_revision_privacidad_qa(p_usuario_id uuid)
returns text language plpgsql security definer set search_path='' as $$
begin
 perform public.preparar_revision_privacidad(p_usuario_id);
 if not cercly_account_private.sujeto_qa_autorizado(p_usuario_id)
 or not cercly_account_private.sujeto_qa_autorizado(auth.uid(),
  (select ensayo_id from cercly_account_private.sujetos_qa_supresion where usuario_id=p_usuario_id)) then
  raise exception using errcode='42501',message='Identidad fuera del ensayo QA autorizado';
 end if;
 return cercly_account_private.huella_supresion(p_usuario_id);
end;
$$;
create function public.autorizar_supresion_revisada_qa(p_usuario_id uuid,p_huella text,p_politica text,p_revision_externa_confirmada boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 -- Revisión de identidad/rol/sesión, sin autoaprobación ni secreto de servidor.
 perform public.preparar_revision_privacidad(p_usuario_id);
 perform 1 from auth.users where id=p_usuario_id for update;
 perform 1 from public.usuarios where id=p_usuario_id for update;
 perform 1 from cercly_account_private.sujetos_qa_supresion where usuario_id=p_usuario_id for share;
 if not cercly_account_private.sujeto_qa_autorizado(p_usuario_id)
 or not cercly_account_private.sujeto_qa_autorizado(auth.uid(),
  (select ensayo_id from cercly_account_private.sujetos_qa_supresion where usuario_id=p_usuario_id)) then
  raise exception using errcode='42501',message='Identidad fuera del ensayo QA autorizado';
 end if;
 if p_revision_externa_confirmada is distinct from true
 or cercly_account_private.bloqueo_externo_supresion(p_usuario_id)
 or not exists(select 1 from cercly_account_private.politicas_supresion where codigo=p_politica and habilitada
  and cercly_account_private.sujeto_qa_autorizado(p_usuario_id,ensayo_qa)) then
 raise exception using errcode='42501',message='Revision externa y politica aprobada sin bloqueos requeridas';
 end if;
 if p_huella is distinct from cercly_account_private.huella_supresion(p_usuario_id) then
 raise exception using errcode='40001',message='Inventario de privacidad obsoleto';
 end if;
 insert into cercly_account_private.planes_supresion(sujeto_id,politica,huella,revisor_id)
 values(p_usuario_id,p_politica,p_huella,auth.uid());
 update cercly_account_private.solicitudes_eliminacion set estado='aprobada',actualizada_en=now() where usuario_id=p_usuario_id;
end;
$$;

-- Transformación cerrada; el revisor nunca envía nuevos valores ni elige tablas.
create function cercly_account_private.fila_suprimida(t text,f jsonb,p_id uuid)
returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;
begin
 if t='solicitudes_establecimientos' then
  foreach k in array array['solicitante_id','revisado_por'] loop
   if f->>k=p_id::text then f:=jsonb_set(f,array[k],'null'); end if;
  end loop;
  return f||jsonb_build_object('datos_suprimidos',true,'mensaje','','motivo_respuesta','','nombre_propuesto',null,
   'datos_propuestos','{}'::jsonb,'estado',case when f->>'estado'='pendiente' then 'rechazada' else f->>'estado' end);
 elsif t='correcciones_aplicadas' then
  foreach k in array array['solicitante_id','revisado_por'] loop
   if f->>k=p_id::text then f:=jsonb_set(f,array[k],'null'); end if;
  end loop;
  return f||jsonb_build_object('datos_suprimidos',true,'motivo','','antes','{}'::jsonb,'despues','{}'::jsonb);
 elsif t='auditoria_moderacion_establecimientos' then
  return f||jsonb_build_object('actor_id',null,'datos_suprimidos',true);
 elsif t='auditoria_eliminacion' then
  foreach k in array array['sujeto_id','actor_id','destino_id'] loop
   if f->>k=p_id::text then f:=jsonb_set(f,array[k],'null'); end if;
  end loop;
  return f;
 end if;
 raise exception using errcode='42501',message='Tabla de privacidad no autorizada';
end;
$$;
create function cercly_account_private.redaccion_autorizada(t text,anterior jsonb,nuevo jsonb)
returns boolean language plpgsql security definer set search_path='' as $$
declare sujeto uuid;
begin
 select sujeto_id into sujeto from cercly_account_private.ejecuciones_supresion where xid=txid_current();
 if sujeto is null then return false; end if;
 return (nuevo-'actualizado_en')=(cercly_account_private.fila_suprimida(t,anterior,sujeto)-'actualizado_en');
end;
$$;

create or replace function public.validar_correccion_estructurada()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  e public.establecimientos%rowtype;
  cambios jsonb;
  campo text;
  item jsonb;
  nuevo text;
  categoria uuid;
  permitidos text[] := array['nombre','direccion','categoria_id','descripcion','telefono_publico','latitud','longitud'];
begin
  if current_user='postgres' and tg_op='UPDATE' then
   if cercly_account_private.redaccion_autorizada('solicitudes_establecimientos',to_jsonb(old),to_jsonb(new)) then return new; end if;
  end if;
  if tg_op='UPDATE' and old.tipo='correccion' and old.estado <> 'pendiente'
     and (to_jsonb(new)-'actualizado_en') is distinct from (to_jsonb(old)-'actualizado_en') then
    raise exception using errcode='42501', message='Una corrección cerrada no puede modificarse.';
  end if;
  if new.tipo <> 'correccion' then return new; end if;
  if tg_op = 'UPDATE' and
     (new.establecimiento_id,new.tipo,new.datos_propuestos) is not distinct from
     (old.establecimiento_id,old.tipo,old.datos_propuestos) then return new; end if;
  -- Compatibilidad con solicitudes de texto y clientes manuales existentes.
  -- Nunca interpretar texto libre ni tratarlo como una propuesta aplicable.
  if not (coalesce(new.datos_propuestos,'{}'::jsonb) ? 'cambios') then return new; end if;
  if auth.uid() is null or not public.puede_gestionar_como_propietario(new.establecimiento_id) then
    raise exception 'Solo el propietario o un colaborador activo puede solicitar una corrección.';
  end if;
  select * into e from public.establecimientos where id = new.establecimiento_id;
  if not found or e.estado is distinct from 'aprobado' or e.publicable is not true then
    raise exception 'El establecimiento no está disponible.';
  end if;
  if jsonb_typeof(new.datos_propuestos) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(new.datos_propuestos)) <> 1
     or not (new.datos_propuestos ? 'cambios') then
    raise exception 'La propuesta debe contener únicamente cambios estructurados.';
  end if;
  cambios := new.datos_propuestos->'cambios';
  if jsonb_typeof(cambios) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(cambios)) not between 1 and 7 then
    raise exception 'Propón al menos un campo válido.';
  end if;
  for campo in select jsonb_object_keys(cambios) loop
    if not (campo = any(permitidos)) then raise exception 'Campo no permitido: %', campo; end if;
    item := cambios->campo;
    if jsonb_typeof(item) is distinct from 'object'
       or (select count(*) from jsonb_object_keys(item)) <> 2
       or not (item ?& array['anterior','nuevo']) then
      raise exception 'Cada cambio requiere valor anterior y nuevo.';
    end if;
    if item->'anterior' is distinct from to_jsonb(e)->campo then
      raise exception 'La ficha cambió. Actualiza la propuesta antes de enviarla.';
    end if;
    if item->'nuevo' = item->'anterior' then raise exception 'No hay cambio en %.', campo; end if;
    if campo in ('latitud','longitud') then
      if jsonb_typeof(item->'nuevo') is distinct from 'number'
         or (campo='latitud' and (item->>'nuevo')::double precision not between -90 and 90)
         or (campo='longitud' and (item->>'nuevo')::double precision not between -180 and 180) then
        raise exception 'Coordenada inválida.';
      end if;
    else
      if jsonb_typeof(item->'nuevo') is distinct from 'string' then
        raise exception 'Valor de texto inválido.';
      end if;
      nuevo := item->>'nuevo';
      if nuevo is distinct from trim(nuevo) then raise exception 'Elimina espacios sobrantes.'; end if;
      if (campo='nombre' and char_length(nuevo) not between 2 and 120)
         or (campo='direccion' and char_length(nuevo) not between 1 and 250)
         or (campo='descripcion' and char_length(nuevo)>1000)
         or (campo='telefono_publico' and char_length(nuevo)>20) then
        raise exception 'Longitud de texto inválida.';
      end if;
      if campo='categoria_id' then
        categoria := nuevo::uuid;
        if not exists(select 1 from public.categorias c where c.id=categoria and c.activa) then
          raise exception 'Categoría no disponible.';
        end if;
      end if;
    end if;
  end loop;
  return new;
end;
$$;

create or replace function public.validar_solicitud_establecimiento()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  establecimiento public.establecimientos%rowtype;
  propuesta jsonb := new.datos_propuestos;
  lat double precision;
  lon double precision;
  categoria uuid;
begin
  if current_user='postgres' and tg_op='UPDATE' then
   if cercly_account_private.redaccion_autorizada('solicitudes_establecimientos',to_jsonb(old),to_jsonb(new)) then return new; end if;
  end if;
  if tg_op = 'UPDATE'
     and (new.establecimiento_id, new.tipo, new.datos_propuestos)
       is not distinct from
         (old.establecimiento_id, old.tipo, old.datos_propuestos) then
    return new;
  end if;

  if new.tipo = 'registro' then
    if propuesta is null or jsonb_typeof(propuesta) <> 'object' then
      raise exception 'Los datos del nuevo establecimiento son obligatorios.';
    end if;
    if new.estado = 'pendiente' and new.establecimiento_id is not null then
      raise exception 'Una solicitud pendiente no puede tener ficha pública.';
    end if;
    if nullif(trim(propuesta->>'nombre'), '') is null
       or char_length(trim(propuesta->>'nombre')) not between 2 and 120 then
      raise exception 'El nombre debe tener entre 2 y 120 caracteres.';
    end if;
    if nullif(propuesta->>'categoria_id', '') is null then
      raise exception 'La categoría es obligatoria.';
    end if;
    categoria := (propuesta->>'categoria_id')::uuid;
    if not exists (select 1 from public.categorias c where c.id = categoria and c.activa) then
      raise exception 'La categoría seleccionada no está disponible.';
    end if;
    if nullif(trim(propuesta->>'direccion'), '') is null
       or char_length(trim(propuesta->>'direccion')) > 250 then
      raise exception 'La dirección debe tener entre 1 y 250 caracteres.';
    end if;
    if char_length(coalesce(propuesta->>'descripcion', '')) > 1000
       or char_length(coalesce(propuesta->>'telefono_publico', '')) > 20 then
      raise exception 'La descripción o el contacto supera el límite permitido.';
    end if;
    if jsonb_typeof(propuesta->'latitud') <> 'number'
       or jsonb_typeof(propuesta->'longitud') <> 'number' then
      raise exception 'La ubicación debe incluir latitud y longitud numéricas.';
    end if;
    lat := (propuesta->>'latitud')::double precision;
    lon := (propuesta->>'longitud')::double precision;
    if lat not between -90 and 90 or lon not between -180 and 180 then
      raise exception 'Las coordenadas están fuera de los límites válidos.';
    end if;
    if jsonb_typeof(coalesce(propuesta->'horarios', '[]'::jsonb)) <> 'array' then
      raise exception 'El horario debe ser una lista válida.';
    end if;
    return new;
  end if;

  if new.establecimiento_id is null then
    raise exception 'El establecimiento es obligatorio.';
  end if;

  select * into establecimiento
  from public.establecimientos
  where id = new.establecimiento_id;
  if not found then
    raise exception 'El establecimiento no existe.';
  end if;

  if new.tipo = 'reclamar' then
    if establecimiento.fuente <> 'osm'
       or establecimiento.estado_reclamo <> 'no_reclamado'
       or establecimiento.propietario_id is not null then
      raise exception 'El establecimiento no está disponible para reclamo';
    end if;
  elsif new.tipo = 'acceso' then
    if establecimiento.propietario_id is null then
      raise exception 'El establecimiento todavía no tiene administrador.';
    end if;
  elsif new.tipo = 'correccion' then
    if propuesta is null or jsonb_typeof(propuesta) <> 'object' or propuesta = '{}'::jsonb then
      raise exception 'Debes indicar los datos que deseas corregir.';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.conservar_auditoria_moderacion()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='UPDATE' and current_user='postgres' then
  if cercly_account_private.redaccion_autorizada(tg_table_name,to_jsonb(old),to_jsonb(new)) then return new; end if;
 end if;
 raise exception using errcode='42501',message='Auditoria inmutable: requiere procedimiento de privacidad revisado';
end;
$$;
create function cercly_account_private.proteger_datos_suprimidos()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and cercly_account_private.redaccion_autorizada(tg_table_name,to_jsonb(old),to_jsonb(new)) then return new; end if;
 if tg_op='UPDATE' and (old.datos_suprimidos or new.datos_suprimidos)
 or tg_op='INSERT' and new.datos_suprimidos then
 raise exception using errcode='42501',message='Marcador de supresion reservado al procedimiento de privacidad';
 end if;
 return new;
end;
$$;
create trigger proteger_datos_suprimidos before insert or update on public.solicitudes_establecimientos
 for each row execute function cercly_account_private.proteger_datos_suprimidos();
create trigger proteger_datos_suprimidos before insert or update on public.correcciones_aplicadas
 for each row execute function cercly_account_private.proteger_datos_suprimidos();

create function cercly_account_private.plan_supresion_valido(p_id uuid)
returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from cercly_account_private.planes_supresion p
 join cercly_account_private.politicas_supresion l on l.codigo=p.politica and l.habilitada
 join public.usuarios r on r.id=p.revisor_id and r.rol='administrador'
 where p.sujeto_id=p_id and p.aprobado_en>now()-interval '1 day'
 and cercly_account_private.sujeto_qa_autorizado(p_id,l.ensayo_qa)
 and cercly_account_private.sujeto_qa_autorizado(p.revisor_id,l.ensayo_qa)
 and p.huella=cercly_account_private.huella_supresion(p_id))
 and not cercly_account_private.bloqueo_externo_supresion(p_id);
$$;

create function public.revocar_plan_supresion_qa(p_usuario_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform public.preparar_revision_privacidad(p_usuario_id);
 perform 1 from auth.users where id=p_usuario_id for update;
 if not cercly_account_private.sujeto_qa_autorizado(p_usuario_id)
 or not cercly_account_private.sujeto_qa_autorizado(auth.uid(),
  (select ensayo_id from cercly_account_private.sujetos_qa_supresion where usuario_id=p_usuario_id)) then
  raise exception using errcode='42501',message='Identidad fuera del ensayo QA autorizado';
 end if;
 delete from cercly_account_private.planes_supresion where sujeto_id=p_usuario_id;
 update cercly_account_private.solicitudes_eliminacion set estado='revision',actualizada_en=now() where usuario_id=p_usuario_id;
end;
$$;
revoke all on function public.revocar_plan_supresion_qa(uuid) from public,anon,authenticated,service_role;
grant execute on function public.revocar_plan_supresion_qa(uuid) to authenticated;

-- Revalidar en cada intento y dentro de Auth DELETE. Un plan no es una
-- autorización permanente ni sobrevive a cambios de contenido/rol/política.
create function cercly_account_private.validar_eliminacion_base(p_usuario_id uuid,p_ruta_qa boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare estado_actual text; rol_actual public.rol_usuario;
begin
 select estado into estado_actual from cercly_account_private.solicitudes_eliminacion
 where usuario_id=p_usuario_id for update;
 if estado_actual is null or estado_actual not in ('pendiente','aprobada') then return false; end if;
 select rol into rol_actual from public.usuarios where id=p_usuario_id for update;
 if rol_actual is null then return false; end if;
 if p_ruta_qa and exists(select 1 from cercly_account_private.planes_supresion where sujeto_id=p_usuario_id) then
  return estado_actual='aprobada' and cercly_account_private.plan_supresion_valido(p_usuario_id);
 end if;
 if cercly_account_private.tiene_dependencias(p_usuario_id) then return false; end if;
 if rol_actual='administrador' and (estado_actual<>'aprobada' or
 (select count(*) from public.usuarios where rol='administrador')<=1) then return false; end if;
 return true;
end;
$$;

-- Clasificación del servidor, conservada aunque caduque/revoque la inscripción.
-- Nunca caer a la ruta normal después de fallar una autorización QA.
create function cercly_account_private.es_identidad_qa(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from cercly_account_private.sujetos_qa_supresion where usuario_id=p_id)
 or exists(select 1 from cercly_account_private.planes_supresion where sujeto_id=p_id)
 or exists(select 1 from auth.users where id=p_id and raw_app_meta_data ? 'cercly_qa_privacidad');
$$;

create or replace function public.validar_eliminacion_cuenta(p_usuario_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if cercly_account_private.es_identidad_qa(p_usuario_id) then return false; end if;
 return cercly_account_private.validar_eliminacion_base(p_usuario_id,false);
end;
$$;
create function public.validar_eliminacion_cuenta_qa(p_usuario_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not cercly_account_private.sujeto_qa_autorizado(p_usuario_id) then return false; end if;
 return cercly_account_private.validar_eliminacion_base(p_usuario_id,true);
end;
$$;
revoke all on function public.validar_eliminacion_cuenta_qa(uuid) from public,anon,authenticated,service_role;
grant execute on function public.validar_eliminacion_cuenta_qa(uuid) to service_role;


create or replace function cercly_account_private.proteger_supresion_auth()
returns trigger language plpgsql security definer set search_path='' as $$
declare s public.solicitudes_establecimientos%rowtype; a public.correcciones_aplicadas%rowtype;
 m public.auditoria_moderacion_establecimientos%rowtype; h cercly_account_private.auditoria_eliminacion%rowtype;
 j jsonb; r uuid; ruta_qa boolean;
begin
 ruta_qa:=cercly_account_private.es_identidad_qa(old.id);
 -- Auth conserva la vía normal y exige guarda al clasificar un sujeto QA.
 perform 1 from cercly_account_private.sujetos_qa_supresion where usuario_id=old.id or usuario_id in
  (select revisor_id from cercly_account_private.planes_supresion where sujeto_id=old.id) order by usuario_id for share;
 perform 1 from auth.users where id in
  (select revisor_id from cercly_account_private.planes_supresion where sujeto_id=old.id) order by id for share;
 if ruta_qa and not cercly_account_private.sujeto_qa_autorizado(old.id) then
  raise exception using errcode='42501',message='Identidad fuera del ensayo QA autorizado';
 end if;
 -- Mismo orden de bloqueo que la revisión; nuevas referencias esperan al Auth DELETE.
 perform 1 from public.usuarios where id=old.id for update;
 perform 1 from public.usuarios where id in
  (select revisor_id from cercly_account_private.planes_supresion where sujeto_id=old.id) for share;
 perform 1 from cercly_account_private.politicas_supresion where codigo in
  (select politica from cercly_account_private.planes_supresion where sujeto_id=old.id) for share;
 perform 1 from public.solicitudes_establecimientos where solicitante_id=old.id or revisado_por=old.id order by id for update;
 perform 1 from public.correcciones_aplicadas where solicitante_id=old.id or revisado_por=old.id
  or solicitud_id in(select id from public.solicitudes_establecimientos where solicitante_id=old.id or revisado_por=old.id)
  order by solicitud_id for update;
 perform 1 from public.auditoria_moderacion_establecimientos where actor_id=old.id order by id for update;
 perform 1 from cercly_account_private.auditoria_eliminacion where sujeto_id=old.id or actor_id=old.id or destino_id=old.id order by id for update;
 if (case when ruta_qa then public.validar_eliminacion_cuenta_qa(old.id)
  else public.validar_eliminacion_cuenta(old.id) end) is distinct from true then
 raise exception using errcode='42501',message='Supresion requiere caso autorizado sin dependencias';
 end if;
 if ruta_qa and exists(select 1 from cercly_account_private.planes_supresion where sujeto_id=old.id) then
  insert into cercly_account_private.ejecuciones_supresion values(txid_current(),old.id);
  -- Primero auditar/redactar los snapshots, antes de quitar el vínculo de la solicitud.
  for a in select * from public.correcciones_aplicadas where solicitante_id=old.id or revisado_por=old.id
    or solicitud_id in(select id from public.solicitudes_establecimientos where solicitante_id=old.id or revisado_por=old.id) loop
   j:=cercly_account_private.fila_suprimida('correcciones_aplicadas',to_jsonb(a),old.id);
   update public.correcciones_aplicadas set solicitante_id=(j->>'solicitante_id')::uuid,revisado_por=(j->>'revisado_por')::uuid,
    antes='{}',despues='{}',motivo='',datos_suprimidos=true where solicitud_id=a.solicitud_id;
  end loop;
  for s in select * from public.solicitudes_establecimientos where solicitante_id=old.id or revisado_por=old.id loop
   j:=cercly_account_private.fila_suprimida('solicitudes_establecimientos',to_jsonb(s),old.id);
   update public.solicitudes_establecimientos set solicitante_id=(j->>'solicitante_id')::uuid,revisado_por=(j->>'revisado_por')::uuid,
    mensaje='',motivo_respuesta='',nombre_propuesto=null,datos_propuestos='{}',estado=(j->>'estado')::public.estado_solicitud,
    datos_suprimidos=true where id=s.id;
  end loop;
  for m in select * from public.auditoria_moderacion_establecimientos where actor_id=old.id loop
   update public.auditoria_moderacion_establecimientos set actor_id=null,datos_suprimidos=true where id=m.id;
  end loop;
  for h in select * from cercly_account_private.auditoria_eliminacion where sujeto_id=old.id or actor_id=old.id or destino_id=old.id loop
   j:=cercly_account_private.fila_suprimida('auditoria_eliminacion',to_jsonb(h),old.id);
   update cercly_account_private.auditoria_eliminacion set sujeto_id=(j->>'sujeto_id')::uuid,
    actor_id=(j->>'actor_id')::uuid,destino_id=(j->>'destino_id')::uuid where id=h.id;
  end loop;
  delete from cercly_account_private.ejecuciones_supresion where xid=txid_current();
 end if;
 if not ruta_qa then
  -- Cerrar únicamente el vínculo personal de la aprobación del caso actual.
  -- Se conserva el registro, su revisor, acción y fecha; no el ID innecesario
  -- del titular después de ejecutar su solicitud verificada.
  update cercly_account_private.auditoria_eliminacion audit_caso set sujeto_id=null
   where audit_caso.sujeto_id=old.id and audit_caso.actor_id is not null and audit_caso.actor_id<>old.id
   and audit_caso.accion='aprobar' and audit_caso.establecimiento_id is null and audit_caso.destino_id is null
   and audit_caso.solicitud_id=(select solicitud_id from cercly_account_private.solicitudes_eliminacion where usuario_id=old.id);
 end if;
 -- El perfil, preferencias, membresías y sesiones desaparecen por sus FK CASCADE.
 -- SET NULL de verificado_por conserva el hecho de moderación sin el ID borrado.
 delete from cercly_account_private.solicitudes_eliminacion where usuario_id=old.id;
 insert into cercly_account_private.resultados_supresion(resultado) values('auth_y_datos_desvinculados') returning recibo into r;
 return old;
end;
$$;

-- También las solicitudes deben serializar su referencia sin FK a Auth.
create function cercly_account_private.proteger_solicitante_auth()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform 1 from auth.users where id=new.solicitante_id for key share;
 if not found then raise exception using errcode='23503',message='Identidad solicitante inexistente'; end if;
 return new;
end;
$$;
create trigger proteger_solicitante_auth before insert on public.solicitudes_establecimientos
 for each row execute function cercly_account_private.proteger_solicitante_auth();

-- El JWT firmado puede durar hasta expirar; una identidad Auth eliminada no
-- conserva permisos de Data API/Storage aunque el token siga criptográficamente válido.
create function public.identidad_cercly_existente()
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users where id=auth.uid())
 and exists(select 1 from public.usuarios where id=auth.uid());
$$;
revoke all on function public.identidad_cercly_existente() from public,anon,authenticated,service_role;
grant execute on function public.identidad_cercly_existente() to authenticated;
do $policies$ declare r record; begin
 for r in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind in ('r','p') and c.relrowsecurity and
 (n.nspname='public' or (n.nspname='storage' and c.relname='objects')) loop
 execute format('create policy identidad_existente_privacidad on %I.%I as restrictive for all to authenticated using ((select public.identidad_cercly_existente())) with check ((select public.identidad_cercly_existente()))',r.nspname,r.relname);
 end loop;
end $policies$;

create function cercly_account_private.registrar_solicitud_propia()
returns text language plpgsql security definer set search_path = '' as $$
declare
  identidad uuid := auth.uid();
  resultado text;
  revision boolean;
begin
  if identidad is null or not exists(select 1 from auth.users where id = identidad) then
    raise exception using errcode = '28000', message = 'Sesión inválida';
  end if;
  if not cercly_account_private.sesion_reciente(identidad) then
    raise exception using errcode = '42501', message = 'Autenticación reciente requerida';
  end if;
  select not exists(select 1 from public.usuarios where id = identidad)
    or exists(select 1 from public.usuarios where id = identidad and rol = 'administrador')
    or cercly_account_private.tiene_dependencias(identidad) into revision;
  insert into cercly_account_private.solicitudes_eliminacion(usuario_id, estado)
    values (identidad, case when revision then 'revision' else 'pendiente' end)
    on conflict (usuario_id) do nothing;
  select estado into resultado from cercly_account_private.solicitudes_eliminacion
    where usuario_id = identidad for update;
  -- Una aprobación explícita no se revoca por el siguiente reintento.
  if resultado = 'aprobada' then return resultado; end if;
  if revision and resultado <> 'revision' then
    update cercly_account_private.solicitudes_eliminacion
      set estado = 'revision', actualizada_en = now() where usuario_id = identidad;
    return 'revision';
  end if;
  return resultado;
end;
$$;

create or replace function public.solicitar_eliminacion_cuenta()
returns text language plpgsql security definer set search_path='' as $$
begin
 if cercly_account_private.es_identidad_qa(auth.uid()) then
  raise exception using errcode='42501',message='Identidad QA requiere su ruta especifica';
 end if;
 return cercly_account_private.registrar_solicitud_propia();
end;
$$;
create function public.solicitar_eliminacion_cuenta_qa()
returns text language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not cercly_account_private.sujeto_qa_autorizado(auth.uid()) then
  raise exception using errcode='42501',message='Identidad fuera del ensayo QA autorizado';
 end if;
 return cercly_account_private.registrar_solicitud_propia();
end;
$$;
revoke all on function public.solicitar_eliminacion_cuenta_qa() from public,anon,authenticated,service_role;
grant execute on function public.solicitar_eliminacion_cuenta_qa() to authenticated;

create or replace function public.revisar_eliminacion_cuenta(
  p_usuario_id uuid, p_accion text, p_establecimiento_id uuid default null,
  p_destino_id uuid default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  solicitud cercly_account_private.solicitudes_eliminacion%rowtype;
  propietario uuid;
  rol_sujeto public.rol_usuario;
begin
  if actor is null or actor = p_usuario_id or not exists (
    select 1 from public.usuarios where id = actor and rol = 'administrador'
  ) or not cercly_account_private.sesion_reciente(actor) then
    raise exception using errcode = '42501', message = 'Administrador autorizado con sesión reciente requerido';
  end if;
  if cercly_account_private.es_identidad_qa(auth.uid())
    or cercly_account_private.es_identidad_qa(p_usuario_id) then
    raise exception using errcode='42501',message='Revision QA requiere su ruta especifica';
  end if;

  select * into solicitud from cercly_account_private.solicitudes_eliminacion
    where usuario_id = p_usuario_id for update;
  if not found then raise exception using errcode = '22023', message = 'Solicitud inexistente'; end if;
  select rol into rol_sujeto from public.usuarios where id = p_usuario_id for update;
  if rol_sujeto is null then
    raise exception using errcode = '22023', message = 'Perfil inexistente';
  end if;
  if p_accion = 'transferir' then
    if p_establecimiento_id is null or p_destino_id is null or p_destino_id = p_usuario_id
      or not exists(select 1 from public.usuarios u join auth.users a on a.id = u.id
        where u.id = p_destino_id and u.rol in ('propietario', 'administrador'))
      or not exists(select 1 from public.miembros_establecimiento m
        where m.establecimiento_id = p_establecimiento_id
          and m.usuario_id = p_destino_id and m.activo and m.rol = 'administrador') then
      raise exception using errcode = '22023', message = 'Destino no autorizado';
    end if;
    select propietario_id into propietario from public.establecimientos
      where id = p_establecimiento_id for update;
    if propietario is distinct from p_usuario_id then
      raise exception using errcode = '22023', message = 'Establecimiento no pertenece al solicitante';
    end if;
    perform pg_catalog.set_config('cercly_account_private.review_operation',
      actor::text || ':' || p_usuario_id::text || ':' || p_establecimiento_id::text, true);
    update public.establecimientos set propietario_id = p_destino_id
      where id = p_establecimiento_id;
  elsif p_accion = 'desactivar' then
    if p_establecimiento_id is null or p_destino_id is not null then
      raise exception using errcode = '22023', message = 'Parámetros inválidos';
    end if;
    select propietario_id into propietario from public.establecimientos
      where id = p_establecimiento_id for update;
    if propietario is distinct from p_usuario_id then
      raise exception using errcode = '22023', message = 'Establecimiento no pertenece al solicitante';
    end if;
    perform pg_catalog.set_config('cercly_account_private.review_operation',
      actor::text || ':' || p_usuario_id::text || ':' || p_establecimiento_id::text, true);
    update public.establecimientos set estado = 'rechazado', publicable = false
      where id = p_establecimiento_id;
    update public.promociones set activa = false where establecimiento_id = p_establecimiento_id;
  elsif p_accion = 'aprobar' then
    if p_establecimiento_id is not null or p_destino_id is not null
      or cercly_account_private.tiene_dependencias(p_usuario_id) then
      raise exception using errcode = '23503', message = 'Dependencias sin resolver';
    end if;
    if rol_sujeto = 'administrador' and
      (select count(*) from public.usuarios where rol = 'administrador') <= 1 then
      raise exception using errcode = '42501', message = 'Último administrador activo';
    end if;
    update cercly_account_private.solicitudes_eliminacion
      set estado = 'aprobada', actualizada_en = now() where usuario_id = p_usuario_id;
  else
    raise exception using errcode = '22023', message = 'Acción inválida';
  end if;
  insert into cercly_account_private.auditoria_eliminacion
    (solicitud_id, sujeto_id, actor_id, accion, establecimiento_id, destino_id)
    values (solicitud.solicitud_id, p_usuario_id, actor, p_accion,
      p_establecimiento_id, p_destino_id);
  return case when p_accion = 'aprobar' then 'aprobada' else 'revision' end;
end;
$$;
-- ACL cerradas para helpers/capacidades privadas, sin EXECUTE público por defecto.
do $acl$ declare f record; begin
 for f in select p.oid::regprocedure firma from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='cercly_account_private' loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',f.firma);
 end loop;
end $acl$;
alter function public.autorizar_supresion_revisada_qa(uuid,text,text,boolean) owner to postgres;
alter function public.obtener_huella_revision_privacidad_qa(uuid) owner to postgres;
revoke all on function public.autorizar_supresion_revisada_qa(uuid,text,text,boolean) from public,anon,authenticated,service_role;
revoke all on function public.obtener_huella_revision_privacidad_qa(uuid) from public,anon,authenticated,service_role;
grant execute on function public.autorizar_supresion_revisada_qa(uuid,text,text,boolean) to authenticated;
grant execute on function public.obtener_huella_revision_privacidad_qa(uuid) to authenticated;
revoke all on function public.conservar_auditoria_moderacion() from public,anon,authenticated,service_role;
commit;
