-- Bind provider errors to the exact token used for each reservation. Historical
-- reservations without a snapshot cannot deactivate a current installation.
begin;
alter table public.fcm_installations
  add column fcm_token_generation uuid not null default gen_random_uuid();
alter table public.promotion_push_reservations
  add column fcm_token_sha256 bytea,
  add column fcm_token_generation uuid;

create or replace function public.reservar_promocion_push_reciente(
 p_user_id uuid,p_installation_id uuid,p_event_id uuid,p_latitude double precision,
 p_longitude double precision,p_accuracy_meters double precision,p_observed_at timestamptz,p_utc_offset_minutes smallint
) returns table(reservation_id uuid,event_id uuid,promotion_id uuid,establishment_id uuid,
 fcm_installation_id text,promotion_title text,promotion_description text,establishment_name text)
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_installation_id::text,24671));
 for r in select * from cercly_notification_private.reservar_comun('fcm',null,p_user_id,p_installation_id,p_event_id,
   p_latitude,p_longitude,p_accuracy_meters,p_observed_at,p_utc_offset_minutes)
 loop
   update public.promotion_push_reservations p
   set fcm_token_sha256 = extensions.digest(convert_to(r.fcm_installation_id,'UTF8'),'sha256'),
       fcm_token_generation = i.fcm_token_generation
   from public.fcm_installations i
   where p.id=r.reservation_id and p.channel='fcm' and i.installation_id=p_installation_id
     and i.fcm_installation_id=r.fcm_installation_id;
   return query select r.reservation_id,r.event_id,r.promotion_id,r.establishment_id,
     r.fcm_installation_id,r.promotion_title,r.promotion_description,r.establishment_name;
 end loop;
end; $$;

create or replace function public.finalizar_reserva_promocion_push(
  p_reservation_id uuid, p_status text, p_provider_message_id text default null
) returns void language plpgsql security definer set search_path=pg_catalog, public as $$
declare v_installation_id uuid; v_token_sha256 bytea; v_token_generation uuid;
begin
  if p_status is null or p_status not in ('sent','failed','invalid_token') then
    raise exception 'invalid delivery status' using errcode='22023';
  end if;
  update public.promotion_push_reservations
  set status=p_status,provider_message_id=left(p_provider_message_id,500),completed_at=now()
  where id=p_reservation_id and status='reserved' and channel='fcm'
  returning installation_id,fcm_token_sha256,fcm_token_generation into v_installation_id,v_token_sha256,v_token_generation;
  if found and p_status='invalid_token' and v_installation_id is not null and v_token_sha256 is not null then
    update public.fcm_installations
    set active=false
    where installation_id=v_installation_id
      and extensions.digest(convert_to(fcm_installation_id,'UTF8'),'sha256')=v_token_sha256
      and fcm_token_generation=v_token_generation;
  end if;
end; $$;
commit;
