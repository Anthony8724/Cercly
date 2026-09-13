begin;

drop function if exists public.buscar_establecimientos_cercanos(
  double precision,
  double precision,
  integer,
  uuid,
  uuid[],
  boolean,
  integer,
  integer
);

create function public.buscar_establecimientos_cercanos(
  p_latitud double precision,
  p_longitud double precision,
  p_radio_metros integer default 5000,
  p_categoria_id uuid default null,
  p_subcategoria_ids uuid[] default null,
  p_solo_promociones boolean default false,
  p_busqueda text default null,
  p_limite integer default 20,
  p_desplazamiento integer default 0
)
returns table (
  id uuid,
  nombre varchar,
  descripcion varchar,
  direccion varchar,
  latitud double precision,
  longitud double precision,
  telefono_publico varchar,
  zona_horaria varchar,
  categoria_id uuid,
  ciudad varchar,
  provincia varchar,
  pais_codigo char(2),
  distancia_metros double precision,
  tiene_promociones boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  punto_usuario extensions.geography;
  termino_busqueda text;
begin
  if p_latitud < -90 or p_latitud > 90 then
    raise exception 'La latitud debe estar entre -90 y 90';
  end if;

  if p_longitud < -180 or p_longitud > 180 then
    raise exception 'La longitud debe estar entre -180 y 180';
  end if;

  if p_radio_metros < 1 or p_radio_metros > 50000 then
    raise exception 'El radio debe estar entre 1 y 50000 metros';
  end if;

  if p_limite < 1 or p_limite > 100 then
    raise exception 'El límite debe estar entre 1 y 100';
  end if;

  if p_desplazamiento < 0 then
    raise exception 'El desplazamiento no puede ser negativo';
  end if;

  termino_busqueda := nullif(
    translate(lower(btrim(coalesce(p_busqueda, ''))), 'áéíóúüñ', 'aeiouun'),
    ''
  );

  punto_usuario := extensions.st_setsrid(
    extensions.st_makepoint(p_longitud, p_latitud),
    4326
  )::extensions.geography;

  return query
  select
    e.id,
    e.nombre,
    e.descripcion,
    e.direccion,
    e.latitud,
    e.longitud,
    e.telefono_publico,
    e.zona_horaria,
    e.categoria_id,
    e.ciudad,
    e.provincia,
    e.pais_codigo,
    extensions.st_distance(e.ubicacion, punto_usuario) as distancia_metros,
    exists (
      select 1
      from public.promociones p
      where p.establecimiento_id = e.id
        and p.activa
        and now() between p.fecha_inicio and p.fecha_fin
    ) as tiene_promociones
  from public.establecimientos e
  where e.estado = 'aprobado'::public.estado_establecimiento
    and e.publicable
    and extensions.st_dwithin(
      e.ubicacion,
      punto_usuario,
      p_radio_metros
    )
    and (
      p_categoria_id is null
      or e.categoria_id = p_categoria_id
    )
    and (
      p_subcategoria_ids is null
      or exists (
        select 1
        from public.establecimiento_categorias ec
        where ec.establecimiento_id = e.id
          and ec.subcategoria_id = any(p_subcategoria_ids)
      )
    )
    and (
      not p_solo_promociones
      or exists (
        select 1
        from public.promociones p
        where p.establecimiento_id = e.id
          and p.activa
          and now() between p.fecha_inicio and p.fecha_fin
      )
    )
    and (
      termino_busqueda is null
      or translate(lower(e.nombre), 'áéíóúüñ', 'aeiouun')
        like '%' || termino_busqueda || '%'
      or exists (
        select 1
        from public.categorias c
        where c.id = e.categoria_id
          and translate(lower(c.nombre), 'áéíóúüñ', 'aeiouun')
            like '%' || termino_busqueda || '%'
      )
      or exists (
        select 1
        from public.establecimiento_categorias ec
        join public.subcategorias s on s.id = ec.subcategoria_id
        where ec.establecimiento_id = e.id
          and translate(lower(s.nombre), 'áéíóúüñ', 'aeiouun')
            like '%' || termino_busqueda || '%'
      )
    )
  order by extensions.st_distance(e.ubicacion, punto_usuario), e.nombre
  limit p_limite
  offset p_desplazamiento;
end;
$$;

revoke all on function public.buscar_establecimientos_cercanos(
  double precision,
  double precision,
  integer,
  uuid,
  uuid[],
  boolean,
  text,
  integer,
  integer
) from public;

grant execute on function public.buscar_establecimientos_cercanos(
  double precision,
  double precision,
  integer,
  uuid,
  uuid[],
  boolean,
  text,
  integer,
  integer
) to anon, authenticated;

commit;
