-- Habilita o restaura temporalmente los OSM promovidos para pruebas locales.
-- No es una migracion y debe ejecutarse solo en el contenedor Supabase local.

\set ON_ERROR_STOP on
\if :{?habilitar}
\else
  \set habilitar true
\endif

begin;

create or replace function staging.configurar_osm_pruebas_local(
  p_habilitar boolean,
  p_lote_id uuid default '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'::uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  cantidad_staging integer;
  cantidad_objetivo integer;
  cantidad_actualizada integer;
  cercly_antes text;
  cercly_despues text;
  reclamados_antes text;
  reclamados_despues text;
begin
  perform pg_advisory_xact_lock(hashtext('cercly:osm-pruebas:' || p_lote_id));

  select count(*) into cantidad_staging
  from staging.importacion_establecimientos_osm
  where lote_id = p_lote_id
    and estado_importacion = 'valido'
    and establecimiento_id is not null;

  if cantidad_staging <> 254 then
    raise exception
      'Se esperaban 254 OSM validos promovidos y se encontraron %',
      cantidad_staging;
  end if;

  select count(*) into cantidad_objetivo
  from public.establecimientos e
  join staging.importacion_establecimientos_osm i
    on i.establecimiento_id = e.id
  where i.lote_id = p_lote_id
    and i.estado_importacion = 'valido'
    and e.fuente = 'osm'
    and e.estado_reclamo = 'no_reclamado'
    and e.propietario_id is null;

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

  perform set_config('session_replication_role', 'replica', true);

  update public.establecimientos e
  set
    estado = case
      when p_habilitar then 'aprobado'::public.estado_establecimiento
      else 'pendiente'::public.estado_establecimiento
    end,
    publicable = p_habilitar
  from staging.importacion_establecimientos_osm i
  where i.lote_id = p_lote_id
    and i.estado_importacion = 'valido'
    and i.establecimiento_id = e.id
    and e.fuente = 'osm'
    and e.estado_reclamo = 'no_reclamado'
    and e.propietario_id is null;

  get diagnostics cantidad_actualizada = row_count;
  perform set_config('session_replication_role', 'origin', true);

  if cantidad_actualizada <> cantidad_objetivo then
    raise exception
      'Se actualizaron % OSM y se esperaban %',
      cantidad_actualizada,
      cantidad_objetivo;
  end if;

  if exists (
    select 1
    from staging.importacion_establecimientos_osm i
    join public.establecimientos e
      on e.osm_type = i.osm_type and e.osm_id = i.osm_id
    where i.lote_id = p_lote_id
      and i.estado_importacion in ('observado', 'descartado')
      and e.fuente = 'osm'
      and (e.estado = 'aprobado' or e.publicable)
  ) then
    raise exception 'Un OSM observado o descartado fue habilitado';
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
    raise exception 'El modo de prueba modifico establecimientos Cercly';
  end if;

  if reclamados_antes is distinct from reclamados_despues then
    raise exception 'El modo de prueba modifico establecimientos OSM reclamados';
  end if;

  return cantidad_actualizada;
exception
  when others then
    perform set_config('session_replication_role', 'origin', true);
    raise;
end;
$$;

revoke all on function staging.configurar_osm_pruebas_local(boolean, uuid)
  from public;
revoke all on function staging.configurar_osm_pruebas_local(boolean, uuid)
  from anon;
revoke all on function staging.configurar_osm_pruebas_local(boolean, uuid)
  from authenticated;

select staging.configurar_osm_pruebas_local(:'habilitar'::boolean)
  as establecimientos_actualizados;

commit;

select estado, publicable, count(*)
from public.establecimientos
where fuente = 'osm'
group by estado, publicable
order by estado, publicable;
