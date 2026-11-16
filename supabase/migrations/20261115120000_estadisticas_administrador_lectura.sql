-- BORRADOR PARA REVISION. No aplicar en Produccion sin aprobacion.
--
-- Estadisticas agregadas de solo lectura para el panel de administracion.
-- Solo devuelve conteos: no expone ids, correos, nombres ni ubicaciones.
-- Cada funcion verifica public.es_administrador() en el backend; ocultar el
-- boton en la app no es suficiente.
--
-- Definiciones usadas (deben aprobarse con el equipo):
--   * Tipo de usuario: columna public.usuarios.rol (enum rol_usuario con los
--     valores usuario, propietario y administrador). Se usa el rol ACTUAL.
--     Propietario = rol 'propietario'; usuario normal = rol 'usuario';
--     administrador = rol 'administrador' (mismo criterio que
--     public.es_administrador()). Los administradores se cuentan aparte y no
--     entran en la serie de nuevos registros.
--   * propietarios_con_establecimiento: usuarios que figuran como
--     propietario_id de algun establecimiento o son miembros activos de uno.
--     Se entrega aparte porque puede diferir del rol. POR VERIFICAR: un
--     propietario_id comodin en establecimientos importados de OSM sumaria 1.
--   * Usuario activo: inicio de sesion (auth.users.last_sign_in_at) en los
--     ultimos N dias (30 por defecto). Es una medida aproximada: solo refleja
--     inicios de sesion, no uso real de la app.
--   * Dias agrupados en la zona horaria America/Guayaquil.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- ---------------------------------------------------------------------------
-- 1. Resumen general (KPI)
-- ---------------------------------------------------------------------------
create or replace function public.admin_estadisticas_resumen(
  p_dias_activos integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_resultado jsonb;
begin
  if not public.es_administrador() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;

  if p_dias_activos is null or p_dias_activos < 1 or p_dias_activos > 365 then
    raise exception 'p_dias_activos fuera de rango (1-365)' using errcode = '22023';
  end if;

  with propietarios_con_establecimiento as (
    select e.propietario_id as usuario_id
    from public.establecimientos e
    where e.propietario_id is not null
    union
    select m.usuario_id
    from public.miembros_establecimiento m
    where m.activo
  )
  select jsonb_build_object(
    'generado_en', now(),
    'usuarios_total', (select count(*) from public.usuarios),
    'propietarios_total', (
      select count(*) from public.usuarios u where u.rol = 'propietario'
    ),
    'administradores_total', (
      select count(*) from public.usuarios u where u.rol = 'administrador'
    ),
    'usuarios_normales_total', (
      select count(*) from public.usuarios u where u.rol = 'usuario'
    ),
    'propietarios_con_establecimiento', (
      select count(*) from propietarios_con_establecimiento
    ),
    'dias_usuario_activo', p_dias_activos,
    'usuarios_activos', (
      select count(*)
      from auth.users au
      join public.usuarios u on u.id = au.id
      where au.last_sign_in_at >= now() - make_interval(days => p_dias_activos)
    ),
    'establecimientos', (
      select jsonb_build_object(
        'total', count(*),
        'pendientes', count(*) filter (where e.estado = 'pendiente'),
        'aprobados', count(*) filter (where e.estado = 'aprobado'),
        'rechazados', count(*) filter (where e.estado = 'rechazado')
      )
      from public.establecimientos e
    ),
    'solicitudes', (
      select jsonb_build_object(
        'total', count(*),
        'pendientes', count(*) filter (where s.estado = 'pendiente'),
        'aprobadas', count(*) filter (where s.estado = 'aprobada'),
        'rechazadas', count(*) filter (where s.estado = 'rechazada')
      )
      from public.solicitudes_establecimientos s
    ),
    'promociones', (
      select jsonb_build_object(
        'total', count(*),
        'activas', count(*) filter (where pr.activa)
      )
      from public.promociones pr
    )
  )
  into v_resultado;

  return v_resultado;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Nuevos registros por dia, semana o mes, separados por rol
--    (tipo_usuario devuelve 'usuario' o 'propietario'; sin administradores)
-- ---------------------------------------------------------------------------
create or replace function public.admin_estadisticas_registros(
  p_desde date,
  p_hasta date,
  p_granularidad text default 'dia'
)
returns table (periodo date, tipo_usuario text, total bigint)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_unidad text;
  v_zona constant text := 'America/Guayaquil';
begin
  if not public.es_administrador() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;

  v_unidad := case p_granularidad
    when 'dia' then 'day'
    when 'semana' then 'week'
    when 'mes' then 'month'
    else null
  end;

  if v_unidad is null then
    raise exception 'p_granularidad debe ser dia, semana o mes' using errcode = '22023';
  end if;

  if p_desde is null or p_hasta is null or p_desde > p_hasta
     or (p_hasta - p_desde) > 730 then
    raise exception 'Rango de fechas invalido (maximo 730 dias)' using errcode = '22023';
  end if;

  return query
  select
    date_trunc(v_unidad, u.creado_en at time zone v_zona)::date,
    u.rol::text,
    count(*)::bigint
  from public.usuarios u
  where (u.creado_en at time zone v_zona)::date between p_desde and p_hasta
    and u.rol <> 'administrador'
  group by 1, 2
  order by 1, 2;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Permisos: solo usuarios autenticados pueden llamar; la funcion rechaza
--    a quien no sea administrador.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_estadisticas_resumen(integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_estadisticas_resumen(integer)
  to authenticated;

revoke all on function public.admin_estadisticas_registros(date, date, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_estadisticas_registros(date, date, text)
  to authenticated;

comment on function public.admin_estadisticas_resumen(integer) is
  'KPI agregados para el panel de administracion. Solo administradores.';
comment on function public.admin_estadisticas_registros(date, date, text) is
  'Nuevos registros por periodo y rol. Solo administradores.';

commit;
