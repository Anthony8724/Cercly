create type public.rol_miembro_establecimiento as enum (
  'administrador',
  'editor'
);

create table public.miembros_establecimiento (
  establecimiento_id uuid not null,
  usuario_id uuid not null,
  rol public.rol_miembro_establecimiento not null default 'editor',
  activo boolean not null default true,
  creado_en timestamp with time zone not null default now(),
  actualizado_en timestamp with time zone not null default now(),

  constraint miembros_establecimiento_pkey
    primary key (establecimiento_id, usuario_id),

  constraint miembros_establecimiento_establecimiento_id_fkey
    foreign key (establecimiento_id)
    references public.establecimientos(id)
    on delete cascade,

  constraint miembros_establecimiento_usuario_id_fkey
    foreign key (usuario_id)
    references public.usuarios(id)
    on delete cascade
);

create index miembros_establecimiento_usuario_idx
  on public.miembros_establecimiento(usuario_id);

alter table public.miembros_establecimiento
  enable row level security;

create trigger actualizar_miembros_establecimiento
before update on public.miembros_establecimiento
for each row
execute function public.actualizar_fecha_modificacion();

create or replace function public.puede_gestionar_establecimiento(
  p_establecimiento_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    public.es_administrador()
    or exists (
      select 1
      from public.establecimientos as e
      where e.id = p_establecimiento_id
        and e.propietario_id = auth.uid()
    )
    or exists (
      select 1
      from public.miembros_establecimiento as m
      where m.establecimiento_id = p_establecimiento_id
        and m.usuario_id = auth.uid()
        and m.activo = true
    );
$function$;

revoke all
on function public.puede_gestionar_establecimiento(uuid)
from public, anon;

grant execute
on function public.puede_gestionar_establecimiento(uuid)
to authenticated;

create policy "miembro lee sus accesos"
on public.miembros_establecimiento
for select
to authenticated
using (
  usuario_id = auth.uid()
  or public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "administrador gestiona miembros"
on public.miembros_establecimiento
for all
to authenticated
using (public.es_administrador())
with check (public.es_administrador());

grant select, insert, update, delete
on table public.miembros_establecimiento
to authenticated;

create policy "colaborador lee establecimiento"
on public.establecimientos
for select
to authenticated
using (
  exists (
    select 1
    from public.miembros_establecimiento as m
    where m.establecimiento_id = establecimientos.id
      and m.usuario_id = auth.uid()
      and m.activo = true
  )
);

create policy "colaborador actualiza establecimiento"
on public.establecimientos
for update
to authenticated
using (
  exists (
    select 1
    from public.miembros_establecimiento as m
    where m.establecimiento_id = establecimientos.id
      and m.usuario_id = auth.uid()
      and m.activo = true
  )
)
with check (
  exists (
    select 1
    from public.miembros_establecimiento as m
    where m.establecimiento_id = establecimientos.id
      and m.usuario_id = auth.uid()
      and m.activo = true
  )
);

create policy "colaborador lee horarios"
on public.horarios_establecimiento
for select
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador crea horarios"
on public.horarios_establecimiento
for insert
to authenticated
with check (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador actualiza horarios"
on public.horarios_establecimiento
for update
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
)
with check (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador elimina horarios"
on public.horarios_establecimiento
for delete
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador lee fotografias"
on public.fotos_establecimiento
for select
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador crea fotografias"
on public.fotos_establecimiento
for insert
to authenticated
with check (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador actualiza fotografias"
on public.fotos_establecimiento
for update
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
)
with check (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador elimina fotografias"
on public.fotos_establecimiento
for delete
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador lee promociones"
on public.promociones
for select
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador crea promociones"
on public.promociones
for insert
to authenticated
with check (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador actualiza promociones"
on public.promociones
for update
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
)
with check (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

create policy "colaborador elimina promociones"
on public.promociones
for delete
to authenticated
using (
  public.puede_gestionar_establecimiento(establecimiento_id)
);

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
  v_motivo text := trim(coalesce(p_motivo_respuesta, ''));
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

  if p_estado = 'rechazada'::public.estado_solicitud
     and v_motivo = '' then
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
    case v_solicitud.tipo
      when 'reclamar'::public.tipo_solicitud_establecimiento then
        update public.establecimientos
        set propietario_id = v_solicitud.solicitante_id
        where id = v_solicitud.establecimiento_id;

        delete from public.miembros_establecimiento
        where establecimiento_id = v_solicitud.establecimiento_id
          and usuario_id = v_solicitud.solicitante_id;

        update public.usuarios
        set rol = 'propietario'::public.rol_usuario
        where id = v_solicitud.solicitante_id
          and rol = 'usuario'::public.rol_usuario;

      when 'acceso'::public.tipo_solicitud_establecimiento then
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
        null;

      else
        raise exception 'El tipo de solicitud no es válido.';
    end case;
  end if;

  update public.solicitudes_establecimientos
  set
    estado = p_estado,
    motivo_respuesta = v_motivo
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