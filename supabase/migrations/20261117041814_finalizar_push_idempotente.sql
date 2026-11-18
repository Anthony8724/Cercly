-- Only the winning transition may affect an installation. Repeated or late
-- callbacks must not invalidate a device after a successful send.
begin;

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
declare
  v_installation_id uuid;
begin
  if p_status is null or p_status not in ('sent', 'failed', 'invalid_token') then
    raise exception 'invalid delivery status' using errcode = '22023';
  end if;
  update public.promotion_push_reservations
  set status = p_status,
      provider_message_id = left(p_provider_message_id, 500),
      completed_at = now()
  where id = p_reservation_id and status = 'reserved'
  returning installation_id into v_installation_id;
  if found and p_status = 'invalid_token' and v_installation_id is not null then
    update public.fcm_installations
    set active = false
    where installation_id = v_installation_id;
  end if;
end;
$function$;

revoke all on function public.finalizar_reserva_promocion_push(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.finalizar_reserva_promocion_push(uuid, text, text)
  to service_role;

commit;
