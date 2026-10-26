-- Política local de eliminación. Aplicar después de 20261025225101.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

alter table cercly_account_private.solicitudes_eliminacion
  drop constraint solicitudes_eliminacion_estado_check;
alter table cercly_account_private.solicitudes_eliminacion
  add constraint solicitudes_eliminacion_estado_check
  check (estado in ('pendiente', 'revision', 'aprobada'));

create table if not exists cercly_account_private.auditoria_eliminacion (
  id bigint generated always as identity primary key,
  solicitud_id uuid not null,
  sujeto_id uuid not null,
  actor_id uuid not null,
  accion text not null check (accion in ('transferir', 'desactivar', 'aprobar')),
  establecimiento_id uuid,
  destino_id uuid,
  creada_en timestamptz not null default now()
);
alter table cercly_account_private.auditoria_eliminacion enable row level security;
revoke all on cercly_account_private.auditoria_eliminacion from public, anon, authenticated;

-- Se comprueban los dos FK RESTRICT, Storage y cualquier objeto atribuible.
-- Relaciones nuevas deberán incorporarse aquí antes de activar el despliegue.
create or replace function cercly_account_private.tiene_dependencias(p_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.establecimientos where propietario_id = p_id)
    or exists(select 1 from public.solicitudes_establecimientos where solicitante_id = p_id)
    or exists(select 1 from pg_catalog.pg_constraint c
      join pg_catalog.pg_class t on t.oid = c.conrelid
      join pg_catalog.pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public' and c.contype = 'f' and c.confrelid in
        ('public.usuarios'::regclass, 'auth.users'::regclass)
        and c.conname not in ('usuarios_id_fkey',
          'miembros_establecimiento_usuario_id_fkey',
          'establecimientos_propietario_id_fkey',
          'solicitudes_establecimientos_solicitante_id_fkey',
          'establecimientos_verificado_por_fkey',
          'solicitudes_establecimientos_revisado_por_fkey'))
    or exists(select 1 from storage.objects where owner_id = p_id::text
      or (bucket_id in ('establecimientos-imagenes', 'promociones-imagenes')
        and name like p_id::text || '/%'));
$$;
revoke all on function cercly_account_private.tiene_dependencias(uuid) from public, anon, authenticated;

create or replace function cercly_account_private.sesion_reciente(p_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.sessions s
    where s.id = nullif(auth.jwt()->>'session_id', '')::uuid
      and s.user_id = p_id
      and s.created_at >= now() - interval '5 minutes'
  );
$$;
revoke all on function cercly_account_private.sesion_reciente(uuid) from public, anon, authenticated;

create or replace function public.solicitar_eliminacion_cuenta()
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
revoke all on function public.solicitar_eliminacion_cuenta() from public, anon;
grant execute on function public.solicitar_eliminacion_cuenta() to authenticated;

create or replace function public.listar_solicitudes_eliminacion()
returns table(usuario_id uuid, estado text, creada_en timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.usuarios
      where id = auth.uid() and rol = 'administrador')
    or not cercly_account_private.sesion_reciente(auth.uid()) then
    raise exception using errcode = '42501', message = 'Administrador autorizado con sesión reciente requerido';
  end if;
  return query select s.usuario_id, s.estado, s.creada_en
    from cercly_account_private.solicitudes_eliminacion s
    order by s.creada_en;
end;
$$;
revoke all on function public.listar_solicitudes_eliminacion() from public, anon;
grant execute on function public.listar_solicitudes_eliminacion() to authenticated;

-- Operaciones de una solicitud ajena, por administrador con sesión reciente.
-- La aprobación deja el borrado final en manos del propio titular autenticado.
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
revoke all on function public.revisar_eliminacion_cuenta(uuid,text,uuid,uuid)
  from public, anon;
grant execute on function public.revisar_eliminacion_cuenta(uuid,text,uuid,uuid)
  to authenticated;

-- Bloquea atajos del panel administrativo mientras el titular tenga una
-- solicitud activa: el cambio debe pasar por la RPC que deja auditoría.
create or replace function cercly_account_private.proteger_negocio_en_revision()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists(select 1 from cercly_account_private.solicitudes_eliminacion
      where usuario_id = old.propietario_id) then
    if tg_op = 'DELETE' then
      raise exception using errcode = '42501', message = 'Negocio compartido en revisión';
    end if;
    if (new.propietario_id, new.estado, new.publicable) is distinct from
       (old.propietario_id, old.estado, old.publicable)
      and current_setting('cercly_account_private.review_operation', true)
        is distinct from auth.uid()::text || ':' || old.propietario_id::text || ':' || old.id::text then
      raise exception using errcode = '42501', message = 'Usar revisión administrativa';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function cercly_account_private.proteger_negocio_en_revision()
  from public, anon, authenticated;
drop trigger if exists proteger_negocio_en_revision on public.establecimientos;
create trigger proteger_negocio_en_revision before update or delete
  on public.establecimientos for each row
  execute function cercly_account_private.proteger_negocio_en_revision();

-- Última barrera antes de llamar a Auth. Revalida roles y FK.
create or replace function public.validar_eliminacion_cuenta(p_usuario_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare estado_actual text; rol_actual public.rol_usuario;
begin
  select estado into estado_actual from cercly_account_private.solicitudes_eliminacion
    where usuario_id = p_usuario_id for update;
  if estado_actual not in ('pendiente','aprobada') then return false; end if;
  select rol into rol_actual from public.usuarios where id = p_usuario_id for update;
  if rol_actual is null or cercly_account_private.tiene_dependencias(p_usuario_id) then return false; end if;
  if rol_actual = 'administrador' and (estado_actual <> 'aprobada' or
    (select count(*) from public.usuarios where rol = 'administrador') <= 1) then
    return false;
  end if;
  return true;
end;
$$;
revoke all on function public.validar_eliminacion_cuenta(uuid) from public, anon, authenticated;
grant execute on function public.validar_eliminacion_cuenta(uuid) to service_role;

-- Defensa transaccional contra dos borrados administrativos concurrentes y
-- contra operaciones Auth fuera de la Edge Function.
create or replace function cercly_account_private.proteger_ultimo_administrador()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(92312, 1);
  if exists(select 1 from public.usuarios where id = old.id and rol = 'administrador')
    and (select count(*) from public.usuarios where rol = 'administrador') <= 1 then
    raise exception using errcode = '42501', message = 'Último administrador activo';
  end if;
  return old;
end;
$$;
revoke all on function cercly_account_private.proteger_ultimo_administrador()
  from public, anon, authenticated;
drop trigger if exists proteger_ultimo_administrador on auth.users;
create trigger proteger_ultimo_administrador before delete on auth.users
  for each row execute function cercly_account_private.proteger_ultimo_administrador();
commit;
