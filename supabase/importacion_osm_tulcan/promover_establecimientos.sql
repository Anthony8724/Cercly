-- Promocion idempotente del lote OSM de Tulcan desde staging.
-- Este archivo se ejecuta solo contra Supabase local. No aprueba ni publica.

\set ON_ERROR_STOP on
\set lote_id '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'

begin;

create or replace function staging.promover_establecimientos_osm(
  p_lote_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  cantidad_validos integer;
  cantidad_observados integer;
  cantidad_promovidos integer;
  cercly_antes text;
  cercly_despues text;
  reclamados_antes text;
  reclamados_despues text;
begin
  perform pg_advisory_xact_lock(hashtext('cercly:promover-osm:' || p_lote_id));

  select count(*) into cantidad_validos
  from staging.importacion_establecimientos_osm
  where lote_id = p_lote_id
    and estado_importacion = 'valido';

  select count(*) into cantidad_observados
  from staging.importacion_establecimientos_osm
  where lote_id = p_lote_id
    and estado_importacion = 'observado';

  if cantidad_validos <> 254 or cantidad_observados <> 52 then
    raise exception
      'Lote inesperado: % validos y % observados; se esperaban 254 y 52',
      cantidad_validos,
      cantidad_observados;
  end if;

  if exists (
    select 1
    from staging.importacion_establecimientos_osm
    where lote_id = p_lote_id
      and estado_importacion = 'valido'
      and (
        nullif(btrim(nombre_original), '') is null
        or char_length(btrim(nombre_original)) not between 2 and 120
        or categoria_id_destino is null
        or subcategoria_id_destino is null
        or latitud not between -90 and 90
        or longitud not between -180 and 180
      )
  ) then
    raise exception 'El lote contiene registros validos incompletos';
  end if;

  if exists (
    select 1
    from staging.importacion_establecimientos_osm i
    join public.subcategorias s on s.id = i.subcategoria_id_destino
    where i.lote_id = p_lote_id
      and i.estado_importacion = 'valido'
      and (
        not s.activa
        or s.categoria_id <> i.categoria_id_destino
      )
  ) then
    raise exception 'Una subcategoria valida no pertenece a su categoria destino';
  end if;

  if exists (
    select 1
    from staging.importacion_establecimientos_osm
    where lote_id = p_lote_id
      and estado_importacion in ('observado', 'descartado')
      and establecimiento_id is not null
  ) then
    raise exception 'Un registro observado o descartado ya esta vinculado a establecimientos';
  end if;

  select md5(coalesce(string_agg(to_jsonb(e)::text, '' order by e.id), ''))
  into cercly_antes
  from public.establecimientos e
  where e.fuente = 'cercly';

  select md5(coalesce(string_agg(to_jsonb(e)::text, '' order by e.id), ''))
  into reclamados_antes
  from public.establecimientos e
  where e.fuente = 'osm'
    and (
      e.estado_reclamo <> 'no_reclamado'
      or e.propietario_id is not null
    );

  insert into public.establecimientos (
    propietario_id,
    categoria_id,
    nombre,
    descripcion,
    direccion,
    latitud,
    longitud,
    telefono_publico,
    zona_horaria,
    estado,
    fuente,
    osm_type,
    osm_id,
    datos_osm,
    estado_reclamo,
    publicable,
    ciudad,
    provincia,
    pais_codigo,
    reclamado_en,
    verificado_en,
    verificado_por
  )
  select
    null,
    i.categoria_id_destino,
    btrim(i.nombre_original),
    '',
    left(
      coalesce(
        nullif(btrim(i.datos_osm ->> 'addr:full'), ''),
        nullif(
          concat_ws(
            ', ',
            nullif(btrim(i.datos_osm ->> 'addr:street'), ''),
            nullif(btrim(i.datos_osm ->> 'addr:housenumber'), '')
          ),
          ''
        ),
        'Ubicacion registrada en OpenStreetMap'
      ),
      250
    ),
    i.latitud,
    i.longitud,
    '',
    'America/Guayaquil',
    'pendiente',
    'osm',
    i.osm_type,
    i.osm_id,
    coalesce(i.datos_osm, '{}'::jsonb),
    'no_reclamado',
    false,
    'Tulcán',
    'Carchi',
    'EC',
    null,
    null,
    null
  from staging.importacion_establecimientos_osm i
  where i.lote_id = p_lote_id
    and i.estado_importacion = 'valido'
    and nullif(btrim(i.nombre_original), '') is not null
  on conflict (osm_type, osm_id) where fuente = 'osm'
  do update set
    categoria_id = excluded.categoria_id,
    nombre = excluded.nombre,
    direccion = excluded.direccion,
    latitud = excluded.latitud,
    longitud = excluded.longitud,
    ciudad = excluded.ciudad,
    provincia = excluded.provincia,
    pais_codigo = excluded.pais_codigo
  where establecimientos.fuente = 'osm'
    and establecimientos.estado_reclamo = 'no_reclamado'
    and establecimientos.propietario_id is null;

  update public.establecimiento_categorias ec
  set es_principal = false
  from staging.importacion_establecimientos_osm i
  join public.establecimientos e
    on e.fuente = 'osm'
   and e.osm_type = i.osm_type
   and e.osm_id = i.osm_id
  where i.lote_id = p_lote_id
    and i.estado_importacion = 'valido'
    and e.estado_reclamo = 'no_reclamado'
    and e.propietario_id is null
    and ec.establecimiento_id = e.id
    and ec.es_principal
    and ec.subcategoria_id <> i.subcategoria_id_destino;

  insert into public.establecimiento_categorias (
    establecimiento_id,
    subcategoria_id,
    es_principal
  )
  select
    e.id,
    i.subcategoria_id_destino,
    true
  from staging.importacion_establecimientos_osm i
  join public.establecimientos e
    on e.fuente = 'osm'
   and e.osm_type = i.osm_type
   and e.osm_id = i.osm_id
  where i.lote_id = p_lote_id
    and i.estado_importacion = 'valido'
    and e.estado_reclamo = 'no_reclamado'
    and e.propietario_id is null
  on conflict (establecimiento_id, subcategoria_id) do update
  set es_principal = excluded.es_principal;

  update staging.importacion_establecimientos_osm i
  set establecimiento_id = e.id
  from public.establecimientos e
  where i.lote_id = p_lote_id
    and i.estado_importacion = 'valido'
    and e.fuente = 'osm'
    and e.osm_type = i.osm_type
    and e.osm_id = i.osm_id;

  select count(*) into cantidad_promovidos
  from staging.importacion_establecimientos_osm
  where lote_id = p_lote_id
    and estado_importacion = 'valido'
    and establecimiento_id is not null;

  if cantidad_promovidos <> 254 then
    raise exception 'Se vincularon % registros; se esperaban 254', cantidad_promovidos;
  end if;

  select md5(coalesce(string_agg(to_jsonb(e)::text, '' order by e.id), ''))
  into cercly_despues
  from public.establecimientos e
  where e.fuente = 'cercly';

  select md5(coalesce(string_agg(to_jsonb(e)::text, '' order by e.id), ''))
  into reclamados_despues
  from public.establecimientos e
  where e.fuente = 'osm'
    and (
      e.estado_reclamo <> 'no_reclamado'
      or e.propietario_id is not null
    );

  if cercly_antes is distinct from cercly_despues then
    raise exception 'La promocion modifico establecimientos creados en Cercly';
  end if;

  if reclamados_antes is distinct from reclamados_despues then
    raise exception 'La promocion modifico establecimientos OSM reclamados';
  end if;

  return cantidad_promovidos;
end;
$$;

revoke all on function staging.promover_establecimientos_osm(uuid) from public;
revoke all on function staging.promover_establecimientos_osm(uuid) from anon;
revoke all on function staging.promover_establecimientos_osm(uuid) from authenticated;

select staging.promover_establecimientos_osm(:'lote_id'::uuid) as promovidos;

commit;

select
  estado_importacion,
  count(*) as cantidad,
  count(establecimiento_id) as vinculados
from staging.importacion_establecimientos_osm
where lote_id = :'lote_id'::uuid
group by estado_importacion
order by estado_importacion;
