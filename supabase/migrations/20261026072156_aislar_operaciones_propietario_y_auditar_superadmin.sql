-- Controles estrictos para operaciones de panel propietario y auditoría
-- append-only de concesiones/revocaciones. No concede capacidades.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create or replace function public.puede_gestionar_como_propietario(
  p_establecimiento_id uuid
)
returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    exists(select 1 from public.establecimientos e
      where e.id = p_establecimiento_id and e.propietario_id = auth.uid())
    or exists(select 1 from public.miembros_establecimiento m
      where m.establecimiento_id = p_establecimiento_id
        and m.usuario_id = auth.uid() and m.activo)
  );
$$;
revoke all on function public.puede_gestionar_como_propietario(uuid)
  from public, anon;
grant execute on function public.puede_gestionar_como_propietario(uuid)
  to authenticated;

alter table cercly_auth_private.superadministradores
  add column if not exists referencia_aprobacion text;
alter table cercly_auth_private.superadministradores
  add column if not exists revocado_por uuid;
alter table cercly_auth_private.superadministradores
  add column if not exists revocado_en timestamptz;
alter table cercly_auth_private.superadministradores
  add column if not exists motivo_revocacion text;
alter table cercly_auth_private.superadministradores
  add column if not exists referencia_revocacion text;

create table if not exists cercly_auth_private.auditoria_superadministradores (
  id bigint generated always as identity primary key,
  usuario_id uuid not null,
  actor_id uuid not null,
  tipo_operacion text not null check (tipo_operacion in ('otorgamiento','revocacion')),
  fecha timestamptz not null default now(),
  motivo text not null check (length(trim(motivo)) between 10 and 500),
  referencia_aprobacion text not null check (length(trim(referencia_aprobacion)) between 6 and 200),
  resultado text not null check (resultado = 'aplicada'),
  ejecutor_db text not null default session_user,
  transaccion bigint not null default txid_current()
);
alter table cercly_auth_private.auditoria_superadministradores enable row level security;
revoke all on cercly_auth_private.auditoria_superadministradores
  from public, anon, authenticated, service_role;

create or replace function cercly_auth_private.validar_actor_superadmin(
  p_actor uuid, p_sujeto uuid, p_referencia text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_actor is null or p_actor = p_sujeto
    or p_referencia is null or length(trim(p_referencia)) < 6
    or not exists(select 1 from public.usuarios u
      where u.id = p_actor and u.rol = 'administrador')
    or not exists(select 1 from auth.users a
      where a.id = p_actor and a.email_confirmed_at is not null
        and coalesce(a.raw_app_meta_data->'providers','[]'::jsonb) ? 'google') then
    raise exception using errcode = '42501',
      message = 'Actor verificado, administrador y referencia aprobada requeridos';
  end if;
  if not exists(select 1 from public.usuarios u where u.id=p_sujeto
      and u.rol='administrador')
    or not exists(select 1 from auth.users a
      where a.id=p_sujeto and a.email_confirmed_at is not null
        and coalesce(a.raw_app_meta_data->'providers','[]'::jsonb) ? 'google') then
    raise exception using errcode = '42501',
      message = 'Titular superadministrador debe ser una identidad Google verificada y administradora';
  end if;
end;
$$;
revoke all on function cercly_auth_private.validar_actor_superadmin(uuid,uuid,text)
  from public, anon, authenticated, service_role;

create or replace function cercly_auth_private.auditar_cambios_superadmin()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  operacion text;
  actor uuid;
  referencia text;
  razon text;
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '42501', message = 'La concesión requiere revocación auditada';
  elsif tg_op = 'INSERT' then
    if not new.activo then
      raise exception using errcode = '22023', message = 'Crear primero una concesión activa';
    end if;
    if new.revocado_por is not null or new.revocado_en is not null
      or new.motivo_revocacion is not null or new.referencia_revocacion is not null then
      raise exception using errcode = '22023', message = 'Los datos de revocación solo se registran al revocar';
    end if;
    actor := new.otorgado_por;
    referencia := new.referencia_aprobacion;
    razon := new.motivo;
    operacion := 'otorgamiento';
    perform cercly_auth_private.validar_actor_superadmin(actor,new.usuario_id,referencia);
  else
    if (new.usuario_id,new.otorgado_por,new.motivo,new.otorgado_en,new.referencia_aprobacion)
      is distinct from
       (old.usuario_id,old.otorgado_por,old.motivo,old.otorgado_en,old.referencia_aprobacion)
      or not old.activo or new.activo
      or new.revocado_por is null or new.revocado_en is null
      or new.motivo_revocacion is null or new.referencia_revocacion is null then
      raise exception using errcode = '42501', message = 'Solo se permite revocación auditada e irreversible';
    end if;
    actor := new.revocado_por;
    referencia := new.referencia_revocacion;
    razon := new.motivo_revocacion;
    operacion := 'revocacion';
    perform cercly_auth_private.validar_actor_superadmin(actor,new.usuario_id,referencia);
    if length(trim(razon)) < 10 or length(trim(razon)) > 500 then
      raise exception using errcode = '22023', message = 'Motivo de revocación inválido';
    end if;
  end if;

  insert into cercly_auth_private.auditoria_superadministradores
    (usuario_id,actor_id,tipo_operacion,motivo,referencia_aprobacion,resultado)
  values (new.usuario_id,actor,operacion,razon,referencia,'aplicada');
  return new;
end;
$$;
revoke all on function cercly_auth_private.auditar_cambios_superadmin()
  from public, anon, authenticated, service_role;
drop trigger if exists auditar_cambios_superadmin
  on cercly_auth_private.superadministradores;
create trigger auditar_cambios_superadmin
  before insert or update or delete on cercly_auth_private.superadministradores
  for each row execute function cercly_auth_private.auditar_cambios_superadmin();

create or replace function cercly_auth_private.proteger_auditoria_superadmin()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception using errcode = '42501', message = 'Auditoría inmutable';
end;
$$;
revoke all on function cercly_auth_private.proteger_auditoria_superadmin()
  from public, anon, authenticated, service_role;
drop trigger if exists proteger_auditoria_superadmin
  on cercly_auth_private.auditoria_superadministradores;
create trigger proteger_auditoria_superadmin
  before update or delete on cercly_auth_private.auditoria_superadministradores
  for each row execute function cercly_auth_private.proteger_auditoria_superadmin();

create or replace function cercly_auth_private.proteger_superadmin_activo_en_borrado()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists(select 1 from cercly_auth_private.superadministradores s
      where s.usuario_id=old.id and s.activo) then
    raise exception using errcode = '42501',
      message = 'Debe revocar superadministración antes de eliminar la cuenta';
  end if;
  return old;
end;
$$;
revoke all on function cercly_auth_private.proteger_superadmin_activo_en_borrado()
  from public, anon, authenticated, service_role;
drop trigger if exists proteger_superadmin_activo_en_borrado on auth.users;
create trigger proteger_superadmin_activo_en_borrado before delete on auth.users
  for each row execute function cercly_auth_private.proteger_superadmin_activo_en_borrado();

commit;
