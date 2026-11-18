begin;

create table public.push_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  location_consent_at timestamptz,
  consented_at timestamptz,
  daily_limit smallint not null default 6
    check (daily_limit in (3, 6, 10)),
  quiet_start_minutes smallint,
  quiet_end_minutes smallint,
  radius_meters smallint not null default 1500
    check (radius_meters in (1000, 1500, 3000, 5000, 10000)),
  updated_at timestamptz not null default now(),
  check ((quiet_start_minutes is null) = (quiet_end_minutes is null)),
  check (quiet_start_minutes is null or quiet_start_minutes between 0 and 1439),
  check (quiet_end_minutes is null or quiet_end_minutes between 0 and 1439),
  check (quiet_start_minutes is null or quiet_start_minutes <> quiet_end_minutes),
  check (enabled = (consented_at is not null)),
  check (enabled = (location_consent_at is not null))
);

create table public.fcm_installations (
  installation_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_installation_id text not null unique
    check (length(fcm_installation_id) between 16 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  active boolean not null default true,
  token_updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index fcm_installations_user_seen_idx
  on public.fcm_installations(user_id, last_seen_at desc);

create table public.promotion_push_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  installation_id uuid
    references public.fcm_installations(installation_id) on delete set null,
  promotion_id uuid not null references public.promociones(id) on delete cascade,
  establishment_id uuid not null
    references public.establecimientos(id) on delete cascade,
  event_id uuid not null,
  status text not null default 'reserved'
    check (status in ('reserved', 'sent', 'failed', 'invalid_token')),
  provider_message_id text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (user_id, event_id),
  unique (user_id, promotion_id)
);

create index promotion_push_reservations_user_created_idx
  on public.promotion_push_reservations(user_id, created_at desc);
create index promotion_push_reservations_business_created_idx
  on public.promotion_push_reservations(user_id, establishment_id, created_at desc);

alter table public.push_preferences enable row level security;
alter table public.fcm_installations enable row level security;
alter table public.promotion_push_reservations enable row level security;

revoke all on public.push_preferences from public, anon, authenticated;
revoke all on public.fcm_installations from public, anon, authenticated;
revoke all on public.promotion_push_reservations from public, anon, authenticated;
grant all on public.push_preferences to service_role;
grant all on public.fcm_installations to service_role;
grant all on public.promotion_push_reservations to service_role;

create or replace function public.configurar_mis_alertas_push_promociones(
  p_enabled boolean,
  p_location_consent boolean,
  p_daily_limit smallint,
  p_quiet_start_minutes smallint,
  p_quiet_end_minutes smallint,
  p_radius_meters smallint
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_daily_limit not in (3, 6, 10) then
    raise exception 'invalid notification frequency' using errcode = '22023';
  end if;
  if p_radius_meters not in (1000, 1500, 3000, 5000, 10000) then
    raise exception 'invalid radius' using errcode = '22023';
  end if;
  if (p_quiet_start_minutes is null) <> (p_quiet_end_minutes is null)
     or p_quiet_start_minutes not between 0 and 1439
     or p_quiet_end_minutes not between 0 and 1439
     or (p_quiet_start_minutes is not null
         and p_quiet_start_minutes = p_quiet_end_minutes) then
    raise exception 'invalid quiet hours' using errcode = '22023';
  end if;
  if p_enabled and p_location_consent is distinct from true then
    raise exception 'location consent required for proximity push'
      using errcode = '42501';
  end if;

  insert into public.push_preferences (
    user_id, enabled, consented_at, location_consent_at, daily_limit,
    quiet_start_minutes, quiet_end_minutes, radius_meters, updated_at
  ) values (
    v_user_id, p_enabled,
    case when p_enabled then now() else null end,
    case when p_enabled then now() else null end,
    p_daily_limit, p_quiet_start_minutes, p_quiet_end_minutes,
    p_radius_meters, now()
  )
  on conflict (user_id) do update set
    enabled = excluded.enabled,
    consented_at = case when excluded.enabled
      then coalesce(public.push_preferences.consented_at, excluded.consented_at)
      else null end,
    location_consent_at = case when excluded.enabled
      then coalesce(public.push_preferences.location_consent_at,
                    excluded.location_consent_at)
      else null end,
    daily_limit = excluded.daily_limit,
    quiet_start_minutes = excluded.quiet_start_minutes,
    quiet_end_minutes = excluded.quiet_end_minutes,
    radius_meters = excluded.radius_meters,
    updated_at = now();

  if not p_enabled then
    delete from public.fcm_installations where user_id = v_user_id;
  end if;
end;
$function$;

revoke all on function public.configurar_mis_alertas_push_promociones(
  boolean, boolean, smallint, smallint, smallint, smallint
) from public, anon;
grant execute on function public.configurar_mis_alertas_push_promociones(
  boolean, boolean, smallint, smallint, smallint, smallint
) to authenticated;

create or replace function public.registrar_mi_instalacion_fcm(
  p_installation_id uuid,
  p_fcm_installation_id text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_user_id uuid := auth.uid();
  v_rows_updated integer;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_installation_id is null or p_fcm_installation_id is null
     or length(p_fcm_installation_id) not between 16 and 4096
     or p_platform not in ('android', 'ios') then
    raise exception 'invalid installation registration' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.push_preferences p
    where p.user_id = v_user_id
      and p.enabled
      and p.location_consent_at is not null
  ) then
    raise exception 'promotional push consent required' using errcode = '42501';
  end if;

  insert into public.fcm_installations (
    installation_id, user_id, fcm_installation_id, platform,
    token_updated_at, last_seen_at
  ) values (
    p_installation_id, v_user_id, p_fcm_installation_id, p_platform, now(), now()
  )
  on conflict (installation_id) do update set
    user_id = excluded.user_id,
    fcm_installation_id = excluded.fcm_installation_id,
    platform = excluded.platform,
    active = true,
    token_updated_at = now(),
    last_seen_at = now()
  where public.fcm_installations.user_id = excluded.user_id;
  get diagnostics v_rows_updated = row_count;
  if v_rows_updated = 0 then
    raise exception 'installation belongs to another account'
      using errcode = '42501';
  end if;
end;
$function$;

revoke all on function public.registrar_mi_instalacion_fcm(uuid, text, text)
  from public, anon;
grant execute on function public.registrar_mi_instalacion_fcm(uuid, text, text)
  to authenticated;

create or replace function public.retirar_mi_instalacion_fcm(
  p_installation_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_installation_id is null then
    raise exception 'installation id required' using errcode = '22023';
  end if;
  -- Only the authenticated owner may retire an installation. Account changes
  -- must revoke before sign-out; registration never steals another user's row.
  delete from public.fcm_installations
  where installation_id = p_installation_id
    and user_id = auth.uid();
end;
$function$;

revoke all on function public.retirar_mi_instalacion_fcm(uuid)
  from public, anon;
grant execute on function public.retirar_mi_instalacion_fcm(uuid)
  to authenticated;

create or replace function public.reservar_promocion_push_reciente(
  p_user_id uuid,
  p_installation_id uuid,
  p_event_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision,
  p_observed_at timestamptz,
  p_utc_offset_minutes smallint
)
returns table (
  reservation_id uuid,
  event_id uuid,
  promotion_id uuid,
  establishment_id uuid,
  fcm_installation_id text,
  promotion_title text,
  promotion_description text,
  establishment_name text
)
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $function$
declare
  v_preferences public.push_preferences%rowtype;
  v_local_time timestamp;
  v_local_minute integer;
  v_promotion public.promociones%rowtype;
  v_establishment public.establecimientos%rowtype;
  v_token text;
  v_reservation_id uuid;
begin
  if p_user_id is null or p_installation_id is null or p_event_id is null
     or p_latitude is null or p_longitude is null
     or p_accuracy_meters is null or p_observed_at is null
     or p_utc_offset_minutes is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180
     or p_accuracy_meters <= 0 or p_accuracy_meters > 100
     or p_utc_offset_minutes not between -840 and 840
     or p_observed_at < now() - interval '2 minutes'
     or p_observed_at > now() + interval '15 seconds' then
    return;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  if exists (
    select 1 from public.promotion_push_reservations r
    where r.user_id = p_user_id and r.event_id = p_event_id
  ) then
    return;
  end if;

  select p.* into v_preferences
  from public.push_preferences p
  where p.user_id = p_user_id and p.enabled
    and p.location_consent_at is not null
  for update;
  if not found then return; end if;

  select i.fcm_installation_id into v_token
  from public.fcm_installations i
  where i.installation_id = p_installation_id
    and i.user_id = p_user_id
    and i.active;
  if not found then return; end if;
  update public.fcm_installations i
  set last_seen_at = now()
  where i.installation_id = p_installation_id;

  v_local_time := (now() at time zone 'UTC')
    + make_interval(mins => p_utc_offset_minutes);
  v_local_minute := extract(hour from v_local_time)::integer * 60
    + extract(minute from v_local_time)::integer;
  if v_preferences.quiet_start_minutes is not null then
    if v_preferences.quiet_start_minutes < v_preferences.quiet_end_minutes then
      if v_local_minute >= v_preferences.quiet_start_minutes
         and v_local_minute < v_preferences.quiet_end_minutes then
        return;
      end if;
    elsif v_local_minute >= v_preferences.quiet_start_minutes
       or v_local_minute < v_preferences.quiet_end_minutes then
      return;
    end if;
  end if;

  if exists (
    select 1 from public.promotion_push_reservations r
    where r.user_id = p_user_id
      and r.created_at > now() - interval '24 hours'
  ) and (
    select count(*) from public.promotion_push_reservations r
    where r.user_id = p_user_id
      and r.created_at > now() - interval '24 hours'
  ) >= v_preferences.daily_limit then
    return;
  end if;
  if exists (
    select 1 from public.promotion_push_reservations r
    where r.user_id = p_user_id
      and r.created_at > now() - interval '15 minutes'
  ) then
    return;
  end if;

  select p.*
  into v_promotion
  from public.promociones p
  join public.establecimientos e on e.id = p.establecimiento_id
  where p.activa
    and p.fecha_inicio <= now()
    and p.fecha_fin >= now()
    and e.estado = 'aprobado'::public.estado_establecimiento
    and e.publicable
    and extensions.st_distance(
      e.ubicacion,
      extensions.st_setsrid(
        extensions.st_makepoint(p_longitude, p_latitude), 4326
      )::extensions.geography
    ) + p_accuracy_meters <= least(
      1500.0,
      v_preferences.radius_meters::double precision,
      p.radio_alerta_metros::double precision
    )
    and not exists (
      select 1 from public.promotion_push_reservations r
      where r.user_id = p_user_id and r.promotion_id = p.id
    )
    and not exists (
      select 1 from public.promotion_push_reservations r
      where r.user_id = p_user_id
        and r.establishment_id = e.id
        and r.created_at > now() - interval '4 hours'
    )
  order by extensions.st_distance(
    e.ubicacion,
    extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography
  ), p.id
  limit 1
  for share of p, e;
  if not found then return; end if;

  select e.* into v_establishment
  from public.establecimientos e
  where e.id = v_promotion.establecimiento_id
    and e.estado = 'aprobado'::public.estado_establecimiento
    and e.publicable
  for share;
  if not found then return; end if;

  insert into public.promotion_push_reservations (
    user_id, installation_id, promotion_id, establishment_id, event_id
  ) values (
    p_user_id, p_installation_id, v_promotion.id,
    v_establishment.id, p_event_id
  ) returning id into v_reservation_id;

  return query select
    v_reservation_id,
    p_event_id,
    v_promotion.id,
    v_establishment.id,
    v_token,
    left(v_promotion.titulo::text, 120),
    v_promotion.descripcion::text,
    left(v_establishment.nombre::text, 120);
end;
$function$;

revoke all on function public.reservar_promocion_push_reciente(
  uuid, uuid, uuid, double precision, double precision, double precision,
  timestamptz, smallint
) from public, anon, authenticated;
grant execute on function public.reservar_promocion_push_reciente(
  uuid, uuid, uuid, double precision, double precision, double precision,
  timestamptz, smallint
) to service_role;

create or replace function public.finalizar_reserva_promocion_push(
  p_reservation_id uuid,
  p_status text,
  p_provider_message_id text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if p_status not in ('sent', 'failed', 'invalid_token') then
    raise exception 'invalid delivery status' using errcode = '22023';
  end if;
  update public.promotion_push_reservations
  set status = p_status,
      provider_message_id = left(p_provider_message_id, 500),
      completed_at = now()
  where id = p_reservation_id and status = 'reserved';
  if p_status = 'invalid_token' then
    update public.fcm_installations i
    set active = false
    where i.installation_id = (
      select r.installation_id
      from public.promotion_push_reservations r
      where r.id = p_reservation_id
    );
  end if;
end;
$function$;

revoke all on function public.finalizar_reserva_promocion_push(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.finalizar_reserva_promocion_push(uuid, text, text)
  to service_role;

commit;
