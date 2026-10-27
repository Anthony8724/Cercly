alter table public.solicitudes_establecimientos
  alter column establecimiento_id drop not null;

alter table public.solicitudes_establecimientos
  drop constraint if exists solicitudes_establecimientos_registro_destino_check;

alter table public.solicitudes_establecimientos
  add constraint solicitudes_establecimientos_registro_destino_check
  check (
    (tipo = 'registro' and
      ((estado = 'aprobada' and establecimiento_id is not null)
       or (estado <> 'aprobada' and establecimiento_id is null)))
    or (tipo <> 'registro' and establecimiento_id is not null)
  );

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

create or replace function public.responder_solicitud_establecimiento(
  p_solicitud_id uuid,
  p_estado public.estado_solicitud,
  p_motivo_respuesta text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.solicitudes_establecimientos%rowtype;
  e public.establecimientos%rowtype;
  propuesta jsonb;
  nuevo_establecimiento uuid;
  motivo text := trim(coalesce(p_motivo_respuesta, ''));
  revisado timestamptz := now();
begin
  if auth.uid() is null or not public.es_administrador() then
    raise exception 'Solo un administrador autenticado puede responder solicitudes.';
  end if;
  if p_estado not in ('aprobada'::public.estado_solicitud, 'rechazada'::public.estado_solicitud) then
    raise exception 'La respuesta debe ser aprobada o rechazada.';
  end if;
  if char_length(motivo) > 1000 then
    raise exception 'El motivo no puede superar los 1000 caracteres.';
  end if;
  if p_estado = 'rechazada' and motivo = '' then
    raise exception 'Debes indicar el motivo del rechazo.';
  end if;

  select * into s from public.solicitudes_establecimientos where id = p_solicitud_id for update;
  if not found then raise exception 'La solicitud no existe.'; end if;
  if s.estado <> 'pendiente' then raise exception 'La solicitud ya fue respondida.'; end if;

  if p_estado = 'aprobada' then
    if s.tipo = 'registro' then
      propuesta := s.datos_propuestos;
      insert into public.establecimientos (
        propietario_id, categoria_id, nombre, descripcion, direccion,
        latitud, longitud, telefono_publico, zona_horaria, fuente,
        estado, publicable, estado_reclamo
      ) values (
        s.solicitante_id,
        (propuesta->>'categoria_id')::uuid,
        trim(propuesta->>'nombre'),
        trim(coalesce(propuesta->>'descripcion', '')),
        trim(propuesta->>'direccion'),
        (propuesta->>'latitud')::double precision,
        (propuesta->>'longitud')::double precision,
        trim(coalesce(propuesta->>'telefono_publico', '')),
        'America/Guayaquil', 'cercly', 'aprobado', true, null
      ) returning id into nuevo_establecimiento;

      if jsonb_typeof(propuesta->'horarios') = 'array' then
        insert into public.horarios_establecimiento (
          establecimiento_id, dia_semana, apertura_minutos,
          cierre_minutos, cierra_al_dia_siguiente
        )
        select nuevo_establecimiento,
          (h->>'dia_semana')::smallint,
          (h->>'apertura_minutos')::smallint,
          (h->>'cierre_minutos')::smallint,
          coalesce((h->>'cierra_al_dia_siguiente')::boolean, false)
        from jsonb_array_elements(propuesta->'horarios') h;
      end if;

      update public.usuarios set rol = 'propietario'::public.rol_usuario
      where id = s.solicitante_id and rol = 'usuario'::public.rol_usuario;
    else
      select * into e from public.establecimientos where id = s.establecimiento_id for update;
      if not found then raise exception 'El establecimiento no existe.'; end if;
      case s.tipo
        when 'reclamar' then
          if e.fuente <> 'osm' or e.estado_reclamo <> 'no_reclamado' or e.propietario_id is not null then
            raise exception 'El establecimiento ya no está disponible para reclamo';
          end if;
          update public.establecimientos set propietario_id = s.solicitante_id,
            estado_reclamo = 'reclamado', reclamado_en = revisado
          where id = s.establecimiento_id;
          delete from public.miembros_establecimiento
          where establecimiento_id = s.establecimiento_id and usuario_id = s.solicitante_id;
          update public.usuarios set rol = 'propietario'::public.rol_usuario
          where id = s.solicitante_id and rol = 'usuario'::public.rol_usuario;
        when 'acceso' then
          if e.propietario_id is null then raise exception 'El establecimiento todavía no tiene administrador.'; end if;
          insert into public.miembros_establecimiento (establecimiento_id, usuario_id, rol, activo)
          values (s.establecimiento_id, s.solicitante_id, 'editor', true)
          on conflict (establecimiento_id, usuario_id) do update
          set rol = excluded.rol, activo = true, actualizado_en = now();
          update public.usuarios set rol = 'propietario'::public.rol_usuario
          where id = s.solicitante_id and rol = 'usuario'::public.rol_usuario;
        when 'correccion' then null;
        else raise exception 'El tipo de solicitud no es válido.';
      end case;
    end if;
  end if;

  update public.solicitudes_establecimientos
  set estado = p_estado,
      motivo_respuesta = motivo,
      revisado_por = auth.uid(),
      revisado_en = revisado,
      establecimiento_id = coalesce(nuevo_establecimiento, establecimiento_id)
  where id = p_solicitud_id;
end;
$$;

revoke all on function public.responder_solicitud_establecimiento(uuid, public.estado_solicitud, text)
  from public, anon;
grant execute on function public.responder_solicitud_establecimiento(uuid, public.estado_solicitud, text)
  to authenticated;

drop policy if exists "propietario crea establecimiento pendiente" on public.establecimientos;
drop policy if exists "administrador responde solicitudes"
  on public.solicitudes_establecimientos;
-- Solo los administradores conservan la política de INSERT directa. Los
-- usuarios nuevos pasan por solicitudes_establecimientos. Las respuestas
-- administrativas ocurren solo por la RPC que guarda revisión y auditoría.

-- Búsqueda privada del solicitante/admin; las solicitudes no se publican ni
-- se agregan a la función de mapa hasta que la aprobación cree la ficha.
