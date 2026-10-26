-- Capacidad adicional al rol administrador existente. No asigna ninguna cuenta.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create schema if not exists cercly_auth_private;

create table if not exists cercly_auth_private.superadministradores (
  id bigint generated always as identity primary key,
  usuario_id uuid not null,
  otorgado_por uuid not null,
  constraint superadministrador_no_autoasignacion check (otorgado_por <> usuario_id),
  motivo text not null check (length(trim(motivo)) between 10 and 500),
  otorgado_en timestamptz not null default now(),
  activo boolean not null default true
);
create unique index if not exists superadministradores_unico_activo
  on cercly_auth_private.superadministradores(usuario_id) where activo;
alter table cercly_auth_private.superadministradores enable row level security;
revoke all on cercly_auth_private.superadministradores from public, anon, authenticated;

-- La asignación futura exige una operación privilegiada, documentada y
-- vinculada al UUID de Auth; nunca se deduce del correo ni de user_metadata.
create or replace function public.mis_capacidades()
returns table (
  rol text,
  superadministrador boolean,
  propietario boolean,
  administrador boolean
)
language plpgsql stable security definer set search_path = '' as $$
declare
  identidad uuid := auth.uid();
  rol_actual public.rol_usuario;
begin
  if identidad is null or not exists (
    select 1 from auth.users where id = identidad
  ) then
    raise exception using errcode = '28000', message = 'Sesión inválida';
  end if;
  select u.rol into rol_actual from public.usuarios u where u.id = identidad;
  if rol_actual is null then
    raise exception using errcode = 'P0002', message = 'Perfil inexistente';
  end if;
  return query select
    rol_actual::text,
    rol_actual = 'administrador'::public.rol_usuario and exists (
      select 1 from cercly_auth_private.superadministradores s
      where s.usuario_id = identidad and s.activo
    ),
    exists(select 1 from public.establecimientos e
      where e.propietario_id = identidad)
      or exists(select 1 from public.miembros_establecimiento m
        where m.usuario_id = identidad and m.activo),
    rol_actual = 'administrador'::public.rol_usuario;
end;
$$;
revoke all on function public.mis_capacidades() from public, anon;
grant execute on function public.mis_capacidades() to authenticated;

commit;
