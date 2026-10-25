-- LOCAL: aplicar solo después de las tres migraciones de autenticación pendientes.
-- La RPC registra una solicitud propia. Auth se elimina después desde la Edge
-- Function mediante admin.deleteUser; nunca desde el cliente ni desde esta RPC.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create schema if not exists cercly_account_private;
revoke all on schema cercly_account_private from public, anon, authenticated;

create table if not exists cercly_account_private.solicitudes_eliminacion (
  usuario_id uuid primary key,
  solicitud_id uuid not null unique default gen_random_uuid(),
  estado text not null check (estado in ('pendiente', 'revision')),
  creada_en timestamptz not null default now(),
  actualizada_en timestamptz not null default now()
);
alter table cercly_account_private.solicitudes_eliminacion enable row level security;
revoke all on cercly_account_private.solicitudes_eliminacion from public, anon, authenticated;

create or replace function public.solicitar_eliminacion_cuenta()
returns text language plpgsql security definer set search_path = '' as $$
declare
  identidad uuid := auth.uid();
  ultimo_ingreso timestamptz;
  necesita_revision boolean;
  resultado text;
begin
  if identidad is null then
    raise exception using errcode = '28000', message = 'Sesión requerida';
  end if;

  select last_sign_in_at into ultimo_ingreso
    from auth.users where id = identidad;
  if not found then
    raise exception using errcode = '28000', message = 'Sesión inválida';
  end if;
  if ultimo_ingreso is null or ultimo_ingreso < now() - interval '5 minutes' then
    raise exception using errcode = '42501', message = 'Autenticación reciente requerida';
  end if;

  -- Bloqueo conservador: los negocios compartidos y sus imágenes no se borran
  -- automáticamente. Tampoco las solicitudes con evidencias o mensajes.
  select not exists (select 1 from public.usuarios where id = identidad)
    or exists (select 1 from public.usuarios
      where id = identidad and rol = 'administrador')
    or exists (select 1 from public.establecimientos
      where propietario_id = identidad)
    or exists (select 1 from public.solicitudes_establecimientos
      where solicitante_id = identidad)
    or exists (select 1 from storage.objects
      where owner_id = identidad::text
        or (bucket_id in ('establecimientos-imagenes', 'promociones-imagenes')
          and name like identidad::text || '/%'))
    into necesita_revision;

  insert into cercly_account_private.solicitudes_eliminacion(usuario_id, estado)
    values (identidad, case when necesita_revision then 'revision' else 'pendiente' end)
    on conflict (usuario_id) do nothing;
  select estado into resultado
    from cercly_account_private.solicitudes_eliminacion
    where usuario_id = identidad for update;
  if necesita_revision and resultado <> 'revision' then
    update cercly_account_private.solicitudes_eliminacion
      set estado = 'revision', actualizada_en = now()
      where usuario_id = identidad;
    resultado := 'revision';
  end if;
  return resultado;
end;
$$;
revoke all on function public.solicitar_eliminacion_cuenta() from public, anon;
grant execute on function public.solicitar_eliminacion_cuenta() to authenticated;

-- Solo la Edge Function con credencial de servidor llama esta RPC después de
-- confirmar que admin.deleteUser eliminó la identidad Auth.
create or replace function public.finalizar_eliminacion_cuenta(p_usuario_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from cercly_account_private.solicitudes_eliminacion
    where usuario_id = p_usuario_id;
end;
$$;
revoke all on function public.finalizar_eliminacion_cuenta(uuid)
  from public, anon, authenticated;
grant execute on function public.finalizar_eliminacion_cuenta(uuid) to service_role;

commit;
