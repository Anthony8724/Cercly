begin;
-- A valid but revoked JWT must not authorize a geofence operation.
create function cercly_notification_private.exigir_sesion_activa()
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_session uuid;
begin
  begin
    v_session := nullif(auth.jwt()->>'session_id','')::uuid;
  exception when invalid_text_representation then
    raise exception 'active session required' using errcode='28000';
  end;
  if v_user is null or v_session is null then
    raise exception 'active session required' using errcode='28000';
  end if;
  perform 1 from auth.sessions s where s.id=v_session and s.user_id=v_user;
  if not found then raise exception 'active session required' using errcode='28000'; end if;
end; $$;
revoke all on function cercly_notification_private.exigir_sesion_activa() from public,anon,authenticated,service_role;

create or replace function public.configurar_mis_alertas_geofencing(p_enabled boolean, p_location_consent boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid();
begin
 perform cercly_notification_private.exigir_sesion_activa();
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

create or replace function public.reservar_promocion_geofencing(
 p_promotion_id uuid,p_event_id uuid,p_latitude double precision,p_longitude double precision,
 p_accuracy_meters double precision,p_observed_at timestamptz,p_utc_offset_minutes smallint
) returns table(reservation_id uuid,event_id uuid,promotion_id uuid,establishment_id uuid,promotion_title text,establishment_name text)
language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid();
begin
 perform cercly_notification_private.exigir_sesion_activa();
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 return query select r.reservation_id,r.event_id,r.promotion_id,r.establishment_id,r.promotion_title,r.establishment_name
 from cercly_notification_private.reservar_comun('geofencing',p_promotion_id,v_user,null,p_event_id,
 p_latitude,p_longitude,p_accuracy_meters,p_observed_at,p_utc_offset_minutes) r;
end; $$;

create or replace function public.finalizar_reserva_geofencing(p_reservation_id uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid();
begin
 perform cercly_notification_private.exigir_sesion_activa();
 if v_user is null then raise exception 'authentication required' using errcode='28000'; end if;
 if p_status is null or p_status not in ('sent','failed') then raise exception 'invalid delivery status' using errcode='22023'; end if;
 update public.promotion_push_reservations set status=p_status,completed_at=now()
 where id=p_reservation_id and user_id=v_user and channel='geofencing' and status='reserved';
end; $$;
commit;
