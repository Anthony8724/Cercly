begin;

select plan(12);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'b6600000-0000-0000-0000-000000000001',
   'authenticated', 'authenticated', 'registro-admin@cercly.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'b6600000-0000-0000-0000-000000000002',
   'authenticated', 'authenticated', 'registro-user@cercly.test', '', now(), '{}', '{}', now(), now());

update public.usuarios set rol = 'administrador'
where id = 'b6600000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b6600000-0000-0000-0000-000000000002', true);

select lives_ok($sql$
  insert into public.solicitudes_establecimientos
    (solicitante_id, tipo, mensaje, datos_propuestos)
  select auth.uid(), 'registro', 'Solicitud de registro', jsonb_build_object(
    'nombre', 'Costurería Test Bloque 6', 'categoria_id', c.id,
    'descripcion', 'Arreglos de ropa', 'direccion', 'Calle Bolívar, Tulcán',
    'telefono_publico', '', 'latitud', 0.8119, 'longitud', -77.7173,
    'horarios', jsonb_build_array(jsonb_build_object(
      'dia_semana', 1, 'apertura_minutos', 540, 'cierre_minutos', 1020,
      'cierra_al_dia_siguiente', false
    ))
  ) from public.categorias c where c.activa order by c.orden limit 1
$sql$, 'usuario autenticado crea solicitud nueva sin rol de propietario');

select throws_ok($sql$
  insert into public.establecimientos
    (propietario_id,categoria_id,nombre,direccion,latitud,longitud)
  select auth.uid(), c.id, 'Alta directa insegura', 'Tulcán', 0.8, -77.7
  from public.categorias c where c.activa limit 1
$sql$, '42501', null, 'el usuario no puede crear la ficha directamente ni asignarse propiedad');

select is(
  (select count(*)::integer from public.establecimientos
   where nombre = 'Costurería Test Bloque 6'),
  0,
  'el establecimiento pendiente no existe en la tabla pública'
);

select throws_ok($sql$
  insert into public.solicitudes_establecimientos
    (solicitante_id,tipo,mensaje,datos_propuestos)
  select auth.uid(),'registro','Coordenada inválida', jsonb_build_object(
    'nombre','Fuera de rango','categoria_id',c.id,'direccion','Tulcán',
    'latitud',91,'longitud',-77,'horarios','[]'::jsonb
  ) from public.categorias c where c.activa limit 1
$sql$, 'P0001', 'Las coordenadas están fuera de los límites válidos.',
  'el servidor valida los límites geográficos');

select throws_ok($sql$
  select public.responder_solicitud_establecimiento(
    (select id from public.solicitudes_establecimientos
     where tipo = 'registro' and solicitante_id = auth.uid()), 'aprobada', '')
$sql$, 'P0001', 'Solo un administrador autenticado puede responder solicitudes.',
  'el solicitante no puede autoaprobar');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b6600000-0000-0000-0000-000000000001', true);

select lives_ok($sql$
  update public.solicitudes_establecimientos set estado = 'aprobada'
  where tipo = 'registro'
$sql$, 'el administrador no puede saltarse la RPC de revisión');

select is(
  (select estado::text from public.solicitudes_establecimientos where tipo = 'registro'),
  'pendiente',
  'la política filtra la actualización directa del administrador'
);

select lives_ok($sql$
  select public.responder_solicitud_establecimiento(
    (select id from public.solicitudes_establecimientos
     where tipo = 'registro' and solicitante_id = 'b6600000-0000-0000-0000-000000000002'),
    'aprobada', ''
  )
$sql$, 'el administrador aprueba y crea la ficha en la misma transacción');

select ok(exists(
  select 1 from public.establecimientos
  where nombre = 'Costurería Test Bloque 6' and estado = 'aprobado'
    and publicable and propietario_id = 'b6600000-0000-0000-0000-000000000002'
    and latitud = 0.8119 and longitud = -77.7173
), 'la ficha aprobada queda visible con coordenadas y propietario autorizados');

select ok(exists(
  select 1 from public.horarios_establecimiento h
  join public.establecimientos e on e.id = h.establecimiento_id
  where e.nombre = 'Costurería Test Bloque 6'
    and h.dia_semana = 1 and h.apertura_minutos = 540 and h.cierre_minutos = 1020
), 'el horario propuesto se crea junto con la ficha aprobada');

select ok(exists(
  select 1 from public.solicitudes_establecimientos
  where tipo = 'registro' and estado = 'aprobada'
    and revisado_por = auth.uid() and revisado_en is not null
    and establecimiento_id is not null
), 'la decisión administrativa conserva revisor, fecha y ficha creada');

select is(
  (select rol::text from public.usuarios
   where id = 'b6600000-0000-0000-0000-000000000002'),
  'propietario',
  'la aprobación habilita el rol propietario después de la revisión');

select * from finish();
rollback;
