-- SOLO STAGING. Script operativo; no está en supabase/migrations y db push
-- no lo ejecuta. No ejecutarlo hasta autorización explícita del propietario.
-- Antes de ejecutar, verificar que el selector del dashboard indique el
-- proyecto dlajxviqhkdcqnmczhvr (Staging), nunca Production.
-- Ejecutar únicamente desde SQL Editor del dashboard como operador autorizado;
-- es una preparación administrativa fuera del cliente y no altera RLS.
-- Requiere exactamente una cuenta administradora confirmada distinta de la
-- cuenta de prueba. El negocio aprobado queda asociado a ese administrador;
-- el trigger no cambia su rol. Si no hay exactamente una, el script aborta.
-- Consulta previa de solo lectura: debe devolver exactamente una fila.
-- select u.id, u.rol from public.usuarios u
-- join auth.users a on a.id = u.id
-- where u.rol = 'administrador'
--   and a.email_confirmed_at is not null
--   and lower(a.email) <> 'cuenta-prueba@example.invalid';

begin;

do $fixture$
declare
  v_owner_id uuid;
  v_owner_count integer;
  v_test_user_id uuid;
  v_test_user_role public.rol_usuario;
  v_categoria_id uuid;
  v_subcategoria_id uuid;
  v_fixture_establecimiento constant uuid :=
    'f14a1f14-14b0-4b14-8a14-140000000001';
  v_fixture_promocion constant uuid :=
    'f14a1f14-14b0-4b14-8a14-140000000002';
begin
  select u.id, u.rol into strict v_test_user_id, v_test_user_role
  from auth.users a
  join public.usuarios u on u.id = a.id
  where lower(a.email) = 'cuenta-prueba@example.invalid'
    and a.email_confirmed_at is not null;

  select count(*) into v_owner_count
  from auth.users a
  join public.usuarios u on u.id = a.id
  where u.rol = 'administrador'
    and a.email_confirmed_at is not null
    and a.id <> v_test_user_id;

  if v_owner_count <> 1 then
    raise exception 'Se requiere exactamente un administrador confirmado, distinto de la cuenta de prueba; no se insertó ningún dato';
  end if;

  select u.id into strict v_owner_id
  from auth.users a
  join public.usuarios u on u.id = a.id
  where u.rol = 'administrador'
    and a.email_confirmed_at is not null
    and a.id <> v_test_user_id;

  select id into strict v_categoria_id
  from public.categorias
  where slug = 'comida-bebidas' and activa;

  select id into strict v_subcategoria_id
  from public.subcategorias
  where slug = 'restaurantes' and categoria_id = v_categoria_id and activa;

  if exists (
    select 1 from public.establecimientos
    where id = v_fixture_establecimiento
      and (nombre <> 'Cercly Test — Proximidad'
        or propietario_id <> v_owner_id)
  ) then
    raise exception 'El ID estable del establecimiento ya pertenece a otros datos';
  end if;

  if exists (
    select 1 from public.promociones
    where id = v_fixture_promocion
      and (titulo <> 'Promoción de prueba Cercly'
        or establecimiento_id <> v_fixture_establecimiento)
  ) then
    raise exception 'El ID estable de la promoción ya pertenece a otros datos';
  end if;

  if exists (
    select 1 from public.establecimientos
    where nombre = 'Cercly Test — Proximidad'
      and id <> v_fixture_establecimiento
  ) or exists (
    select 1 from public.promociones
    where titulo = 'Promoción de prueba Cercly'
      and id <> v_fixture_promocion
  ) then
    raise exception 'Ya existe un registro con el nombre reservado de prueba';
  end if;

  insert into public.establecimientos (
    id, propietario_id, categoria_id, nombre, descripcion, direccion,
    latitud, longitud, telefono_publico, ciudad, provincia, pais_codigo,
    fuente, estado, publicable
  ) values (
    v_fixture_establecimiento, v_owner_id, v_categoria_id,
    'Cercly Test — Proximidad',
    'Establecimiento sintético para probar alertas de proximidad en Staging.',
    'Campus principal UPEC, punto de prueba ficticio.',
    0.80525, -77.73434, '', 'Tulcán', 'Carchi', 'EC',
    'cercly', 'aprobado', true
  ) on conflict (id) do nothing;

  insert into public.establecimiento_categorias (
    establecimiento_id, subcategoria_id, es_principal
  ) values (
    v_fixture_establecimiento, v_subcategoria_id, true
  ) on conflict (establecimiento_id, subcategoria_id) do nothing;

  insert into public.promociones (
    id, establecimiento_id, titulo, descripcion, fecha_inicio, fecha_fin,
    radio_alerta_metros, activa
  ) values (
    v_fixture_promocion, v_fixture_establecimiento,
    'Promoción de prueba Cercly',
    'Contenido ficticio para validar alertas locales; sin descuento comercial.',
    now() - interval '5 minutes', now() + interval '14 days', 5000, true
  ) on conflict (id) do nothing;

  if not exists (
    select 1 from public.establecimientos e
    join public.promociones p on p.establecimiento_id = e.id
    where e.id = v_fixture_establecimiento
      and e.propietario_id = v_owner_id
      and e.categoria_id = v_categoria_id
      and e.nombre = 'Cercly Test — Proximidad'
      and e.latitud = 0.80525 and e.longitud = -77.73434
      and e.fuente = 'cercly'
      and e.estado = 'aprobado'
      and e.publicable
      and exists (
        select 1 from public.establecimiento_categorias ec
        where ec.establecimiento_id = e.id
          and ec.subcategoria_id = v_subcategoria_id
          and ec.es_principal
      )
      and p.id = v_fixture_promocion
      and p.titulo = 'Promoción de prueba Cercly'
      and p.radio_alerta_metros = 5000
      and p.activa
      and p.fecha_inicio <= now() and p.fecha_fin > now()
  ) then
    raise exception 'El conjunto de prueba no quedó completo y elegible';
  end if;

  if (select rol from public.usuarios where id = v_owner_id)
      is distinct from 'administrador'::public.rol_usuario
     or (select rol from public.usuarios where id = v_test_user_id)
      is distinct from v_test_user_role then
    raise exception 'El seed intentó alterar un rol; toda la transacción se revirtió';
  end if;
end;
$fixture$;

commit;

-- Limpieza manual futura: NO ejecutar durante las pruebas. Primero confirmar
-- ambos UUID y el nombre reservado; eliminar promoción antes del negocio.
-- Este seed usa una cuenta ya administradora, por lo que el trigger conserva
-- su rol. La limpieza solo elimina estas dos filas y no cambia perfiles.
--
-- begin;
-- delete from public.promociones
-- where id = 'f14a1f14-14b0-4b14-8a14-140000000002'
--   and establecimiento_id = 'f14a1f14-14b0-4b14-8a14-140000000001'
--   and titulo = 'Promoción de prueba Cercly';
-- delete from public.establecimientos
-- where id = 'f14a1f14-14b0-4b14-8a14-140000000001'
--   and nombre = 'Cercly Test — Proximidad'
--   and fuente = 'cercly';
-- commit;
