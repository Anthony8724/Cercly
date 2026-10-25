-- No modifica roles existentes. Aplicar tras revisar en un entorno de pruebas.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
alter table public.usuarios enable row level security;
-- Los clientes también heredan PUBLIC. REVOKE de tabla elimina asimismo los
-- grants correspondientes de columna; después se concede solo SELECT/nombre.
revoke all on public.usuarios from public, anon, authenticated;
grant select on public.usuarios to authenticated;
grant update (nombre) on public.usuarios to authenticated;

-- Solo código de confianza puede modificar identidad o rol. SECURITY INVOKER
-- conserva current_user del RPC administrativo SECURITY DEFINER existente.
create or replace function public.proteger_rol_usuario()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') and
     (new.rol is distinct from old.rol or new.id is distinct from old.id) then
    raise exception 'No puedes modificar la identidad ni el rol';
  end if;
  return new;
end;
$$;

-- OAuth y SMS usan el mismo trigger de alta; nunca se copia un rol del cliente.
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger language plpgsql security definer set search_path = '' as $$
declare nombre_nuevo text;
begin
  nombre_nuevo := trim(coalesce(nullif(new.raw_user_meta_data->>'nombre', ''),
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'name', ''),
    nullif(split_part(new.email, '@', 1), ''), 'Usuario'));
  if char_length(nombre_nuevo) < 2 then nombre_nuevo := 'Usuario'; end if;
  insert into public.usuarios(id, nombre, rol)
    values (new.id, left(nombre_nuevo, 80), 'usuario')
    on conflict (id) do nothing;
  return new;
end;
$$;

-- Una solicitud/establecimiento pendiente no concede el panel comercial.
create or replace function public.convertir_en_propietario()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 'aprobado' then
    update public.usuarios set rol = 'propietario'
      where id = new.propietario_id and rol = 'usuario';
  end if;
  return new;
end;
$$;
drop trigger if exists convertir_en_propietario_trigger on public.establecimientos;
create trigger convertir_en_propietario_trigger
  after insert or update of estado, propietario_id on public.establecimientos
  for each row execute function public.convertir_en_propietario();

revoke execute on function public.crear_perfil_nuevo_usuario() from public, anon, authenticated;
revoke execute on function public.convertir_en_propietario() from public, anon, authenticated;
revoke execute on function public.proteger_rol_usuario() from public, anon, authenticated;
commit;
