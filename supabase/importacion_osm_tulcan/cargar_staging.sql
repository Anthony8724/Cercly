-- Carga idempotente del lote OSM de Tulcan en staging.
-- Ejecutar desde la raiz del repositorio con psql contra Supabase local.
-- Este script no escribe en public.establecimientos.

\set ON_ERROR_STOP on

begin;

create temporary table importacion_osm_tulcan_raw (
  lote_id text,
  osm_type text,
  osm_id text,
  nombre_original text,
  categoria_preliminar text,
  etiqueta_osm text,
  latitud text,
  longitud text,
  datos_osm text,
  categoria_oficial text,
  categoria_slug_destino text,
  subcategoria_nombre text,
  subcategoria_slug_destino text,
  confianza_mapeo text,
  estado_importacion text,
  motivo_observacion text,
  publicable_propuesto text
) on commit drop;

\copy importacion_osm_tulcan_raw from 'supabase/seed/importacion_osm_tulcan.csv' with (format csv, header true, encoding 'UTF8')

do $$
declare
  cantidad integer;
begin
  select count(*) into cantidad from importacion_osm_tulcan_raw;
  if cantidad <> 306 then
    raise exception 'Se esperaban 306 registros y se recibieron %', cantidad;
  end if;

  if exists (
    select 1
    from importacion_osm_tulcan_raw
    group by lote_id, osm_type, osm_id
    having count(*) > 1
  ) then
    raise exception 'El CSV contiene identidades OSM duplicadas dentro del lote';
  end if;

  if exists (
    select 1
    from importacion_osm_tulcan_raw
    where lote_id is null
       or lote_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       or osm_type not in ('node', 'way', 'relation')
       or osm_id is null
       or osm_id !~ '^[0-9]+$'
       or osm_id::numeric <= 0
       or latitud is null
       or longitud is null
       or latitud::double precision not between -90 and 90
       or longitud::double precision not between -180 and 180
       or estado_importacion not in ('valido', 'observado')
  ) then
    raise exception 'El CSV contiene identidad, coordenadas o estados invalidos';
  end if;

  if exists (
    select 1
    from importacion_osm_tulcan_raw r
    left join public.categorias c
      on c.slug = r.categoria_slug_destino
     and c.activa
    where c.id is null
  ) then
    raise exception 'Existe una categoria destino inexistente o inactiva';
  end if;

  if exists (
    select 1
    from importacion_osm_tulcan_raw r
    join public.categorias c on c.slug = r.categoria_slug_destino
    left join public.subcategorias s
      on s.slug = nullif(r.subcategoria_slug_destino, '')
     and s.categoria_id = c.id
     and s.activa
    where nullif(r.subcategoria_slug_destino, '') is not null
      and s.id is null
  ) then
    raise exception 'Existe una subcategoria destino inexistente, inactiva o ajena a su categoria';
  end if;

  if (
    select count(*)
    from importacion_osm_tulcan_raw
    where nullif(btrim(nombre_original), '') is null
      and estado_importacion = 'observado'
      and motivo_observacion like 'Sin nombre%'
  ) <> 50 then
    raise exception 'Los 50 registros sin nombre no estan observados correctamente';
  end if;

  if exists (
    select 1
    from importacion_osm_tulcan_raw
    where nullif(btrim(nombre_original), '') is null
      and estado_importacion <> 'observado'
  ) then
    raise exception 'Un registro sin nombre fue marcado como valido';
  end if;
end;
$$;

insert into staging.importacion_establecimientos_osm (
  lote_id,
  osm_type,
  osm_id,
  nombre_original,
  categoria_preliminar,
  etiqueta_osm,
  latitud,
  longitud,
  datos_osm,
  categoria_id_destino,
  subcategoria_id_destino,
  estado_importacion,
  motivo_observacion
)
select
  r.lote_id::uuid,
  r.osm_type::public.tipo_objeto_osm,
  r.osm_id::bigint,
  nullif(btrim(r.nombre_original), ''),
  nullif(btrim(r.categoria_preliminar), ''),
  nullif(btrim(r.etiqueta_osm), ''),
  r.latitud::double precision,
  r.longitud::double precision,
  nullif(r.datos_osm, '')::jsonb,
  c.id,
  s.id,
  r.estado_importacion::public.estado_importacion_osm,
  nullif(btrim(r.motivo_observacion), '')
from importacion_osm_tulcan_raw r
join public.categorias c
  on c.slug = r.categoria_slug_destino
 and c.activa
left join public.subcategorias s
  on s.slug = nullif(r.subcategoria_slug_destino, '')
 and s.categoria_id = c.id
 and s.activa
on conflict (lote_id, osm_type, osm_id) do update
set
  nombre_original = excluded.nombre_original,
  categoria_preliminar = excluded.categoria_preliminar,
  etiqueta_osm = excluded.etiqueta_osm,
  latitud = excluded.latitud,
  longitud = excluded.longitud,
  datos_osm = excluded.datos_osm,
  categoria_id_destino = excluded.categoria_id_destino,
  subcategoria_id_destino = excluded.subcategoria_id_destino,
  estado_importacion = excluded.estado_importacion,
  motivo_observacion = excluded.motivo_observacion;

commit;

select
  lote_id,
  estado_importacion,
  count(*) as cantidad
from staging.importacion_establecimientos_osm
where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
group by lote_id, estado_importacion
order by estado_importacion;
