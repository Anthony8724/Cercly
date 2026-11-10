-- Propuesta LOCAL posterior a las 26 migraciones de STAGING. No desplegada.
-- No modifica datos existentes, no amplía UPDATE ni automatiza supresión.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$ begin
 if to_regclass('public.correcciones_aplicadas') is null
 or to_regprocedure('public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)') is null
 or not exists(select 1 from pg_trigger where tgrelid='public.establecimientos'::regclass
   and tgname='limitar_actualizacion_directa_establecimiento' and not tgisinternal) then
   raise exception using errcode='42883', message='Aplicar primero las dos migraciones de correcciones y seguridad';
 end if;
 if has_function_privilege('anon','public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)','EXECUTE')
 or has_function_privilege('service_role','public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)','EXECUTE')
 or not has_function_privilege('authenticated','public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)','EXECUTE') then
   raise exception using errcode='42501', message='ACL de moderacion inesperada: revisar antes de migrar';
 end if;
end $$;

create or replace function public.limitar_actualizacion_directa_establecimiento()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user in ('postgres','supabase_admin') then return new; end if;
 if current_user <> 'authenticated' or auth.uid() is null then
   raise exception using errcode='42501', message='Procedimiento autorizado requerido';
 end if;
 if public.es_administrador() then
   if (to_jsonb(new)-array['estado','actualizado_en','ubicacion']) is distinct from
      (to_jsonb(old)-array['estado','actualizado_en','ubicacion']) then
     raise exception using errcode='42501', message='El administrador solo puede moderar el estado directamente';
   end if;
   if new.estado <> 'aprobado' then new.publicable := false; end if;
 elsif not public.puede_gestionar_como_propietario(old.id) then
   raise exception using errcode='42501', message='Establecimiento ajeno';
 elsif old.estado='aprobado' and
   (to_jsonb(new)->'nombre',to_jsonb(new)->'descripcion',to_jsonb(new)->'direccion',
    to_jsonb(new)->'telefono_publico',new.categoria_id,new.latitud,new.longitud)
   is distinct from
   (to_jsonb(old)->'nombre',to_jsonb(old)->'descripcion',to_jsonb(old)->'direccion',
    to_jsonb(old)->'telefono_publico',old.categoria_id,old.latitud,old.longitud) then
   raise exception using errcode='42501', message='Ficha aprobada: solicitud de correccion requerida';
 end if;
 return new;
end $$;

-- La sincronización de subcategorías es SECURITY DEFINER: comprobar ANTES
-- de entrar en ella y bloquear la ficha evita el bypass y su carrera con moderación.
create function public.proteger_categoria_aprobada()
returns trigger language plpgsql security invoker set search_path='' as $$
declare e public.establecimientos%rowtype; categoria uuid;
begin
 if current_user in ('postgres','supabase_admin') or not new.es_principal then return new; end if;
 select * into e from public.establecimientos where id=new.establecimiento_id for update;
 select categoria_id into categoria from public.subcategorias where id=new.subcategoria_id;
 if e.estado='aprobado' and e.categoria_id is distinct from categoria then
   raise exception using errcode='42501', message='Ficha aprobada: solicitud de correccion requerida';
 end if;
 return new;
end $$;
revoke all on function public.proteger_categoria_aprobada() from public,anon,authenticated,service_role;
create trigger proteger_categoria_aprobada before insert or update
 on public.establecimiento_categorias for each row execute function public.proteger_categoria_aprobada();

-- Identificadores de auditoría sin FK destructiva ni textos/contactos del negocio.
create table public.auditoria_moderacion_establecimientos (
 id uuid primary key default gen_random_uuid(),
 establecimiento_id uuid not null,
 actor_id uuid,
 ejecutor_db name not null,
 estado_anterior public.estado_establecimiento not null,
 estado_nuevo public.estado_establecimiento not null,
 publicable_anterior boolean not null,
 publicable_nuevo boolean not null,
 creado_en timestamptz not null default now(),
 conservar_hasta timestamptz,
 check (estado_anterior is distinct from estado_nuevo or publicable_anterior is distinct from publicable_nuevo)
);
alter table public.auditoria_moderacion_establecimientos enable row level security;
revoke all on public.auditoria_moderacion_establecimientos from public,anon,authenticated,service_role;
grant select on public.auditoria_moderacion_establecimientos to authenticated;
create policy "administrador consulta moderacion" on public.auditoria_moderacion_establecimientos
 for select to authenticated using ((select public.es_administrador()));
create index auditoria_moderacion_actor_idx on public.auditoria_moderacion_establecimientos(actor_id);
create index auditoria_moderacion_ficha_fecha_idx on public.auditoria_moderacion_establecimientos(establecimiento_id,creado_en);

create function public.registrar_moderacion_establecimiento()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if (old.estado,old.publicable) is not distinct from (new.estado,new.publicable) then return new; end if;
 if auth.uid() is not null and not public.es_administrador() then
   raise exception using errcode='42501', message='Moderacion requiere administrador';
 end if;
 insert into public.auditoria_moderacion_establecimientos
  (establecimiento_id,actor_id,ejecutor_db,estado_anterior,estado_nuevo,publicable_anterior,publicable_nuevo)
 values(new.id,auth.uid(),session_user,old.estado,new.estado,old.publicable,new.publicable);
 return new;
end $$;
alter function public.registrar_moderacion_establecimiento() owner to postgres;
revoke all on function public.registrar_moderacion_establecimiento() from public,anon,authenticated,service_role;
create trigger registrar_moderacion_establecimiento after update on public.establecimientos
 for each row execute function public.registrar_moderacion_establecimiento();

create function public.conservar_auditoria_moderacion()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 raise exception using errcode='42501', message='Auditoria inmutable: requiere procedimiento de privacidad revisado';
end $$;
revoke all on function public.conservar_auditoria_moderacion() from public,anon,authenticated,service_role;
create trigger conservar_auditoria_moderacion before update or delete
 on public.auditoria_moderacion_establecimientos for each row execute function public.conservar_auditoria_moderacion();

create or replace function public.moderar_estado_establecimiento(
 p_id uuid, p_estado public.estado_establecimiento, p_publicable boolean default null)
returns void language plpgsql security definer set search_path='' as $$
declare e public.establecimientos%rowtype; publicar boolean;
begin
 if auth.uid() is null or not public.es_administrador() then
   raise exception using errcode='42501', message='Administrador autenticado requerido';
 end if;
 if p_estado is null or (p_publicable is true and p_estado <> 'aprobado') then
   raise exception using errcode='22023', message='Estado y publicacion incompatibles';
 end if;
 select * into e from public.establecimientos where id=p_id for update;
 if not found then raise exception using errcode='22023', message='Establecimiento inexistente'; end if;
 publicar := case when p_estado <> 'aprobado' then false else coalesce(p_publicable,e.publicable) end;
 if (e.estado,e.publicable) is not distinct from (p_estado,publicar) then return; end if;
 update public.establecimientos set estado=p_estado,publicable=publicar where id=e.id;
end $$;
-- CREATE OR REPLACE conserva los ACL cerrados de la migración anterior.

-- Un plazo provisional no es una decisión legal. Conservar marcas existentes
-- como referencia histórica, sin eliminación automática ni nuevos plazos por defecto.
alter table public.correcciones_aplicadas alter column conservar_hasta drop default,
 alter column conservar_hasta drop not null;
create index correcciones_solicitante_idx on public.correcciones_aplicadas(solicitante_id);
create index correcciones_revisor_idx on public.correcciones_aplicadas(revisado_por);

create or replace function cercly_account_private.tiene_dependencias(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.establecimientos where propietario_id=p_id)
 or exists(select 1 from public.solicitudes_establecimientos where solicitante_id=p_id or revisado_por=p_id)
 or exists(select 1 from public.correcciones_aplicadas where solicitante_id=p_id or revisado_por=p_id)
 or exists(select 1 from public.auditoria_moderacion_establecimientos where actor_id=p_id)
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
commit;
