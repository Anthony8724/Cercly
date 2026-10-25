-- LOCAL, pendiente de revisión y autorización. Requiere las dos migraciones
-- de seguridad 20261017/20261018. No repara ni modifica perfiles en lote.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Nunca habilitar recuperación sobre permisos de perfil sin endurecer.
do $$
begin
  if has_any_column_privilege('authenticated', 'public.usuarios', 'INSERT')
     or has_column_privilege('authenticated', 'public.usuarios', 'rol', 'UPDATE')
     or has_column_privilege('authenticated', 'public.usuarios', 'id', 'UPDATE')
     or has_column_privilege('authenticated', 'public.usuarios', 'creado_en', 'UPDATE')
     or has_any_column_privilege('anon', 'public.usuarios', 'INSERT')
     or has_any_column_privilege('anon', 'public.usuarios', 'SELECT')
     or not (select relrowsecurity from pg_class where oid = 'public.usuarios'::regclass)
     or not exists (select 1 from pg_policy
       where polrelid = 'public.establecimientos'::regclass
         and polname = 'alta sin verificacion autoconcedida'
         and not polpermissive and polcmd = 'a') then
    raise exception 'Aplicar primero las migraciones de seguridad revisadas';
  end if;
  -- Dependencias de plataforma: no repararlas concediendo acceso a Auth.
  -- Una restauración sin ACL debe fallar antes de instalar una RPC inutilizable.
  if not has_schema_privilege('authenticated', 'auth', 'USAGE')
     or not has_function_privilege('authenticated', 'auth.uid()', 'EXECUTE') then
    raise exception using errcode = '42501',
      message = 'Prerrequisitos Auth incompletos: verificar restauración de permisos';
  end if;
end;
$$;

create schema if not exists cercly_auth_private;
revoke all on schema cercly_auth_private from public, anon, authenticated;
grant usage on schema cercly_auth_private to authenticated;

-- Helper interno sin privilegios propios. No concede roles desde metadatos.
create or replace function cercly_auth_private.insertar_perfil_basico(
  identidad uuid, metadatos jsonb, correo text
) returns void language plpgsql security invoker set search_path = '' as $$
declare nombre_nuevo text;
begin
  nombre_nuevo := coalesce(nullif(btrim(metadatos->>'nombre'), ''),
    nullif(btrim(metadatos->>'full_name'), ''),
    nullif(btrim(metadatos->>'name'), ''),
    nullif(btrim(split_part(correo, '@', 1)), ''), 'Usuario');
  if char_length(nombre_nuevo) < 2 then nombre_nuevo := 'Usuario'; end if;
  insert into public.usuarios(id, nombre, rol)
    values (identidad, left(nombre_nuevo, 80), 'usuario')
    on conflict (id) do nothing;
end;
$$;
revoke all on function cercly_auth_private.insertar_perfil_basico(uuid,jsonb,text)
  from public, anon, authenticated;

create or replace function public.crear_perfil_nuevo_usuario()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform cercly_auth_private.insertar_perfil_basico(new.id, new.raw_user_meta_data, new.email);
  return new;
exception when others then
  -- Sin SQLERRM, identidad, correo ni metadatos. Fallar revierte también el alta.
  raise log 'Cercly: fallo al crear perfil; SQLSTATE=%', SQLSTATE;
  raise exception using errcode = 'P0001', message = 'No se pudo crear el perfil';
end;
$$;
revoke all on function public.crear_perfil_nuevo_usuario() from public, anon, authenticated;
drop trigger if exists crear_perfil_despues_del_registro on auth.users;
create trigger crear_perfil_despues_del_registro after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- Única elevación necesaria para insertar sin abrir INSERT al cliente.
-- Esquema no expuesto; sin parámetros, SQL dinámico, UPDATE ni DELETE.
create or replace function cercly_auth_private.recuperar_perfil_actual()
returns void language plpgsql security definer set search_path = '' as $$
declare
  identidad uuid := auth.uid();
  datos record;
begin
  if identidad is null then
    raise exception using errcode = '28000', message = 'Sesión requerida';
  end if;
  select email, raw_user_meta_data into datos from auth.users where id = identidad;
  if not found then
    raise exception using errcode = '28000', message = 'Sesión inválida';
  end if;
  perform cercly_auth_private.insertar_perfil_basico(identidad, datos.raw_user_meta_data, datos.email);
exception
  when sqlstate '28000' then raise;
  when others then
    raise log 'Cercly: fallo al recuperar perfil; SQLSTATE=%', SQLSTATE;
    raise exception using errcode = 'P0001', message = 'No se pudo recuperar el perfil';
end;
$$;
revoke all on function cercly_auth_private.recuperar_perfil_actual() from public, anon, authenticated;
grant execute on function cercly_auth_private.recuperar_perfil_actual() to authenticated;

-- La API pública conserva SECURITY INVOKER: el resultado pasa por RLS.
-- Incluso un administrador recibe exclusivamente su propio perfil.
create or replace function public.recuperar_mi_perfil()
returns table(id uuid, rol text)
language plpgsql security invoker set search_path = '' as $$
begin
  perform cercly_auth_private.recuperar_perfil_actual();
  return query select u.id, u.rol::text from public.usuarios u where u.id = auth.uid();
end;
$$;
revoke all on function public.recuperar_mi_perfil() from public, anon, authenticated;
grant execute on function public.recuperar_mi_perfil() to authenticated;
commit;
