-- Pruebas pgTAP de la promocion local OSM.
-- Requiere cargar staging y ejecutar promover_establecimientos.sql primero.

begin;

select plan(28);

select has_function(
  'staging',
  'promover_establecimientos_osm',
  array['uuid'],
  'existe la funcion interna de promocion local'
);

select is(
  (select count(*)::bigint from public.establecimientos where fuente = 'osm'),
  254::bigint,
  'se promovieron exactamente 254 establecimientos OSM'
);

select is_empty(
  $$
    select i.id
    from staging.importacion_establecimientos_osm i
    join public.establecimientos e
      on e.fuente = 'osm'
     and e.osm_type = i.osm_type
     and e.osm_id = i.osm_id
    where i.lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and i.estado_importacion = 'observado'
  $$,
  'ninguno de los 52 observados fue promovido'
);

select is_empty(
  $$select id from public.establecimientos where fuente <> 'osm' and osm_id is not null$$,
  'ningun establecimiento ajeno a OSM recibio identidad OSM'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and propietario_id is not null$$,
  'todos los OSM promovidos carecen de propietario'
);

select is_empty(
  $$
    select id from public.establecimientos
    where fuente = 'osm' and estado_reclamo <> 'no_reclamado'
  $$,
  'todos los OSM promovidos quedan no reclamados'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and estado <> 'pendiente'$$,
  'todos los OSM promovidos quedan pendientes'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and publicable$$,
  'todos los OSM promovidos quedan no publicables'
);

select is_empty(
  $$
    select id from public.establecimientos
    where fuente = 'osm' and (osm_type is null or osm_id is null)
  $$,
  'todos los OSM promovidos conservan su identidad completa'
);

select is_empty(
  $$
    select osm_type, osm_id
    from public.establecimientos
    where fuente = 'osm'
    group by osm_type, osm_id
    having count(*) > 1
  $$,
  'no existen identidades OSM duplicadas'
);

select is_empty(
  $$
    select id from public.establecimientos
    where fuente = 'osm'
      and (latitud not between -90 and 90 or longitud not between -180 and 180)
  $$,
  'todas las coordenadas promovidas son validas'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    join staging.importacion_establecimientos_osm i
      on i.establecimiento_id = e.id
    where i.lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and (e.latitud <> i.latitud or e.longitud <> i.longitud)
  $$,
  'las coordenadas coinciden con staging'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    join staging.importacion_establecimientos_osm i
      on i.establecimiento_id = e.id
    where e.datos_osm is distinct from coalesce(i.datos_osm, '{}'::jsonb)
  $$,
  'los datos OSM originales quedan preservados'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and ubicacion is null$$,
  'todos los OSM promovidos tienen ubicacion PostGIS'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    join staging.importacion_establecimientos_osm i on i.establecimiento_id = e.id
    where e.fuente = 'osm' and e.categoria_id <> i.categoria_id_destino
  $$,
  'cada establecimiento usa la categoria destino de staging'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    left join public.establecimiento_categorias ec
      on ec.establecimiento_id = e.id and ec.es_principal
    left join public.subcategorias s
      on s.id = ec.subcategoria_id and s.activa
    where e.fuente = 'osm' and s.id is null
  $$,
  'cada OSM tiene una subcategoria principal activa'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    join staging.importacion_establecimientos_osm i on i.establecimiento_id = e.id
    join public.establecimiento_categorias ec
      on ec.establecimiento_id = e.id and ec.es_principal
    join public.subcategorias s on s.id = ec.subcategoria_id
    where e.fuente = 'osm'
      and (
        ec.subcategoria_id <> i.subcategoria_id_destino
        or s.categoria_id <> e.categoria_id
      )
  $$,
  'la subcategoria principal coincide con staging y su categoria'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and ciudad <> 'Tulcán'$$,
  'todos los OSM promovidos pertenecen a Tulcan'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and provincia <> 'Carchi'$$,
  'todos los OSM promovidos pertenecen a Carchi'
);

select is_empty(
  $$select id from public.establecimientos where fuente = 'osm' and pais_codigo <> 'EC'$$,
  'todos los OSM promovidos pertenecen a Ecuador'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'observado'
      and establecimiento_id is null
  ),
  52::bigint,
  'los 52 observados permanecen sin vinculo en staging'
);

create temporary table prueba_cercly_antes on commit drop as
select id, to_jsonb(e) as datos
from public.establecimientos e
where fuente = 'cercly';

create temporary table prueba_total_osm_antes on commit drop as
select count(*)::bigint as cantidad
from public.establecimientos
where fuente = 'osm';

select lives_ok(
  $$
    select staging.promover_establecimientos_osm(
      '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
    )
  $$,
  'volver a ejecutar la promocion no produce errores'
);

select is(
  (select count(*)::bigint from public.establecimientos where fuente = 'osm'),
  (select cantidad from prueba_total_osm_antes),
  'volver a ejecutar la promocion no aumenta el total'
);

select is_empty(
  $$
    select coalesce(a.id, d.id)
    from prueba_cercly_antes a
    full join (
      select id, to_jsonb(e) as datos
      from public.establecimientos e
      where fuente = 'cercly'
    ) d using (id)
    where a.datos is distinct from d.datos
  $$,
  'los establecimientos Cercly no fueron modificados'
);

select is_empty(
  $$
    select id from public.establecimientos
    where fuente = 'osm' and (estado = 'aprobado' or publicable)
  $$,
  'ningun OSM fue aprobado o publicado automaticamente'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'valido'
      and establecimiento_id is not null
  ),
  254::bigint,
  'los 254 validos quedan vinculados a su establecimiento'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'valido'
  ),
  254::bigint,
  'la promocion conserva el estado valido en staging'
);

select is_empty(
  $$
    select id from public.establecimientos
    where fuente = 'osm'
      and (
        reclamado_en is not null
        or verificado_en is not null
        or verificado_por is not null
      )
  $$,
  'la promocion no completa campos administrativos de reclamo'
);

select * from finish();

rollback;
