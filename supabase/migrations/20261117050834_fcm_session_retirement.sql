begin;
-- Keep a session-bound retirement tombstone even if an old request arrives
-- before its first registration. User deletion still cascades through the
-- already-existing fcm_installations -> auth.users relation.
alter table public.fcm_installations alter column fcm_installation_id drop not null;
alter table public.fcm_installations add column authorized_session_id uuid;
alter table public.fcm_installations add constraint active_installation_has_session_and_token
  check (not active or (authorized_session_id is not null and fcm_installation_id is not null)) not valid;
-- Existing installations have no proven session; refuse delivery until a new
-- authenticated registration associates them explicitly.
update public.fcm_installations set active=false;
create table cercly_notification_private.fcm_retired_sessions (
  installation_id uuid not null references public.fcm_installations(installation_id) on delete cascade,
  session_id uuid not null,
  retired_at timestamptz not null default now(),
  primary key (installation_id, session_id)
);
revoke all on cercly_notification_private.fcm_retired_sessions from public,anon,authenticated,service_role;

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
    update public.fcm_installations set active=false,fcm_installation_id=null where user_id = v_user_id;
  end if;
end;
$function$;


create or replace function public.registrar_mi_instalacion_fcm(
  p_installation_id uuid,p_fcm_installation_id text,p_platform text
) returns void language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_user uuid:=auth.uid(); v_session uuid; v_rows integer;
begin
  if p_installation_id is null or p_fcm_installation_id is null
     or length(p_fcm_installation_id) not between 16 and 4096
     or p_platform is null or p_platform not in ('android','ios') then
    raise exception 'invalid installation registration' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_installation_id::text,24671));
  perform cercly_notification_private.exigir_sesion_activa();
  v_session:=(auth.jwt()->>'session_id')::uuid;
  if exists(select 1 from cercly_notification_private.fcm_retired_sessions t
    where t.installation_id=p_installation_id and t.session_id=v_session) then
    raise exception 'installation session retired' using errcode='42501';
  end if;
  -- Serialize consent changes with registration until this transaction commits.
  perform 1 from public.push_preferences p where p.user_id=v_user
    and p.enabled and p.location_consent_at is not null for update;
  if not found then
    raise exception 'promotional push consent required' using errcode='42501';
  end if;
  insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform,active,authorized_session_id)
  values(p_installation_id,v_user,p_fcm_installation_id,p_platform,true,v_session)
  on conflict(installation_id) do update set
    fcm_installation_id=excluded.fcm_installation_id,platform=excluded.platform,
    active=true,authorized_session_id=v_session,fcm_token_generation=gen_random_uuid(),token_updated_at=now(),last_seen_at=now()
  where public.fcm_installations.user_id=v_user;
  get diagnostics v_rows=row_count;
  if v_rows=0 then raise exception 'installation belongs to another account' using errcode='42501'; end if;
end; $$;

create or replace function public.retirar_mi_instalacion_fcm(p_installation_id uuid)
returns void language plpgsql security definer set search_path=pg_catalog,public as $$
declare v_user uuid:=auth.uid(); v_session uuid; v_previous_session uuid; v_rows integer;
begin
  if p_installation_id is null then raise exception 'installation id required' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_installation_id::text,24671));
  perform cercly_notification_private.exigir_sesion_activa();
  v_session:=(auth.jwt()->>'session_id')::uuid;
  select authorized_session_id into v_previous_session from public.fcm_installations
    where installation_id=p_installation_id and user_id=v_user;
  insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform,active,authorized_session_id)
  values(p_installation_id,v_user,null,'android',false,null)
  on conflict(installation_id) do update set active=false,fcm_installation_id=null
    where public.fcm_installations.user_id=v_user;
  get diagnostics v_rows=row_count;
  if v_rows=0 then raise exception 'installation belongs to another account or session' using errcode='42501'; end if;
  insert into cercly_notification_private.fcm_retired_sessions(installation_id,session_id)
  values(p_installation_id,v_session) on conflict do nothing;
  if v_previous_session is not null then
    insert into cercly_notification_private.fcm_retired_sessions(installation_id,session_id)
    values(p_installation_id,v_previous_session) on conflict do nothing;
  end if;
end; $$;

-- Evaluation requests must prove the same live session that owns the device.
create function public.mi_sesion_fcm_activa() returns uuid
language plpgsql security definer set search_path='' as $$
begin
  perform cercly_notification_private.exigir_sesion_activa();
  return (auth.jwt()->>'session_id')::uuid;
end; $$;
revoke all on function public.mi_sesion_fcm_activa() from public,anon,authenticated;
grant execute on function public.mi_sesion_fcm_activa() to authenticated;
-- The previous server entry point is not a proof of the initiating session.
-- Only this overload accepts the session verified by the authenticated RPC.
revoke all on function public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)
  from public,anon,authenticated,service_role;
create function public.reservar_promocion_push_reciente(
  p_user_id uuid,p_installation_id uuid,p_event_id uuid,p_latitude double precision,
  p_longitude double precision,p_accuracy_meters double precision,p_observed_at timestamptz,
  p_utc_offset_minutes smallint,p_session_id uuid
) returns table(reservation_id uuid,event_id uuid,promotion_id uuid,establishment_id uuid,
  fcm_installation_id text,promotion_title text,promotion_description text,establishment_name text)
language plpgsql security definer set search_path=pg_catalog,public,extensions as $$
begin
  if p_installation_id is null or p_user_id is null or p_session_id is null then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_installation_id::text,24671));
  if not exists(select 1 from public.fcm_installations i
    join auth.sessions s on s.id=i.authorized_session_id and s.user_id=i.user_id
    where i.installation_id=p_installation_id and i.user_id=p_user_id
      and i.authorized_session_id=p_session_id and i.active
      and not exists(select 1 from cercly_notification_private.fcm_retired_sessions t
        where t.installation_id=i.installation_id and t.session_id=p_session_id)) then return; end if;
  return query select * from public.reservar_promocion_push_reciente(
    p_user_id,p_installation_id,p_event_id,p_latitude,p_longitude,p_accuracy_meters,
    p_observed_at,p_utc_offset_minutes);
end; $$;
revoke all on function public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint,uuid)
  from public,anon,authenticated;
grant execute on function public.reservar_promocion_push_reciente(uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint,uuid)
  to service_role;
create function public.entrega_fcm_autorizada(p_reservation_id uuid,p_session_id uuid)
returns boolean language sql security definer set search_path=pg_catalog,public,extensions as $$
  select exists(select 1 from public.promotion_push_reservations r
    join public.fcm_installations i on i.installation_id=r.installation_id and i.user_id=r.user_id
    join auth.sessions s on s.id=i.authorized_session_id and s.user_id=i.user_id
    join public.push_preferences p on p.user_id=i.user_id
    where r.id=p_reservation_id and r.channel='fcm' and r.status='reserved'
      and i.active and i.authorized_session_id=p_session_id and p.enabled
      and p.consented_at is not null and p.location_consent_at is not null
      and extensions.digest(convert_to(i.fcm_installation_id,'UTF8'),'sha256')=r.fcm_token_sha256
      and i.fcm_token_generation=r.fcm_token_generation
      and not exists(select 1 from cercly_notification_private.fcm_retired_sessions t
        where t.installation_id=i.installation_id and t.session_id=p_session_id));
$$;
revoke all on function public.entrega_fcm_autorizada(uuid,uuid) from public,anon,authenticated;
grant execute on function public.entrega_fcm_autorizada(uuid,uuid) to service_role;
commit;
