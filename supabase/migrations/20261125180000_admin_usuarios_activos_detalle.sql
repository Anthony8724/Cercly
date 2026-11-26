begin;

create or replace function public.admin_usuarios_activos_detalle(
  p_dias_activos integer default 30,
  p_limite integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  nombre text,
  rol text,
  ultimo_inicio_sesion timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not public.es_administrador() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;

  if p_dias_activos is null or p_dias_activos < 1 or p_dias_activos > 365 then
    raise exception 'p_dias_activos fuera de rango (1-365)' using errcode = '22023';
  end if;

  if p_limite is null or p_limite < 1 or p_limite > 200 then
    raise exception 'p_limite fuera de rango (1-200)' using errcode = '22023';
  end if;

  if p_offset is null or p_offset < 0 then
    raise exception 'p_offset invalid' using errcode = '22023';
  end if;

  return query
  select
    u.id,
    u.nombre::text,
    u.rol::text,
    au.last_sign_in_at
  from auth.users au
  join public.usuarios u on u.id = au.id
  where au.last_sign_in_at >= now() - make_interval(days => p_dias_activos)
  order by au.last_sign_in_at desc, u.nombre asc, u.id asc
  limit p_limite
  offset p_offset;
end;
$function$;

revoke all on function public.admin_usuarios_activos_detalle(integer, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_usuarios_activos_detalle(integer, integer, integer)
  to authenticated;
commit;
