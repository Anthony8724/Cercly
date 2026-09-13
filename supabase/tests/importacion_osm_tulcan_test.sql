-- Pruebas pgTAP para el lote cargado en staging.
-- Requiere ejecutar primero cargar_staging.sql contra Supabase local.

begin;

select plan(17);

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
  254::bigint,
  'el lote refinado contiene 254 registros validos'
);

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and estado_importacion = 'observado'
  ),
  52::bigint,
  'el lote refinado contiene 52 registros observados'
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

select is(
  (
    select count(*)::bigint
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and nombre_original is not null
      and estado_importacion = 'observado'
  ),
  2::bigint,
  'solo dos registros con nombre permanecen observados'
);

select set_eq(
  $$
    select etiqueta_osm || '|' || nombre_original
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and nombre_original is not null
      and estado_importacion = 'observado'
  $$,
  $$values
    ('outdoor|EMELNORTE'),
    ('butcher|Centro de Faenamiento de Tulcán')
  $$,
  'EMELNORTE y el centro de faenamiento requieren revision manual'
);

select is_empty(
  $$
    select id
    from staging.importacion_establecimientos_osm
    where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and nombre_original is not null
      and estado_importacion <> 'valido'
      and (etiqueta_osm, nombre_original) not in (
        ('outdoor', 'EMELNORTE'),
        ('butcher', 'Centro de Faenamiento de Tulcán')
      )
  $$,
  'los otros 32 registros observados con nombre pasan a validos'
);

select is_empty(
  $$
    with esperado(etiqueta, categoria_slug, subcategoria_slug) as (
      values
        ('telecommunication', 'tecnologia-electronica', 'telefonia-movil'),
        ('beverages', 'comida-bebidas', 'bares-bebidas'),
        ('confectionery', 'comida-bebidas', 'heladerias-postres'),
        ('department_store', 'tiendas-supermercados', 'centros-comerciales-grandes-almacenes'),
        ('mall', 'tiendas-supermercados', 'centros-comerciales-grandes-almacenes'),
        ('toys', 'educacion-papeleria', 'jugueterias'),
        ('appliance', 'tecnologia-electronica', 'electronica'),
        ('general', 'tiendas-supermercados', 'tiendas-barrio'),
        ('florist', 'tiendas-supermercados', 'floristerias'),
        ('internet_cafe', 'tecnologia-electronica', 'computacion'),
        ('metal_construction', 'hogar-construccion', 'materiales-construccion'),
        ('shoemaker', 'servicios-oficios', 'reparaciones')
    )
    select i.id
    from staging.importacion_establecimientos_osm i
    join esperado e on e.etiqueta = i.etiqueta_osm
    left join public.categorias c on c.id = i.categoria_id_destino
    left join public.subcategorias s on s.id = i.subcategoria_id_destino
    where i.lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
      and (
        c.slug is distinct from e.categoria_slug
        or s.slug is distinct from e.subcategoria_slug
      )
  $$,
  'las etiquetas refinadas resuelven los slugs aprobados'
);

select is_empty(
  $$
    with esperado(nombre, categoria_slug, subcategoria_slug) as (
      values
        ('Cevicheria Cuatro Ases', 'comida-bebidas', 'restaurantes'),
        ('Authesa', 'automotriz-movilidad', 'venta-vehiculos'),
        ('SuperExpress', 'tiendas-supermercados', 'minimarkets')
    )
    select e.nombre
    from esperado e
    left join staging.importacion_establecimientos_osm i
      on i.lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
     and i.nombre_original = e.nombre
    left join public.categorias c on c.id = i.categoria_id_destino
    left join public.subcategorias s on s.id = i.subcategoria_id_destino
    where i.id is null
       or c.slug is distinct from e.categoria_slug
       or s.slug is distinct from e.subcategoria_slug
       or i.estado_importacion <> 'valido'
  $$,
  'los casos especiales resuelven su clasificacion aprobada'
);

select * from finish();

rollback;
