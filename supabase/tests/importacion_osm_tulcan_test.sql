-- Pruebas pgTAP para el lote cargado en staging.
-- Requiere ejecutar primero cargar_staging.sql contra Supabase local.

begin;

select plan(12);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
  ),
  306::bigint,
  'el lote contiene exactamente 306 registros'
);

select is_empty(
  $$
    select osm_type, osm_id
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
    group by osm_type, osm_id
    having count(*) > 1
  $$,
  'no hay identidades OSM duplicadas dentro del lote'
);

select is_empty(
  $$
    select id
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and (
        latitud not between -90 and 90
        or longitud not between -180 and 180
      )
  $$,
  'todas las coordenadas estan dentro de rangos validos'
);

select is_empty(
  $$
    select i.id
    from staging.importacion_establecimientos_osm i
    left join public.categorias c on c.id = i.categoria_id_destino
    where i.lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and (c.id is null or not c.activa)
  $$,
  'todos los registros resuelven una categoria activa'
);

select is_empty(
  $$
    select i.id
    from staging.importacion_establecimientos_osm i
    join public.categorias c on c.id = i.categoria_id_destino
    join public.subcategorias s on s.id = i.subcategoria_id_destino
    where i.lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and (not s.activa or s.categoria_id <> c.id)
  $$,
  'las subcategorias resueltas pertenecen a su categoria y estan activas'
);

select is_empty(
  $$
    select id
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'valido'
      and subcategoria_id_destino is null
  $$,
  'todo registro valido tiene una subcategoria destino resuelta'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and nombre_original is null
      and estado_importacion = 'observado'
      and motivo_observacion like 'Sin nombre%'
  ),
  50::bigint,
  'los 50 registros sin nombre permanecen observados'
);

select is_empty(
  $$
    select id
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and nombre_original is null
      and estado_importacion <> 'observado'
  $$,
  'ningun registro sin nombre fue marcado como valido'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'valido'
  ),
  222::bigint,
  'el lote conserva 222 registros validos'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'observado'
  ),
  84::bigint,
  'el lote conserva 84 registros observados'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'descartado'
  ),
  0::bigint,
  'el lote no contiene registros descartados'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm'$$,
  'la carga staging no inserta establecimientos OSM publicos'
);

select * from finish();

rollback;
