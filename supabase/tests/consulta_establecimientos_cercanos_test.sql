-- Pruebas pgTAP del RPC PostGIS y del modo local de datos OSM.
-- Requiere staging, promocion y habilitacion local ejecutados previamente.

begin;

select plan(19);

select has_function(
  'public',
  'buscar_establecimientos_cercanos',
  array[
    'double precision', 'double precision', 'integer', 'uuid', 'uuid[]',
    'boolean', 'integer', 'integer'
  ],
  'existe el RPC PostGIS de establecimientos cercanos'
);

select has_function(
  'staging',
  'configurar_osm_pruebas_local',
  array['boolean', 'uuid'],
  'existe la funcion privada para configurar pruebas locales'
);

select is(
  (
    select count(*)::bigint
    from public.establecimientos
    where fuente = 'osm' and estado = 'aprobado' and publicable
  ),
  254::bigint,
  'el modo local habilita los 254 OSM validos'
);

select isnt_empty(
  $$
    select id
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 5000, null, null, false, 20, 0
    )
  $$,
  'el RPC devuelve establecimientos cercanos a Tulcan'
);

select is_empty(
  $$
    with resultados as (
      select
        distancia_metros,
        lag(distancia_metros) over () as distancia_anterior
      from public.buscar_establecimientos_cercanos(
        0.8116, -77.7172, 50000, null, null, false, 100, 0
      )
    )
    select distancia_metros
    from resultados
    where distancia_anterior > distancia_metros
  $$,
  'los resultados estan ordenados por distancia'
);

select is_empty(
  $$
    select id
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 1000, null, null, false, 100, 0
    )
    where distancia_metros > 1000
  $$,
  'el RPC respeta el radio solicitado'
);

select is_empty(
  $$
    with categoria as (
      select categoria_id
      from public.buscar_establecimientos_cercanos(
        0.8116, -77.7172, 50000, null, null, false, 1, 0
      )
    )
    select r.id
    from categoria c
    cross join lateral public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 50000, c.categoria_id, null, false, 100, 0
    ) r
    where r.categoria_id <> c.categoria_id
  $$,
  'el RPC respeta la categoria opcional'
);

select is_empty(
  $$
    with subcategoria as (
      select ec.subcategoria_id
      from public.establecimiento_categorias ec
      join public.establecimientos e on e.id = ec.establecimiento_id
      where e.fuente = 'osm' and e.publicable and ec.es_principal
      limit 1
    )
    select r.id
    from subcategoria s
    cross join lateral public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 50000, null, array[s.subcategoria_id], false, 100, 0
    ) r
    where not exists (
      select 1
      from public.establecimiento_categorias ec
      where ec.establecimiento_id = r.id
        and ec.subcategoria_id = s.subcategoria_id
    )
  $$,
  'el RPC respeta las subcategorias opcionales'
);

insert into public.promociones (
  establecimiento_id,
  titulo,
  descripcion,
  fecha_inicio,
  fecha_fin,
  radio_alerta_metros,
  activa
)
select
  id,
  'Promocion pgTAP',
  'Dato temporal de prueba',
  now() - interval '1 hour',
  now() + interval '1 hour',
  100,
  true
from public.establecimientos
where fuente = 'osm' and publicable
limit 1;

select is_empty(
  $$
    select id
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 50000, null, null, true, 100, 0
    )
    where not tiene_promociones
  $$,
  'el filtro de promociones solo devuelve promociones vigentes'
);

select ok(
  (
    select count(*) <= 3
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 50000, null, null, false, 3, 0
    )
  ),
  'el RPC respeta el limite'
);

select isnt(
  (
    select id
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 50000, null, null, false, 1, 0
    )
  ),
  (
    select id
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 50000, null, null, false, 1, 1
    )
  ),
  'el desplazamiento cambia la pagina de resultados'
);

select throws_ok(
  $$select * from public.buscar_establecimientos_cercanos(91, -77.7172)$$,
  'P0001',
  'La latitud debe estar entre -90 y 90',
  'una latitud invalida genera un error controlado'
);

select throws_ok(
  $$
    select *
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 0, null, null, false, 20, 0
    )
  $$,
  'P0001',
  'El radio debe estar entre 1 y 50000 metros',
  'un radio invalido genera un error controlado'
);

insert into public.establecimientos (
  categoria_id, nombre, direccion, latitud, longitud, estado, fuente,
  osm_type, osm_id, datos_osm, estado_reclamo, publicable, ciudad,
  provincia, pais_codigo
)
select
  id, 'Pendiente pgTAP', 'Tulcan', 0.8116, -77.7172, 'pendiente', 'osm',
  'node', 9223372036854775000, '{}'::jsonb, 'no_reclamado', false, 'Tulcán',
  'Carchi', 'EC'
from public.categorias
where activa
order by orden
limit 1;

select is_empty(
  $$
    select id
    from public.buscar_establecimientos_cercanos(
      0.8116, -77.7172, 100, null, null, false, 100, 0
    )
    where nombre = 'Pendiente pgTAP'
  $$,
  'las consultas publicas no muestran establecimientos pendientes'
);

create temporary table cercly_antes on commit drop as
select id, to_jsonb(e) as datos
from public.establecimientos e
where fuente = 'cercly';

create temporary table reclamados_antes on commit drop as
select id, to_jsonb(e) as datos
from public.establecimientos e
where fuente = 'osm'
  and (estado_reclamo <> 'no_reclamado' or propietario_id is not null);

select lives_ok(
  $$
    select staging.configurar_osm_pruebas_local(false);
    select staging.configurar_osm_pruebas_local(true)
  $$,
  'el modo local puede restaurarse y habilitarse nuevamente'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'establecimientos'
      and t.tgname = 'proteger_establecimiento_trigger'
      and not t.tgisinternal
      and t.tgenabled = 'O'
  ),
  'el trigger de proteccion queda habilitado despues del modo local'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'establecimientos'
      and t.tgname = 'establecimientos_actualizar_fecha'
      and not t.tgisinternal
      and t.tgenabled = 'O'
  ),
  'el trigger de fecha permanece habilitado durante el modo local'
);

select is_empty(
  $$
    select coalesce(a.id, d.id)
    from cercly_antes a
    full join (
      select id, to_jsonb(e) as datos
      from public.establecimientos e
      where fuente = 'cercly'
    ) d using (id)
    where a.datos is distinct from d.datos
  $$,
  'el modo local no modifica establecimientos Cercly'
);

select is_empty(
  $$
    select coalesce(a.id, d.id)
    from reclamados_antes a
    full join (
      select id, to_jsonb(e) as datos
      from public.establecimientos e
      where fuente = 'osm'
        and (estado_reclamo <> 'no_reclamado' or propietario_id is not null)
    ) d using (id)
    where a.datos is distinct from d.datos
  $$,
  'el modo local no modifica establecimientos OSM reclamados'
);

select * from finish();

rollback;
