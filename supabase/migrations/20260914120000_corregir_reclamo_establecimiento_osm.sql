-- Adapta la respuesta administrativa de solicitudes al modelo OSM/PostGIS.
-- La solicitud y el establecimiento se bloquean en la misma transaccion para
-- impedir que dos reclamos pendientes asignen propietarios distintos.

create or replace function public.responder_solicitud_establecimiento(
  p_solicitud_id uuid,
  p_estado public.estado_solicitud,
  p_motivo_respuesta text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_solicitud public.solicitudes_establecimientos%rowtype;
  v_establecimiento public.establecimientos%rowtype;
  v_motivo text := trim(coalesce(p_motivo_respuesta, ''));
  v_revisado_en timestamptz := now();
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  if not public.es_administrador() then
    raise exception 'Solo un administrador puede responder solicitudes.';
  end if;

  if p_estado not in (
    'aprobada'::public.estado_solicitud,
    'rechazada'::public.estado_solicitud
  ) then
    raise exception 'La respuesta debe ser aprobada o rechazada.';
  end if;

  if char_length(v_motivo) > 1000 then
    raise exception 'El motivo no puede superar los 1000 caracteres.';
  end if;

  if p_estado = 'rechazada'::public.estado_solicitud and v_motivo = '' then
    raise exception 'Debes indicar el motivo del rechazo.';
  end if;

  select *
  into v_solicitud
  from public.solicitudes_establecimientos
  where id = p_solicitud_id
  for update;

  if not found then
    raise exception 'La solicitud no existe.';
  end if;

  if v_solicitud.estado <> 'pendiente'::public.estado_solicitud then
    raise exception 'La solicitud ya fue respondida.';
  end if;

  if p_estado = 'aprobada'::public.estado_solicitud then
    select *
    into v_establecimiento
    from public.establecimientos
    where id = v_solicitud.establecimiento_id
    for update;

    if not found then
      raise exception 'El establecimiento no existe.';
    end if;

    case v_solicitud.tipo
      when 'reclamar'::public.tipo_solicitud_establecimiento then
        if v_establecimiento.fuente <> 'osm'::public.fuente_establecimiento
           or v_establecimiento.estado_reclamo <>
             'no_reclamado'::public.estado_reclamo_establecimiento
           or v_establecimiento.propietario_id is not null then
          raise exception 'El establecimiento ya no está disponible para reclamo.';
        end if;

        update public.establecimientos
        set
          propietario_id = v_solicitud.solicitante_id,
          estado_reclamo = 'reclamado'::public.estado_reclamo_establecimiento,
          reclamado_en = v_revisado_en
        where id = v_solicitud.establecimiento_id;

        delete from public.miembros_establecimiento
        where establecimiento_id = v_solicitud.establecimiento_id
          and usuario_id = v_solicitud.solicitante_id;

        update public.usuarios
        set rol = 'propietario'::public.rol_usuario
        where id = v_solicitud.solicitante_id
          and rol = 'usuario'::public.rol_usuario;

      when 'acceso'::public.tipo_solicitud_establecimiento then
        if v_establecimiento.propietario_id is null then
          raise exception 'El establecimiento todavía no tiene administrador.';
        end if;

        insert into public.miembros_establecimiento (
          establecimiento_id,
          usuario_id,
          rol,
          activo
        )
        values (
          v_solicitud.establecimiento_id,
          v_solicitud.solicitante_id,
          'editor'::public.rol_miembro_establecimiento,
          true
        )
        on conflict (establecimiento_id, usuario_id)
        do update set
          rol = excluded.rol,
          activo = true,
          actualizado_en = now();

        update public.usuarios
        set rol = 'propietario'::public.rol_usuario
        where id = v_solicitud.solicitante_id
          and rol = 'usuario'::public.rol_usuario;

      when 'correccion'::public.tipo_solicitud_establecimiento then
        -- La correccion sigue siendo informativa: la aprobacion no cambia
        -- automaticamente los datos del establecimiento.
        null;

      else
        raise exception 'El tipo de solicitud no es válido.';
    end case;
  end if;

  update public.solicitudes_establecimientos
  set
    estado = p_estado,
    motivo_respuesta = v_motivo,
    revisado_por = auth.uid(),
    revisado_en = v_revisado_en
  where id = p_solicitud_id;
end;
$function$;

revoke all
on function public.responder_solicitud_establecimiento(
  uuid,
  public.estado_solicitud,
  text
)
from public, anon;

grant execute
on function public.responder_solicitud_establecimiento(
  uuid,
  public.estado_solicitud,
  text
)
to authenticated;
