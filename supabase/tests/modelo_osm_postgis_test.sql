-- Pruebas de contrato para la migracion modelo_osm_postgis.
-- Ejecutar despues de aplicar las migraciones en una base local o efimera.
-- Este archivo no inserta establecimientos OSM.

begin;

do $$
declare
  categorias_activas integer;
  subcategorias_requeridas integer;
  establecimientos_osm integer;
  datos_legacy_invalidos integer;
begin
  select count(*)
  into categorias_activas
  from public.categorias
  where activa;

  if categorias_activas <> 12 then
    raise exception
      'Se esperaban 12 categorias activas y existen %',
      categorias_activas;
  end if;

  select count(*)
  into subcategorias_requeridas
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
  );

  if subcategorias_requeridas <> 12 then
    raise exception
      'Faltan subcategorias obligatorias de belleza o servicios';
  end if;

  if exists (
    select 1
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
  ) then
    raise exception
      'Una subcategoria de belleza fue asignada a otra categoria';
  end if;

  select count(*)
  into establecimientos_osm
  from public.establecimientos
  where fuente = 'osm';

  if establecimientos_osm <> 0 then
    raise exception
      'La migracion estructural no debe importar establecimientos OSM';
  end if;

  select count(*)
  into datos_legacy_invalidos
  from public.establecimientos
  where fuente <> 'cercly'
     or estado_reclamo is not null
     or publicable <> (
       estado = 'aprobado'::public.estado_establecimiento
     );

  if datos_legacy_invalidos <> 0 then
    raise exception
      'La adaptacion de establecimientos existentes es inconsistente';
  end if;

  if exists (
    select 1
    from public.establecimientos
    where ubicacion is null
  ) then
    raise exception 'Existen establecimientos sin punto geografico';
  end if;

  if to_regclass('public.subcategorias') is null
     or to_regclass('public.establecimiento_categorias') is null
     or to_regclass('public.evidencias_solicitud') is null
     or to_regclass('staging.importacion_establecimientos_osm') is null then
    raise exception 'Falta una tabla requerida por el modelo';
  end if;

  if to_regprocedure(
    'public.buscar_establecimientos_cercanos(double precision,double precision,integer,uuid,uuid[],boolean,integer,integer)'
  ) is null then
    raise exception 'No existe la RPC de busqueda geografica';
  end if;

  if has_schema_privilege('anon', 'staging', 'usage')
     or has_schema_privilege('authenticated', 'staging', 'usage') then
    raise exception
      'La infraestructura staging es accesible desde Flutter';
  end if;
end;
$$;

rollback;
