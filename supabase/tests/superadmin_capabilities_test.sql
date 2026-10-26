-- Solo base local aislada; identidades sintéticas y rollback.
begin;
select plan(30);
insert into auth.users(id,email,raw_user_meta_data) values
 ('b5900000-0000-0000-0000-000000000001','normal-b5@cercly.test','{"rol":"administrador"}'),
 ('b5900000-0000-0000-0000-000000000002','owner-b5@cercly.test','{}'),
 ('b5900000-0000-0000-0000-000000000003','admin-b5@cercly.test','{}'),
 ('b5900000-0000-0000-0000-000000000004','super-b5@cercly.test','{}');
update public.usuarios set rol='propietario' where id='b5900000-0000-0000-0000-000000000002';
update public.usuarios set rol='administrador' where id in
 ('b5900000-0000-0000-0000-000000000003','b5900000-0000-0000-0000-000000000004');
update auth.users set email_confirmed_at=now(),
  raw_app_meta_data='{"provider":"google","providers":["google"]}'::jsonb
where id in ('b5900000-0000-0000-0000-000000000003',
             'b5900000-0000-0000-0000-000000000004');
insert into public.establecimientos
 (id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado)
select 'b5910000-0000-0000-0000-000000000001',
 'b5900000-0000-0000-0000-000000000002',id,'Negocio sintético B5','Tulcán',0.8,-77.7,'pendiente'
from public.categorias limit 1;

select ok((select count(*)=0 from cercly_auth_private.superadministradores),
  'migración no asigna superadministradores');
select ok((select relrowsecurity from pg_class where oid=
  'cercly_auth_private.superadministradores'::regclass), 'RLS activo');
select ok(has_schema_privilege('authenticated','cercly_auth_private','USAGE'),
  'se conserva USAGE requerido por recuperar_mi_perfil');
select ok(not has_table_privilege('authenticated',
  'cercly_auth_private.superadministradores','INSERT'), 'cliente sin concesión directa');
select ok(not has_table_privilege('service_role',
  'cercly_auth_private.auditoria_superadministradores','INSERT'),
  'service_role de cliente sin inserción de auditoría');

set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000001',true);
select is((select rol from public.mis_capacidades()),'usuario','rol viene del servidor');
select ok((select not superadministrador and not administrador and not propietario
  from public.mis_capacidades()), 'metadatos falsos no elevan permisos');
select throws_ok($$insert into cercly_auth_private.superadministradores
  (usuario_id,otorgado_por,motivo) values
  (auth.uid(),auth.uid(),'autoasignación indebida')$$,
  '42501',null,'cliente no se autoasigna');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000002',true);
select ok((select propietario and not administrador and not superadministrador
  from public.mis_capacidades()),'propietario solo recibe su modo autorizado');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000003',true);
select ok((select administrador and not superadministrador and not propietario
  from public.mis_capacidades()),'administrador normal no es superadministrador');
reset role;

select throws_ok($$insert into cercly_auth_private.superadministradores
  (usuario_id,otorgado_por,motivo,referencia_aprobacion) values
  ('b5900000-0000-0000-0000-000000000003',
   'b5900000-0000-0000-0000-000000000003','Autoasignación administrativa',
   'B5-APPROVAL-SELF')$$,
  '42501',null,'ni el operador privilegiado se autoasigna');

insert into cercly_auth_private.superadministradores
  (usuario_id,otorgado_por,motivo,referencia_aprobacion) values
  ('b5900000-0000-0000-0000-000000000004',
   'b5900000-0000-0000-0000-000000000003','Concesión sintética de prueba local',
   'B5-APPROVAL-001');
select is((select count(*)::integer from cercly_auth_private.auditoria_superadministradores
  where usuario_id='b5900000-0000-0000-0000-000000000004'
    and actor_id='b5900000-0000-0000-0000-000000000003'
    and tipo_operacion='otorgamiento' and resultado='aplicada'),1,
  'otorgamiento registra actor, operación y resultado');
select throws_ok($$insert into cercly_auth_private.superadministradores
  (usuario_id,otorgado_por,motivo,referencia_aprobacion) values
  ('b5900000-0000-0000-0000-000000000004',
   'b5900000-0000-0000-0000-000000000002','Actor no administrador',
   'B5-APPROVAL-002')$$,'42501',null,'actor no autorizado no otorga capacidad');
select is((select count(*)::integer from cercly_auth_private.auditoria_superadministradores
  where actor_id='b5900000-0000-0000-0000-000000000002'),0,
  'fallo de otorgamiento no deja actor falso');
set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000004',true);
select ok((select superadministrador and administrador and not propietario
  from public.mis_capacidades()),'superadministrador usa administración sin propiedad universal');
select throws_ok($$select * from cercly_auth_private.superadministradores$$,
  '42501',null,'ni el superadministrador lee la tabla privada');
select throws_ok($$select * from cercly_auth_private.auditoria_superadministradores$$,
  '42501',null,'superadministrador tampoco lee auditoría');
select throws_ok($$insert into cercly_auth_private.auditoria_superadministradores
  (usuario_id,actor_id,tipo_operacion,motivo,referencia_aprobacion,resultado)
  values (auth.uid(),auth.uid(),'otorgamiento','falsificación desde cliente',
  'B5-FAKE-001','aplicada')$$,'42501',null,'cliente no falsifica auditoría');
reset role;

insert into public.miembros_establecimiento
  (establecimiento_id,usuario_id,rol,activo) values
  ('b5910000-0000-0000-0000-000000000001',
   'b5900000-0000-0000-0000-000000000004','editor',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000004',true);
select ok((select propietario from public.mis_capacidades()),
  'membresía concreta habilita modo propietario');
reset role;
update public.miembros_establecimiento set activo=false
  where usuario_id='b5900000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000004',true);
select ok((select not propietario from public.mis_capacidades()),
  'revocar membresía retira modo propietario');
reset role;

update auth.users set email='otro-correo-b5@cercly.test'
  where id='b5900000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000004',true);
select ok((select superadministrador from public.mis_capacidades()),
  'cambiar correo no altera autorización por UUID');
reset role;

update cercly_auth_private.superadministradores set activo=false,
  revocado_por='b5900000-0000-0000-0000-000000000003',
  revocado_en=now(), motivo_revocacion='Revocación sintética por prueba',
  referencia_revocacion='B5-REVOKE-001'
  where usuario_id='b5900000-0000-0000-0000-000000000004';
select is((select count(*)::integer from cercly_auth_private.auditoria_superadministradores
  where usuario_id='b5900000-0000-0000-0000-000000000004'
    and actor_id='b5900000-0000-0000-0000-000000000003'
    and tipo_operacion='revocacion' and resultado='aplicada'),1,
  'revocación registra actor, motivo y resultado');
select is((select referencia_revocacion from cercly_auth_private.superadministradores
  where usuario_id='b5900000-0000-0000-0000-000000000004'),
  'B5-REVOKE-001','la concesión conserva datos de revocación');
set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000004',true);
select ok((select not superadministrador and administrador from public.mis_capacidades()),
  'revocación tiene efecto en la siguiente consulta');
reset role;

select throws_ok($$update cercly_auth_private.superadministradores set activo=true
  where usuario_id='b5900000-0000-0000-0000-000000000004'$$,
  '42501',null,'reactivación no auditada prohibida');
select throws_ok($$update cercly_auth_private.auditoria_superadministradores
  set motivo='alterado' where usuario_id='b5900000-0000-0000-0000-000000000004'$$,
  '42501',null,'auditoría inmutable');
update public.usuarios set rol='usuario'
  where id='b5900000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','b5900000-0000-0000-0000-000000000004',true);
select ok((select not superadministrador and not administrador from public.mis_capacidades()),
  'capacidad no sobrevive a pérdida del rol administrador');
reset role;

select set_config('request.jwt.claim.sub','',true);
set local role anon;
select throws_ok($$select * from public.mis_capacidades()$$,
  '42501',null,'anónimo no ejecuta RPC');
reset role;
select ok(not has_function_privilege('anon','public.mis_capacidades()','EXECUTE'),
  'RPC no concede ejecución anónima');
delete from auth.users where id='b5900000-0000-0000-0000-000000000004';
select is((select count(*)::integer from cercly_auth_private.auditoria_superadministradores
  where usuario_id='b5900000-0000-0000-0000-000000000004'),2,
  'auditoría conserva otorgamiento y revocación tras borrar cuenta revocada');
select * from finish();
rollback;
