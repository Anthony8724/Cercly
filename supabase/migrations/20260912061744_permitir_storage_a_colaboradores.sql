-- Permite que propietarios, colaboradores activos y administradores
-- gestionen archivos asociados a un establecimiento.
--
-- Estructura esperada de las rutas:
-- usuario_id/establecimiento_id/nombre_archivo

create or replace function public.puede_gestionar_ruta_storage(
  nombre_objeto text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  partes_ruta text[];
  establecimiento_id_ruta uuid;
begin
  if nombre_objeto is null or trim(nombre_objeto) = '' then
    return false;
  end if;

  partes_ruta := storage.foldername(nombre_objeto);

  if coalesce(array_length(partes_ruta, 1), 0) < 2 then
    return false;
  end if;

  begin
    establecimiento_id_ruta := partes_ruta[2]::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  return public.puede_gestionar_establecimiento(
    establecimiento_id_ruta
  );
end;
$$;

revoke all
on function public.puede_gestionar_ruta_storage(text)
from public, anon;

grant execute
on function public.puede_gestionar_ruta_storage(text)
to authenticated;


-- Elimina únicamente políticas con estos nombres para permitir
-- volver a ejecutar la migración durante pruebas.

drop policy if exists
  "colaborador lee imagenes del establecimiento"
on storage.objects;

drop policy if exists
  "colaborador sube imagenes del establecimiento"
on storage.objects;

drop policy if exists
  "colaborador actualiza imagenes del establecimiento"
on storage.objects;

drop policy if exists
  "colaborador elimina imagenes del establecimiento"
on storage.objects;


-- Lectura de fotografías e imágenes de promociones.

create policy
  "colaborador lee imagenes del establecimiento"
on storage.objects
for select
to authenticated
using (
  bucket_id in (
    'establecimientos-imagenes',
    'promociones-imagenes'
  )
  and public.puede_gestionar_ruta_storage(name)
);


-- Subida de fotografías e imágenes de promociones.

create policy
  "colaborador sube imagenes del establecimiento"
on storage.objects
for insert
to authenticated
with check (
  bucket_id in (
    'establecimientos-imagenes',
    'promociones-imagenes'
  )
  and public.puede_gestionar_ruta_storage(name)
);


-- Actualización de fotografías e imágenes de promociones.

create policy
  "colaborador actualiza imagenes del establecimiento"
on storage.objects
for update
to authenticated
using (
  bucket_id in (
    'establecimientos-imagenes',
    'promociones-imagenes'
  )
  and public.puede_gestionar_ruta_storage(name)
)
with check (
  bucket_id in (
    'establecimientos-imagenes',
    'promociones-imagenes'
  )
  and public.puede_gestionar_ruta_storage(name)
);


-- Eliminación de fotografías e imágenes de promociones.

create policy
  "colaborador elimina imagenes del establecimiento"
on storage.objects
for delete
to authenticated
using (
  bucket_id in (
    'establecimientos-imagenes',
    'promociones-imagenes'
  )
  and public.puede_gestionar_ruta_storage(name)
);