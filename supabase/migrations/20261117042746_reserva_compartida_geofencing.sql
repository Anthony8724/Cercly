-- Sin conexión o sin respuesta confirmada, el cliente no debe mostrar la
-- notificación: no puede asegurar deduplicación global. Las reservas de
-- resultado incierto se conservan; no se reintentan automáticamente.
begin;
alter table public.push_preferences
  add column geofencing_enabled boolean not null default false,
  add column geofencing_consented_at timestamptz,
  add column geofencing_location_consented_at timestamptz,
  add constraint geofencing_consent_consistent check (
    geofencing_enabled = (geofencing_consented_at is not null)
    and geofencing_enabled = (geofencing_location_consented_at is not null)
  );
alter table public.promotion_push_reservations
  add column channel text not null default 'fcm'
  check (channel in ('fcm','geofencing')),
  add constraint reservation_channel_installation_consistent check
  (channel='fcm' or installation_id is null);
create schema cercly_notification_private;
revoke all on schema cercly_notification_private from public, anon, authenticated, service_role;

create function public.configurar_mis_alertas_geofencing(p_enabled boolean, p_location_consent boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
  if p_enabled is null or (p_enabled and p_location_consent is distinct from true) then
    raise exception 'location consent required' using errcode='42501';
  end if;
  insert into public.push_preferences(user_id,geofencing_enabled,geofencing_consented_at,geofencing_location_consented_at)
  values(v_user,p_enabled,case when p_enabled then now() end,case when p_enabled then now() end)
  on conflict(user_id) do update set
    geofencing_enabled=excluded.geofencing_enabled,
    geofencing_consented_at=case when excluded.geofencing_enabled then coalesce(public.push_preferences.geofencing_consented_at,excluded.geofencing_consented_at) end,
    geofencing_location_consented_at=case when excluded.geofencing_enabled then coalesce(public.push_preferences.geofencing_location_consented_at,excluded.geofencing_location_consented_at) end,
    updated_at=now();
end; $$;
revoke all on function public.configurar_mis_alertas_geofencing(boolean,boolean) from public,anon,authenticated;
grant execute on function public.configurar_mis_alertas_geofencing(boolean,boolean) to authenticated;

create or replace function cercly_notification_private.reservar_comun(
  p_channel text,
  p_promotion_id uuid,
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
  if p_channel is null or p_channel not in ('fcm','geofencing')
     or (p_channel='fcm' and p_installation_id is null)
     or (p_channel='geofencing' and p_promotion_id is null)
     or p_user_id is null or p_event_id is null
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
  where p.user_id = p_user_id
  for update;
  if not found then return; end if;
  if p_channel='fcm' and (not v_preferences.enabled or v_preferences.location_consent_at is null) then return; end if;
  if p_channel='geofencing' and (not v_preferences.geofencing_enabled or v_preferences.geofencing_consented_at is null or v_preferences.geofencing_location_consented_at is null) then return; end if;

  if p_channel='fcm' then
  select i.fcm_installation_id into v_token
  from public.fcm_installations i
  where i.installation_id = p_installation_id
    and i.user_id = p_user_id
    and i.active;
  if not found then return; end if;
  update public.fcm_installations i
  set last_seen_at = now()
  where i.installation_id = p_installation_id;
  end if;

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
  where (p_promotion_id is null or p.id=p_promotion_id)
    and p.activa
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
    user_id, installation_id, promotion_id, establishment_id, event_id, channel
  ) values (
    p_user_id, case when p_channel='fcm' then p_installation_id else null end, v_promotion.id,
    v_establishment.id, p_event_id, p_channel
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

revoke all on function cercly_notification_private.reservar_comun(text,uuid,uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint) from public,anon,authenticated,service_role;

create or replace function public.reservar_promocion_push_reciente(
 p_user_id uuid,p_installation_id uuid,p_event_id uuid,p_latitude double precision,
 p_longitude double precision,p_accuracy_meters double precision,p_observed_at timestamptz,p_utc_offset_minutes smallint
) returns table(reservation_id uuid,event_id uuid,promotion_id uuid,establishment_id uuid,
 fcm_installation_id text,promotion_title text,promotion_description text,establishment_name text)
language sql security definer set search_path = pg_catalog, public, extensions as $$
 select * from cercly_notification_private.reservar_comun('fcm',null,p_user_id,p_installation_id,p_event_id,
 p_latitude,p_longitude,p_accuracy_meters,p_observed_at,p_utc_offset_minutes);
$$;
revoke all on function public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint) from public,anon,authenticated;
grant execute on function public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint) to service_role;

create function public.reservar_promocion_geofencing(
 p_promotion_id uuid,p_event_id uuid,p_latitude double precision,p_longitude double precision,
 p_accuracy_meters double precision,p_observed_at timestamptz,p_utc_offset_minutes smallint
) returns table(reservation_id uuid,event_id uuid,promotion_id uuid,establishment_id uuid,promotion_title text,establishment_name text)
language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid();
begin
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 return query select r.reservation_id,r.event_id,r.promotion_id,r.establishment_id,r.promotion_title,r.establishment_name
 from cercly_notification_private.reservar_comun('geofencing',p_promotion_id,v_user,null,p_event_id,
 p_latitude,p_longitude,p_accuracy_meters,p_observed_at,p_utc_offset_minutes) r;
end; $$;
revoke all on function public.reservar_promocion_geofencing(uuid,uuid,double precision,double precision,double precision,timestamptz,smallint) from public,anon,authenticated;
grant execute on function public.reservar_promocion_geofencing(uuid,uuid,double precision,double precision,double precision,timestamptz,smallint) to authenticated;

create function public.finalizar_reserva_geofencing(p_reservation_id uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid();
begin
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_status is null or p_status not in ('sent','failed') then raise exception 'invalid delivery status' using errcode='22023'; end if;
 update public.promotion_push_reservations set status=p_status,completed_at=now()
 where id=p_reservation_id and user_id=v_user and channel='geofencing' and status='reserved';
end; $$;
revoke all on function public.finalizar_reserva_geofencing(uuid,text) from public,anon,authenticated;
grant execute on function public.finalizar_reserva_geofencing(uuid,text) to authenticated;
commit;
