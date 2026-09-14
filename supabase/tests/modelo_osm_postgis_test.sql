-- Pruebas pgTAP del contrato creado por modelo_osm_postgis.
-- Supabase ejecuta este archivo con: supabase test db

begin;

select plan(18);

select is(
  (select count(*)::bigint from public.categorias where activa),
  12::bigint,
  'existen exactamente 12 categorias activas'
);

select set_eq(
  $$select slug from public.categorias where activa$$,
  $$values
    ('comida-bebidas'),
    ('tiendas-supermercados'),
    ('moda-accesorios'),
    ('belleza-cuidado-personal'),
    ('tecnologia-electronica'),
    ('automotriz-movilidad'),
    ('hogar-construccion'),
    ('salud-bienestar'),
    ('educacion-papeleria'),
    ('agropecuario-mascotas'),
    ('entretenimiento-deporte-turismo'),
    ('servicios-oficios')$$,
  'las categorias activas corresponden a la taxonomia oficial'
);

select is(
  (
    select count(*)::bigint
    from public.subcategorias
    where slug in (
      'peluquerias',
      'barberias',
      'salones-belleza',
      'cosmeticos',
      'lavanderias',
      'servicios-financieros',
      'costura-confeccion',
      'cerrajeria',
      'fotografia',
      'reparaciones',
      'limpieza',
      'otros-servicios-oficios'
    )
  ),
  12::bigint,
  'existen todas las subcategorias obligatorias'
);

select is_empty(
  $$
    select s.id
    from public.subcategorias s
    join public.categorias c on c.id = s.categoria_id
    where s.slug in (
      'peluquerias',
      'barberias',
      'salones-belleza',
      'cosmeticos',
      'lavanderias'
    )
      and c.slug <> 'belleza-cuidado-personal'
  $$,
  'las subcategorias de belleza estan correctamente clasificadas'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    left join staging.importacion_establecimientos_osm i
      on i.osm_type = e.osm_type
     and i.osm_id = e.osm_id
     and i.estado_importacion = 'valido'
    where e.fuente = 'osm'
      and i.id is null
  $$,
  'todo OSM presente procede de una fila valida de staging'
);

select is_empty(
  $$
    select id
    from public.establecimientos
    where fuente = 'cercly'
      and (
        estado_reclamo is not null
        or publicable <> (
          estado = 'aprobado'::public.estado_establecimiento
        )
      )
  $$,
  'los establecimientos existentes fueron adaptados de forma segura'
);

select is_empty(
  $$select id from public.establecimientos where ubicacion is null$$,
  'todos los establecimientos existentes tienen ubicacion geografica'
);

select is_empty(
  $$
    select e.id
    from public.establecimientos e
    left join public.establecimiento_categorias ec
      on ec.establecimiento_id = e.id
     and ec.es_principal
    where ec.establecimiento_id is null
  $$,
  'cada establecimiento existente conserva una subcategoria principal'
);

select has_table(
  'public',
  'subcategorias',
  'existe la tabla public.subcategorias'
);

select has_table(
  'public',
  'establecimiento_categorias',
  'existe la tabla public.establecimiento_categorias'
);

select has_table(
  'public',
  'evidencias_solicitud',
  'existe la tabla public.evidencias_solicitud'
);

select has_table(
  'staging',
  'importacion_establecimientos_osm',
  'existe la tabla interna de importacion OSM'
);

select has_function(
  'public',
  'buscar_establecimientos_cercanos',
  array[
    'double precision',
    'double precision',
    'integer',
    'uuid',
    'uuid[]',
    'boolean',
    'text',
    'integer',
    'integer'
  ],
  'existe la RPC de busqueda geografica'
);

select has_index(
  'public',
  'establecimientos',
  'establecimientos_ubicacion_gist_idx',
  'existe el indice GiST para consultas geograficas'
);

select has_index(
  'public',
  'establecimientos',
  'establecimientos_osm_identidad_unica_idx',
  'existe el indice unico de identidad OSM'
);

select ok(
  not has_schema_privilege('anon', 'staging', 'usage'),
  'anon no puede usar el esquema staging'
);

select ok(
  not has_schema_privilege('authenticated', 'staging', 'usage'),
  'authenticated no puede usar el esquema staging'
);

select ok(
  not has_table_privilege(
    'anon',
    'staging.importacion_establecimientos_osm',
    'select'
  )
  and not has_table_privilege(
    'authenticated',
    'staging.importacion_establecimientos_osm',
    'select'
  ),
  'anon y authenticated no pueden leer la tabla de importacion'
);

select * from finish();

rollback;
