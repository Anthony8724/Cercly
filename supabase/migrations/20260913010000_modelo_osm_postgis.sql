-- Modelo territorial, taxonomia y procedencia de establecimientos.
-- Esta migracion no importa datos de OpenStreetMap.

begin;

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create type public.fuente_establecimiento as enum (
  'osm',
  'cercly'
);

create type public.tipo_objeto_osm as enum (
  'node',
  'way',
  'relation'
);

create type public.estado_reclamo_establecimiento as enum (
  'no_reclamado',
  'reclamado',
  'verificado'
);

create type public.estado_importacion_osm as enum (
  'pendiente',
  'valido',
  'observado',
  'importado',
  'descartado'
);

create table public.subcategorias (
  id uuid primary key default gen_random_uuid(),
  categoria_id uuid not null
    references public.categorias(id) on delete restrict,
  nombre varchar(100) not null,
  slug varchar(100) not null unique,
  icono varchar(50) not null default 'category',
  activa boolean not null default true,
  orden integer not null default 0,
  creado_en timestamp with time zone not null default now(),
  actualizado_en timestamp with time zone not null default now(),

  constraint subcategorias_nombre_check
    check (char_length(trim(nombre)) between 2 and 100),
  constraint subcategorias_slug_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint subcategorias_orden_check
    check (orden >= 0)
);

create table public.establecimiento_categorias (
  establecimiento_id uuid not null
    references public.establecimientos(id) on delete cascade,
  subcategoria_id uuid not null
    references public.subcategorias(id) on delete restrict,
  es_principal boolean not null default false,
  creado_en timestamp with time zone not null default now(),

  constraint establecimiento_categorias_pkey
    primary key (establecimiento_id, subcategoria_id)
);

create table public.evidencias_solicitud (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null
    references public.solicitudes_establecimientos(id) on delete cascade,
  ruta_storage text not null,
  tipo_evidencia varchar(40) not null,
  descripcion varchar(250),
  creado_en timestamp with time zone not null default now(),

  constraint evidencias_solicitud_ruta_check
    check (char_length(trim(ruta_storage)) > 0),
  constraint evidencias_solicitud_tipo_check
    check (
      tipo_evidencia in (
        'documento',
        'fotografia',
        'factura',
        'permiso',
        'otro'
      )
    ),
  constraint evidencias_solicitud_descripcion_check
    check (
      descripcion is null
      or char_length(trim(descripcion)) between 1 and 250
    ),
  constraint evidencias_solicitud_ruta_key
    unique (solicitud_id, ruta_storage)
);

create schema if not exists staging;

revoke all on schema staging from public;
revoke all on schema staging from anon;
revoke all on schema staging from authenticated;

create table staging.importacion_establecimientos_osm (
  id bigint generated always as identity primary key,
  lote_id uuid not null,
  osm_type public.tipo_objeto_osm not null,
  osm_id bigint not null,
  nombre_original text,
  categoria_preliminar text,
  etiqueta_osm text,
  latitud double precision not null,
  longitud double precision not null,
  datos_osm jsonb,
  categoria_id_destino uuid
    references public.categorias(id) on delete set null,
  subcategoria_id_destino uuid
    references public.subcategorias(id) on delete set null,
  estado_importacion public.estado_importacion_osm
    not null default 'pendiente',
  motivo_observacion text,
  establecimiento_id uuid
    references public.establecimientos(id) on delete set null,
  creado_en timestamp with time zone not null default now(),

  constraint importacion_osm_latitud_check
    check (latitud between -90 and 90),
  constraint importacion_osm_longitud_check
    check (longitud between -180 and 180),
  constraint importacion_osm_identidad_key
    unique (lote_id, osm_type, osm_id)
);

revoke all on all tables in schema staging from public;
revoke all on all tables in schema staging from anon;
revoke all on all tables in schema staging from authenticated;
revoke all on all sequences in schema staging from public;
revoke all on all sequences in schema staging from anon;
revoke all on all sequences in schema staging from authenticated;

alter default privileges in schema staging
  revoke all on tables from public;
alter default privileges in schema staging
  revoke all on tables from anon;
alter default privileges in schema staging
  revoke all on tables from authenticated;
alter default privileges in schema staging
  revoke all on sequences from public;
alter default privileges in schema staging
  revoke all on sequences from anon;
alter default privileges in schema staging
  revoke all on sequences from authenticated;

alter table public.establecimientos
  alter column propietario_id drop not null,
  add column fuente public.fuente_establecimiento
    not null default 'cercly',
  add column osm_type public.tipo_objeto_osm,
  add column osm_id bigint,
  add column datos_osm jsonb,
  add column estado_reclamo public.estado_reclamo_establecimiento,
  add column publicable boolean not null default false,
  add column ciudad varchar(100),
  add column provincia varchar(100),
  add column pais_codigo char(2),
  add column reclamado_en timestamp with time zone,
  add column verificado_en timestamp with time zone,
  add column verificado_por uuid
    references public.usuarios(id) on delete set null;

alter table public.solicitudes_establecimientos
  add column nombre_propuesto varchar(120),
  add column datos_propuestos jsonb,
  add column revisado_por uuid
    references public.usuarios(id) on delete set null,
  add column revisado_en timestamp with time zone;

-- Los datos ya existentes fueron creados en Cercly. No reciben estado de
-- reclamo, porque ese estado se reserva para fuentes externas.
update public.establecimientos
set
  fuente = 'cercly',
  estado_reclamo = null,
  publicable = (estado = 'aprobado'::public.estado_establecimiento);

-- Conservar la clasificacion anterior durante el remapeo. Esta tabla es
-- temporal y desaparece al finalizar la transaccion.
create temporary table establecimientos_categoria_legacy
on commit drop
as
select
  e.id as establecimiento_id,
  c.slug as categoria_slug
from public.establecimientos e
join public.categorias c on c.id = e.categoria_id;

-- Reutilizar IDs de categorias antiguas cuando es seguro evita romper
-- referencias existentes. Cafeteria y Minimarket quedan como filas legado
-- inactivas despues de remapear sus establecimientos.
update public.categorias
set
  nombre = 'Comida y bebidas',
  slug = 'comida-bebidas',
  icono = 'restaurant',
  activa = true,
  orden = 1
where slug = 'restaurantes';

update public.categorias
set
  nombre = 'Tiendas y supermercados',
  slug = 'tiendas-supermercados',
  icono = 'storefront',
  activa = true,
  orden = 2
where slug = 'tiendas';

update public.categorias
set
  nombre = 'Servicios y oficios',
  slug = 'servicios-oficios',
  icono = 'handyman',
  activa = true,
  orden = 12
where slug = 'otros';

insert into public.categorias (nombre, slug, icono, activa, orden)
values
  ('Moda y accesorios', 'moda-accesorios', 'checkroom', true, 3),
  (
    'Belleza y cuidado personal',
    'belleza-cuidado-personal',
    'content_cut',
    true,
    4
  ),
  (
    'Tecnología y electrónica',
    'tecnologia-electronica',
    'devices',
    true,
    5
  ),
  (
    'Automotriz y movilidad',
    'automotriz-movilidad',
    'directions_car',
    true,
    6
  ),
  (
    'Hogar y construcción',
    'hogar-construccion',
    'construction',
    true,
    7
  ),
  (
    'Salud y bienestar',
    'salud-bienestar',
    'health_and_safety',
    true,
    8
  ),
  (
    'Educación y papelería',
    'educacion-papeleria',
    'school',
    true,
    9
  ),
  (
    'Agropecuario y mascotas',
    'agropecuario-mascotas',
    'pets',
    true,
    10
  ),
  (
    'Entretenimiento, deporte y turismo',
    'entretenimiento-deporte-turismo',
    'attractions',
    true,
    11
  )
on conflict (slug) do update
set
  nombre = excluded.nombre,
  icono = excluded.icono,
  activa = excluded.activa,
  orden = excluded.orden;

update public.establecimientos e
set categoria_id = destino.id
from public.categorias origen, public.categorias destino
where e.categoria_id = origen.id
  and origen.slug = 'cafeterias'
  and destino.slug = 'comida-bebidas';

update public.establecimientos e
set categoria_id = destino.id
from public.categorias origen, public.categorias destino
where e.categoria_id = origen.id
  and origen.slug = 'minimarkets'
  and destino.slug = 'tiendas-supermercados';

update public.categorias
set activa = false, orden = 90
where slug = 'cafeterias';

update public.categorias
set activa = false, orden = 91
where slug = 'minimarkets';

insert into public.subcategorias (
  categoria_id,
  nombre,
  slug,
  icono,
  activa,
  orden
)
select c.id, s.nombre, s.slug, s.icono, true, s.orden
from (
  values
    ('comida-bebidas', 'Restaurantes', 'restaurantes', 'restaurant', 1),
    ('comida-bebidas', 'Cafeterías', 'cafeterias', 'local_cafe', 2),
    ('comida-bebidas', 'Panaderías', 'panaderias', 'bakery_dining', 3),
    ('comida-bebidas', 'Comida rápida', 'comida-rapida', 'fastfood', 4),
    ('comida-bebidas', 'Heladerías y postres', 'heladerias-postres', 'icecream', 5),
    ('comida-bebidas', 'Bares y bebidas', 'bares-bebidas', 'local_bar', 6),

    ('tiendas-supermercados', 'Supermercados', 'supermercados', 'shopping_cart', 1),
    ('tiendas-supermercados', 'Minimarkets', 'minimarkets', 'shopping_basket', 2),
    ('tiendas-supermercados', 'Tiendas de barrio', 'tiendas-barrio', 'store', 3),
    ('tiendas-supermercados', 'Mayoristas', 'mayoristas', 'warehouse', 4),

    ('moda-accesorios', 'Ropa', 'ropa', 'checkroom', 1),
    ('moda-accesorios', 'Calzado', 'calzado', 'steps', 2),
    ('moda-accesorios', 'Joyería y accesorios', 'joyeria-accesorios', 'diamond', 3),

    ('belleza-cuidado-personal', 'Peluquerías', 'peluquerias', 'content_cut', 1),
    ('belleza-cuidado-personal', 'Barberías', 'barberias', 'content_cut', 2),
    ('belleza-cuidado-personal', 'Salones de belleza', 'salones-belleza', 'spa', 3),
    ('belleza-cuidado-personal', 'Cosméticos', 'cosmeticos', 'face', 4),
    ('belleza-cuidado-personal', 'Lavanderías', 'lavanderias', 'local_laundry_service', 5),

    ('tecnologia-electronica', 'Telefonía móvil', 'telefonia-movil', 'smartphone', 1),
    ('tecnologia-electronica', 'Computación', 'computacion', 'computer', 2),
    ('tecnologia-electronica', 'Electrónica', 'electronica', 'devices_other', 3),
    ('tecnologia-electronica', 'Reparación electrónica', 'reparacion-electronica', 'build', 4),

    ('automotriz-movilidad', 'Talleres automotrices', 'talleres-automotrices', 'car_repair', 1),
    ('automotriz-movilidad', 'Repuestos', 'repuestos-automotrices', 'settings', 2),
    ('automotriz-movilidad', 'Lavadoras de vehículos', 'lavado-vehiculos', 'local_car_wash', 3),
    ('automotriz-movilidad', 'Transporte y movilidad', 'transporte-movilidad', 'directions_bus', 4),

    ('hogar-construccion', 'Ferreterías', 'ferreterias', 'hardware', 1),
    ('hogar-construccion', 'Materiales de construcción', 'materiales-construccion', 'foundation', 2),
    ('hogar-construccion', 'Muebles y decoración', 'muebles-decoracion', 'chair', 3),
    ('hogar-construccion', 'Servicios para el hogar', 'servicios-hogar', 'home_repair_service', 4),

    ('salud-bienestar', 'Farmacias', 'farmacias', 'local_pharmacy', 1),
    ('salud-bienestar', 'Clínicas y consultorios', 'clinicas-consultorios', 'medical_services', 2),
    ('salud-bienestar', 'Laboratorios', 'laboratorios', 'biotech', 3),
    ('salud-bienestar', 'Ópticas', 'opticas', 'visibility', 4),
    ('salud-bienestar', 'Bienestar y terapias', 'bienestar-terapias', 'self_improvement', 5),

    ('educacion-papeleria', 'Instituciones educativas', 'instituciones-educativas', 'school', 1),
    ('educacion-papeleria', 'Papelerías', 'papelerias', 'edit_note', 2),
    ('educacion-papeleria', 'Librerías', 'librerias', 'menu_book', 3),
    ('educacion-papeleria', 'Regalos', 'regalos', 'redeem', 4),

    ('agropecuario-mascotas', 'Insumos agropecuarios', 'insumos-agropecuarios', 'agriculture', 1),
    ('agropecuario-mascotas', 'Veterinarias', 'veterinarias', 'pets', 2),
    ('agropecuario-mascotas', 'Tiendas para mascotas', 'tiendas-mascotas', 'cruelty_free', 3),

    ('entretenimiento-deporte-turismo', 'Deportes', 'deportes', 'sports_soccer', 1),
    ('entretenimiento-deporte-turismo', 'Entretenimiento', 'entretenimiento', 'theaters', 2),
    ('entretenimiento-deporte-turismo', 'Turismo y viajes', 'turismo-viajes', 'travel_explore', 3),
    ('entretenimiento-deporte-turismo', 'Alojamiento', 'alojamiento', 'hotel', 4),

    ('servicios-oficios', 'Servicios financieros', 'servicios-financieros', 'account_balance', 1),
    ('servicios-oficios', 'Costura y confección', 'costura-confeccion', 'design_services', 2),
    ('servicios-oficios', 'Cerrajería', 'cerrajeria', 'key', 3),
    ('servicios-oficios', 'Fotografía', 'fotografia', 'photo_camera', 4),
    ('servicios-oficios', 'Reparaciones', 'reparaciones', 'handyman', 5),
    ('servicios-oficios', 'Limpieza', 'limpieza', 'cleaning_services', 6),
    ('servicios-oficios', 'Otros servicios y oficios', 'otros-servicios-oficios', 'miscellaneous_services', 7)
) as s(categoria_slug, nombre, slug, icono, orden)
join public.categorias c on c.slug = s.categoria_slug
on conflict (slug) do update
set
  categoria_id = excluded.categoria_id,
  nombre = excluded.nombre,
  icono = excluded.icono,
  activa = excluded.activa,
  orden = excluded.orden;

-- Adaptar registros existentes a la nueva relacion sin cambiar su categoria
-- principal compatible.
insert into public.establecimiento_categorias (
  establecimiento_id,
  subcategoria_id,
  es_principal
)
select
  e.id,
  s.id,
  true
from public.establecimientos e
join establecimientos_categoria_legacy l
  on l.establecimiento_id = e.id
join public.subcategorias s on s.slug = case l.categoria_slug
  when 'restaurantes' then 'restaurantes'
  when 'cafeterias' then 'cafeterias'
  when 'tiendas' then 'tiendas-barrio'
  when 'minimarkets' then 'minimarkets'
  when 'otros' then 'otros-servicios-oficios'
end
where l.categoria_slug in (
  'restaurantes',
  'cafeterias',
  'tiendas',
  'minimarkets',
  'otros'
)
on conflict (establecimiento_id, subcategoria_id) do update
set es_principal = excluded.es_principal;

alter table public.establecimientos
  add constraint establecimientos_fuente_identidad_check
  check (
    (
      fuente = 'osm'
      and osm_type is not null
      and osm_id is not null
      and estado_reclamo is not null
    )
    or
    (
      fuente = 'cercly'
      and propietario_id is not null
      and osm_type is null
      and osm_id is null
      and datos_osm is null
      and estado_reclamo is null
      and reclamado_en is null
    )
  ),
  add constraint establecimientos_reclamo_propietario_check
  check (
    fuente <> 'osm'
    or (
      estado_reclamo = 'no_reclamado'
      and propietario_id is null
      and reclamado_en is null
      and verificado_en is null
      and verificado_por is null
    )
    or (
      estado_reclamo = 'reclamado'
      and propietario_id is not null
      and reclamado_en is not null
      and verificado_en is null
      and verificado_por is null
    )
    or (
      estado_reclamo = 'verificado'
      and propietario_id is not null
      and reclamado_en is not null
      and verificado_en is not null
      and verificado_por is not null
    )
  ),
  add constraint establecimientos_publicable_check
  check (
    not publicable
    or (
      estado = 'aprobado'::public.estado_establecimiento
      and char_length(trim(nombre)) >= 2
    )
  ),
  add constraint establecimientos_ciudad_check
  check (
    ciudad is null
    or char_length(trim(ciudad)) between 2 and 100
  ),
  add constraint establecimientos_provincia_check
  check (
    provincia is null
    or char_length(trim(provincia)) between 2 and 100
  ),
  add constraint establecimientos_pais_codigo_check
  check (
    pais_codigo is null
    or pais_codigo ~ '^[A-Z]{2}$'
  ),
  add constraint establecimientos_datos_osm_objeto_check
  check (
    datos_osm is null
    or jsonb_typeof(datos_osm) = 'object'
  );

create unique index establecimientos_osm_identidad_unica_idx
  on public.establecimientos(osm_type, osm_id)
  where fuente = 'osm';

create unique index establecimiento_categoria_principal_unica_idx
  on public.establecimiento_categorias(establecimiento_id)
  where es_principal;

create index subcategorias_categoria_activa_orden_idx
  on public.subcategorias(categoria_id, activa, orden);

create index establecimiento_categorias_subcategoria_idx
  on public.establecimiento_categorias(subcategoria_id);

create index establecimientos_publicos_categoria_idx
  on public.establecimientos(categoria_id, estado, publicable);

create index establecimientos_territorio_idx
  on public.establecimientos(pais_codigo, provincia, ciudad);

create index solicitudes_tipo_estado_idx
  on public.solicitudes_establecimientos(tipo, estado);

create index solicitudes_revisado_por_idx
  on public.solicitudes_establecimientos(revisado_por)
  where revisado_por is not null;

create index evidencias_solicitud_solicitud_idx
  on public.evidencias_solicitud(solicitud_id);

create index importacion_osm_lote_estado_idx
  on staging.importacion_establecimientos_osm(lote_id, estado_importacion);

alter table public.establecimientos
  add column ubicacion extensions.geography(Point, 4326)
  generated always as (
    extensions.st_setsrid(
      extensions.st_makepoint(longitud, latitud),
      4326
    )::extensions.geography
  ) stored;

create index establecimientos_ubicacion_gist_idx
  on public.establecimientos using gist (ubicacion);

create trigger subcategorias_actualizar_fecha
  before update on public.subcategorias
  for each row
  execute function public.actualizar_fecha_modificacion();

create or replace function public.sincronizar_categoria_principal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  categoria_principal uuid;
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  if new.es_principal then
    select s.categoria_id
    into categoria_principal
    from public.subcategorias s
    where s.id = new.subcategoria_id;

    update public.establecimientos
    set categoria_id = categoria_principal
    where id = new.establecimiento_id
      and categoria_id is distinct from categoria_principal;
  end if;

  return new;
end;
$$;

create trigger sincronizar_categoria_principal_trigger
  after insert or update of subcategoria_id, es_principal
  on public.establecimiento_categorias
  for each row
  execute function public.sincronizar_categoria_principal();

create or replace function public.proteger_establecimiento()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not public.es_administrador() then
    if new.propietario_id is distinct from old.propietario_id then
      raise exception 'No puedes cambiar el propietario';
    end if;

    if new.estado is distinct from old.estado then
      raise exception 'Solo un administrador puede cambiar el estado';
    end if;

    if new.publicable is distinct from old.publicable then
      raise exception 'Solo un administrador puede publicar un establecimiento';
    end if;

    if new.fuente is distinct from old.fuente
       or new.osm_type is distinct from old.osm_type
       or new.osm_id is distinct from old.osm_id
       or new.datos_osm is distinct from old.datos_osm then
      raise exception 'No puedes cambiar la procedencia del establecimiento';
    end if;

    if new.estado_reclamo is distinct from old.estado_reclamo
       or new.reclamado_en is distinct from old.reclamado_en
       or new.verificado_en is distinct from old.verificado_en
       or new.verificado_por is distinct from old.verificado_por then
      raise exception 'Solo un administrador puede gestionar el reclamo';
    end if;

    if new.creado_en is distinct from old.creado_en then
      raise exception 'No puedes cambiar la fecha de creación';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.validar_solicitud_establecimiento()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  establecimiento public.establecimientos%rowtype;
begin
  select *
  into establecimiento
  from public.establecimientos
  where id = new.establecimiento_id;

  if not found then
    raise exception 'El establecimiento no existe';
  end if;

  if new.tipo = 'reclamar' then
    if establecimiento.fuente <> 'osm'
       or establecimiento.estado_reclamo <> 'no_reclamado'
       or establecimiento.propietario_id is not null then
      raise exception 'El establecimiento no está disponible para reclamo';
    end if;
  elsif new.tipo = 'acceso' then
    if establecimiento.propietario_id is null then
      raise exception 'El establecimiento todavía no tiene administrador';
    end if;
  elsif new.tipo = 'correccion' then
    if new.datos_propuestos is null
       or jsonb_typeof(new.datos_propuestos) <> 'object'
       or new.datos_propuestos = '{}'::jsonb then
      raise exception 'Debes indicar los datos que deseas corregir';
    end if;
  end if;

  return new;
end;
$$;

create trigger validar_solicitud_establecimiento_trigger
  before insert or update of establecimiento_id, tipo, datos_propuestos
  on public.solicitudes_establecimientos
  for each row
  execute function public.validar_solicitud_establecimiento();

create or replace function public.buscar_establecimientos_cercanos(
  p_latitud double precision,
  p_longitud double precision,
  p_radio_metros integer default 5000,
  p_categoria_id uuid default null,
  p_subcategoria_ids uuid[] default null,
  p_solo_promociones boolean default false,
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
  order by extensions.st_distance(e.ubicacion, punto_usuario), e.nombre
  limit p_limite
  offset p_desplazamiento;
end;
$$;

alter table public.subcategorias enable row level security;
alter table public.establecimiento_categorias enable row level security;
alter table public.evidencias_solicitud enable row level security;
alter table staging.importacion_establecimientos_osm enable row level security;

create policy "publico lee subcategorias activas"
on public.subcategorias
for select
to anon, authenticated
using (activa or public.es_administrador());

create policy "administrador gestiona subcategorias"
on public.subcategorias
for all
to authenticated
using (public.es_administrador())
with check (public.es_administrador());

create policy "lectura de categorias de establecimientos visibles"
on public.establecimiento_categorias
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.establecimientos e
    where e.id = establecimiento_categorias.establecimiento_id
      and (
        (e.estado = 'aprobado'::public.estado_establecimiento and e.publicable)
        or e.propietario_id = auth.uid()
        or public.es_administrador()
        or exists (
          select 1
          from public.miembros_establecimiento m
          where m.establecimiento_id = e.id
            and m.usuario_id = auth.uid()
            and m.activo
        )
      )
  )
);

create policy "responsable gestiona categorias del establecimiento"
on public.establecimiento_categorias
for all
to authenticated
using (
  exists (
    select 1
    from public.establecimientos e
    where e.id = establecimiento_categorias.establecimiento_id
      and (
        e.propietario_id = auth.uid()
        or public.es_administrador()
        or exists (
          select 1
          from public.miembros_establecimiento m
          where m.establecimiento_id = e.id
            and m.usuario_id = auth.uid()
            and m.activo
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.establecimientos e
    where e.id = establecimiento_categorias.establecimiento_id
      and (
        e.propietario_id = auth.uid()
        or public.es_administrador()
        or exists (
          select 1
          from public.miembros_establecimiento m
          where m.establecimiento_id = e.id
            and m.usuario_id = auth.uid()
            and m.activo
        )
      )
  )
);

create policy "solicitante lee sus evidencias"
on public.evidencias_solicitud
for select
to authenticated
using (
  public.es_administrador()
  or exists (
    select 1
    from public.solicitudes_establecimientos s
    where s.id = evidencias_solicitud.solicitud_id
      and s.solicitante_id = auth.uid()
  )
);

create policy "solicitante agrega evidencias a solicitud pendiente"
on public.evidencias_solicitud
for insert
to authenticated
with check (
  exists (
    select 1
    from public.solicitudes_establecimientos s
    where s.id = evidencias_solicitud.solicitud_id
      and s.solicitante_id = auth.uid()
      and s.estado = 'pendiente'::public.estado_solicitud
  )
);

create policy "solicitante elimina evidencias de solicitud pendiente"
on public.evidencias_solicitud
for delete
to authenticated
using (
  public.es_administrador()
  or exists (
    select 1
    from public.solicitudes_establecimientos s
    where s.id = evidencias_solicitud.solicitud_id
      and s.solicitante_id = auth.uid()
      and s.estado = 'pendiente'::public.estado_solicitud
  )
);

drop policy if exists "lectura de establecimientos"
  on public.establecimientos;

create policy "lectura de establecimientos"
on public.establecimientos
for select
to anon, authenticated
using (
  (estado = 'aprobado'::public.estado_establecimiento and publicable)
  or propietario_id = auth.uid()
  or public.es_administrador()
);

drop policy if exists "propietario crea establecimiento pendiente"
  on public.establecimientos;

create policy "propietario crea establecimiento pendiente"
on public.establecimientos
for insert
to authenticated
with check (
  propietario_id = auth.uid()
  and fuente = 'cercly'
  and estado_reclamo is null
  and osm_type is null
  and osm_id is null
  and estado = 'pendiente'::public.estado_establecimiento
  and not publicable
);

create policy "administrador crea establecimientos externos"
on public.establecimientos
for insert
to authenticated
with check (public.es_administrador());

drop policy if exists "usuario crea su solicitud pendiente"
  on public.solicitudes_establecimientos;

create policy "usuario crea su solicitud pendiente"
on public.solicitudes_establecimientos
for insert
to authenticated
with check (
  solicitante_id = auth.uid()
  and estado = 'pendiente'::public.estado_solicitud
  and motivo_respuesta = ''
  and revisado_por is null
  and revisado_en is null
);

-- Las fotos, horarios y promociones solo son publicos cuando el
-- establecimiento tambien es publicable.
drop policy if exists "lectura de fotos visibles"
  on public.fotos_establecimiento;

create policy "lectura de fotos visibles"
on public.fotos_establecimiento
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.establecimientos e
    where e.id = fotos_establecimiento.establecimiento_id
      and (
        (e.estado = 'aprobado'::public.estado_establecimiento and e.publicable)
        or e.propietario_id = auth.uid()
        or public.es_administrador()
      )
  )
);

drop policy if exists "lectura de horarios visibles"
  on public.horarios_establecimiento;

create policy "lectura de horarios visibles"
on public.horarios_establecimiento
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.establecimientos e
    where e.id = horarios_establecimiento.establecimiento_id
      and (
        (e.estado = 'aprobado'::public.estado_establecimiento and e.publicable)
        or e.propietario_id = auth.uid()
        or public.es_administrador()
      )
  )
);

drop policy if exists "lectura de promociones"
  on public.promociones;

create policy "lectura de promociones"
on public.promociones
for select
to anon, authenticated
using (
  (
    activa
    and now() between fecha_inicio and fecha_fin
    and exists (
      select 1
      from public.establecimientos e
      where e.id = promociones.establecimiento_id
        and e.estado = 'aprobado'::public.estado_establecimiento
        and e.publicable
    )
  )
  or exists (
    select 1
    from public.establecimientos e
    where e.id = promociones.establecimiento_id
      and (
        e.propietario_id = auth.uid()
        or public.es_administrador()
      )
  )
);

-- Ajustar las politicas publicas de Storage al nuevo indicador de
-- publicacion. Las politicas de escritura existentes se conservan.
drop policy if exists "lectura de imagenes de establecimientos"
  on storage.objects;

create policy "lectura de imagenes de establecimientos"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'establecimientos-imagenes'
  and (
    exists (
      select 1
      from public.fotos_establecimiento f
      join public.establecimientos e
        on e.id = f.establecimiento_id
      where f.ruta_storage = objects.name
        and e.estado = 'aprobado'::public.estado_establecimiento
        and e.publicable
    )
    or (storage.foldername(name))[1] = auth.uid()::text
    or public.es_administrador()
  )
);

drop policy if exists "lectura de imagenes de promociones"
  on storage.objects;

create policy "lectura de imagenes de promociones"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'promociones-imagenes'
  and (
    exists (
      select 1
      from public.promociones p
      join public.establecimientos e
        on e.id = p.establecimiento_id
      where p.imagen_ruta_storage = objects.name
        and e.estado = 'aprobado'::public.estado_establecimiento
        and e.publicable
        and p.activa
        and now() between p.fecha_inicio and p.fecha_fin
    )
    or (storage.foldername(name))[1] = auth.uid()::text
    or public.es_administrador()
  )
);

grant select on public.subcategorias to anon, authenticated;
grant select on public.establecimiento_categorias to anon, authenticated;
grant insert, update, delete on public.establecimiento_categorias
  to authenticated;
grant select, insert, delete on public.evidencias_solicitud
  to authenticated;

revoke all on function public.buscar_establecimientos_cercanos(
  double precision,
  double precision,
  integer,
  uuid,
  uuid[],
  boolean,
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
  integer,
  integer
) to anon, authenticated;

commit;
