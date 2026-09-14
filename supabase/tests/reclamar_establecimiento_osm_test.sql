-- Pruebas pgTAP del flujo de reclamacion OSM.

begin;

select plan(17);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'admin-reclamo@cercly.test',
    '', now(), '{}'::jsonb,
    '{"nombre":"Admin Reclamo"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'usuario-reclamo@cercly.test',
    '', now(), '{}'::jsonb,
    '{"nombre":"Usuario Reclamo"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'usuario-rechazo@cercly.test',
    '', now(), '{}'::jsonb,
    '{"nombre":"Usuario Rechazo"}'::jsonb, now(), now()
  );

update public.usuarios
set rol = 'administrador'
where id = '10000000-0000-0000-0000-000000000001';

insert into public.establecimientos (
  id, categoria_id, nombre, direccion, latitud, longitud, estado, fuente,
  osm_type, osm_id, datos_osm, estado_reclamo, publicable, ciudad, provincia,
  pais_codigo
)
select
  '20000000-0000-0000-0000-000000000001', id, 'OSM reclamable pgTAP',
  'Tulcán', 0.8116, -77.7172, 'aprobado', 'osm', 'node',
  900000000000000001, '{}'::jsonb, 'no_reclamado', true, 'Tulcán', 'Carchi',
  'EC'
from public.categorias where activa order by orden limit 1;

insert into public.establecimientos (
  id, propietario_id, categoria_id, nombre, direccion, latitud, longitud,
  estado, fuente, publicable, ciudad, provincia, pais_codigo
)
select
  '20000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001', id, 'Cercly pgTAP', 'Tulcán',
  0.8116, -77.7172, 'aprobado', 'cercly', true, 'Tulcán', 'Carchi', 'EC'
from public.categorias where activa order by orden limit 1;

insert into public.establecimientos (
  id, propietario_id, categoria_id, nombre, direccion, latitud, longitud,
  estado, fuente, osm_type, osm_id, datos_osm, estado_reclamo, publicable,
  ciudad, provincia, pais_codigo, reclamado_en
)
select
  '20000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000001', id, 'OSM reclamado pgTAP',
  'Tulcán', 0.8116, -77.7172, 'aprobado', 'osm', 'node',
  900000000000000003, '{}'::jsonb, 'reclamado', true, 'Tulcán', 'Carchi',
  'EC', now()
from public.categorias where activa order by orden limit 1;

select lives_ok(
  $$insert into public.solicitudes_establecimientos (
      id, solicitante_id, establecimiento_id, tipo, mensaje
    ) values (
      '30000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002',
      '20000000-0000-0000-0000-000000000001',
      'reclamar', 'Solicito administrar este establecimiento OSM.'
    )$$,
  'un OSM no reclamado acepta una solicitud de reclamo'
);

select throws_ok(
  $$insert into public.solicitudes_establecimientos (
      solicitante_id, establecimiento_id, tipo, mensaje
    ) values (
      '10000000-0000-0000-0000-000000000002',
      '20000000-0000-0000-0000-000000000002',
      'reclamar', 'Intento inválido sobre un negocio Cercly.'
    )$$,
  'P0001',
  'El establecimiento no está disponible para reclamo',
  'un establecimiento Cercly no puede reclamarse'
);

select throws_ok(
  $$insert into public.solicitudes_establecimientos (
      solicitante_id, establecimiento_id, tipo, mensaje
    ) values (
      '10000000-0000-0000-0000-000000000002',
      '20000000-0000-0000-0000-000000000003',
      'reclamar', 'Intento inválido sobre un OSM reclamado.'
    )$$,
  'P0001',
  'El establecimiento no está disponible para reclamo',
  'un OSM reclamado no acepta otra solicitud'
);

select throws_ok(
  $$insert into public.solicitudes_establecimientos (
      solicitante_id, establecimiento_id, tipo, mensaje
    ) values (
      '10000000-0000-0000-0000-000000000002',
      '20000000-0000-0000-0000-000000000001',
      'reclamar', 'Segunda solicitud pendiente duplicada.'
    )$$,
  '23505',
  'duplicate key value violates unique constraint "solicitud_pendiente_unica"',
  'el indice impide solicitudes pendientes duplicadas'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$select public.responder_solicitud_establecimiento(
      '30000000-0000-0000-0000-000000000001', 'aprobada', ''
    )$$,
  'el administrador puede aprobar el reclamo'
);

select is(
  (select propietario_id from public.establecimientos
   where id = '20000000-0000-0000-0000-000000000001'),
  '10000000-0000-0000-0000-000000000002'::uuid,
  'aprobar asigna al solicitante como propietario'
);

select is(
  (select estado_reclamo::text from public.establecimientos
   where id = '20000000-0000-0000-0000-000000000001'),
  'reclamado',
  'aprobar cambia el estado de reclamo sin verificarlo'
);

select ok(
  (select reclamado_en is not null and verificado_en is null
   from public.establecimientos
   where id = '20000000-0000-0000-0000-000000000001'),
  'aprobar registra reclamado_en y no verifica automaticamente'
);

select ok(
  (select estado = 'aprobada' and revisado_por =
      '10000000-0000-0000-0000-000000000001'::uuid
      and revisado_en is not null
   from public.solicitudes_establecimientos
   where id = '30000000-0000-0000-0000-000000000001'),
  'la solicitud aprobada conserva auditoria del administrador'
);

select is(
  (select rol::text from public.usuarios
   where id = '10000000-0000-0000-0000-000000000002'),
  'propietario',
  'el solicitante usuario pasa a rol propietario'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002',
  true
);

select ok(
  public.puede_gestionar_establecimiento(
    '20000000-0000-0000-0000-000000000001'
  ),
  'el nuevo propietario puede gestionar el establecimiento'
);

-- Un segundo OSM permite comprobar que el rechazo no altera su propiedad.
insert into public.establecimientos (
  id, categoria_id, nombre, direccion, latitud, longitud, estado, fuente,
  osm_type, osm_id, datos_osm, estado_reclamo, publicable, ciudad, provincia,
  pais_codigo
)
select
  '20000000-0000-0000-0000-000000000004', id, 'OSM rechazo pgTAP',
  'Tulcán', 0.8116, -77.7172, 'aprobado', 'osm', 'node',
  900000000000000004, '{}'::jsonb, 'no_reclamado', true, 'Tulcán', 'Carchi',
  'EC'
from public.categorias where activa order by orden limit 1;

insert into public.solicitudes_establecimientos (
  id, solicitante_id, establecimiento_id, tipo, mensaje
) values (
  '30000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000003',
  '20000000-0000-0000-0000-000000000004',
  'reclamar', 'Solicito administrar este segundo establecimiento.'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);

select lives_ok(
  $$select public.responder_solicitud_establecimiento(
      '30000000-0000-0000-0000-000000000002',
      'rechazada', 'No se presentó evidencia suficiente.'
    )$$,
  'el administrador puede rechazar un reclamo con motivo'
);

select ok(
  (select propietario_id is null
      and estado_reclamo = 'no_reclamado'
      and reclamado_en is null
   from public.establecimientos
   where id = '20000000-0000-0000-0000-000000000004'),
  'rechazar no altera propietario ni estado de reclamo'
);

select ok(
  (select estado = 'rechazada'
      and motivo_respuesta = 'No se presentó evidencia suficiente.'
      and revisado_por = '10000000-0000-0000-0000-000000000001'::uuid
      and revisado_en is not null
   from public.solicitudes_establecimientos
   where id = '30000000-0000-0000-0000-000000000002'),
  'el rechazo registra motivo y auditoria'
);

select is_empty(
  $$select id
    from public.establecimientos
    where id = '20000000-0000-0000-0000-000000000001'
      and fuente = 'osm'
      and estado_reclamo = 'no_reclamado'
      and propietario_id is null
      and estado = 'aprobado'
      and publicable$$,
  'el OSM aprobado deja de cumplir el filtro reclamable'
);

insert into public.solicitudes_establecimientos (
  id, solicitante_id, establecimiento_id, tipo, mensaje
) values (
  '30000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000003',
  '20000000-0000-0000-0000-000000000002',
  'acceso', 'Solicito colaborar en la administración.'
);

select lives_ok(
  $$select public.responder_solicitud_establecimiento(
      '30000000-0000-0000-0000-000000000003', 'aprobada', ''
    )$$,
  'la aprobación de acceso continúa disponible'
);

select ok(
  exists (
    select 1 from public.miembros_establecimiento
    where establecimiento_id = '20000000-0000-0000-0000-000000000002'
      and usuario_id = '10000000-0000-0000-0000-000000000003'
      and activo
  ),
  'aprobar acceso crea o reactiva la membresía'
);

select * from finish();

rollback;
