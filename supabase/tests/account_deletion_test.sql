-- Identidades sintéticas; la transacción revierte todos los fixtures.
begin;
select plan(23);

insert into auth.users(id,email,raw_user_meta_data,last_sign_in_at) values
 ('b7000000-0000-0000-0000-000000000001','delete-basic@cercly.test','{}',now()),
 ('b7000000-0000-0000-0000-000000000002','delete-owner@cercly.test','{}',now()),
 ('b7000000-0000-0000-0000-000000000003','delete-admin@cercly.test','{}',now()),
 ('b7000000-0000-0000-0000-000000000004','delete-storage@cercly.test','{}',now()),
 ('b7000000-0000-0000-0000-000000000005','delete-stale@cercly.test','{}',now() - interval '1 hour'),
 ('b7000000-0000-0000-0000-000000000006','delete-request@cercly.test','{}',now());
insert into auth.sessions(id,user_id,created_at)
 select id,id,case when id='b7000000-0000-0000-0000-000000000005'::uuid
   then now() - interval '1 hour' else now() end
 from auth.users where email like 'delete-%@cercly.test';
update public.usuarios set rol='administrador'
 where id='b7000000-0000-0000-0000-000000000003';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
 select 'b7100000-0000-0000-0000-000000000001',
 'b7000000-0000-0000-0000-000000000002',id,'Negocio de prueba','Tulcán',0,0,'aprobado',true
 from public.categorias limit 1;
insert into public.miembros_establecimiento(establecimiento_id,usuario_id)
 values ('b7100000-0000-0000-0000-000000000001',
 'b7000000-0000-0000-0000-000000000001');
insert into storage.objects(bucket_id,name,owner_id)
 values ('promociones-imagenes','b7000000-0000-0000-0000-000000000004/archivo.png',
 'b7000000-0000-0000-0000-000000000004');
insert into public.solicitudes_establecimientos(solicitante_id,establecimiento_id,mensaje,tipo)
 values ('b7000000-0000-0000-0000-000000000006',
 'b7100000-0000-0000-0000-000000000001','Solicitud sintética','acceso');

select ok(not has_schema_privilege('authenticated','cercly_account_private','USAGE'),
 'cliente no abre el esquema de solicitudes');
select ok(not has_function_privilege('authenticated','public.finalizar_eliminacion_cuenta(uuid)','EXECUTE'),
 'cliente no puede finalizar solicitudes ajenas');
select ok(not has_function_privilege('anon','public.solicitar_eliminacion_cuenta()','EXECUTE'),
 'anónimo no puede solicitar');

set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok('select public.solicitar_eliminacion_cuenta()', '28000',
 'Sesión inválida','sin sesión: rechazo');
select set_config('request.jwt.claim.sub','b7000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000001"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente',
 'usuario sin relaciones solicita borrado');
select is(public.solicitar_eliminacion_cuenta(),'pendiente',
 'solicitud duplicada es idempotente');
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000002"}',true);
select throws_ok('select public.solicitar_eliminacion_cuenta()', '42501',
 'Autenticación reciente requerida','sesión de otra identidad no verifica al titular');
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000001"}',true);
select throws_ok(
 $$select public.solicitar_eliminacion_cuenta('b7000000-0000-0000-0000-000000000003'::uuid)$$,
 '42883',null,'no existe parámetro para otra identidad');
select set_config('request.jwt.claim.sub','b7000000-0000-0000-0000-000000000005',true);
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000005"}',true);
select throws_ok('select public.solicitar_eliminacion_cuenta()', '42501',
 'Autenticación reciente requerida','sesión antigua exige ingreso reciente');
select set_config('request.jwt.claim.sub','b7000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000002"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision',
 'propietario con negocio queda en revisión');
select set_config('request.jwt.claim.sub','b7000000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000003"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision',
 'administrador queda en revisión sin cambiar rol');
select set_config('request.jwt.claim.sub','b7000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000004"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision',
 'objeto Storage bloquea borrado automático');
select set_config('request.jwt.claim.sub','b7000000-0000-0000-0000-000000000006',true);
select set_config('request.jwt.claims','{"session_id":"b7000000-0000-0000-0000-000000000006"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision',
 'solicitud con datos de negocio requiere revisión');
select throws_ok(
 $$select public.finalizar_eliminacion_cuenta('b7000000-0000-0000-0000-000000000003'::uuid)$$,
 '42501',null,'cliente no finaliza solicitud ajena');
reset role;

select is((select count(*)::integer from cercly_account_private.solicitudes_eliminacion),5,
 'solo cinco identidades elegibles tienen una fila');
select is((select count(*)::integer from cercly_account_private.solicitudes_eliminacion
 where usuario_id='b7000000-0000-0000-0000-000000000001'),1,
 'duplicado conserva una fila');
select is((select rol::text from public.usuarios
 where id='b7000000-0000-0000-0000-000000000003'),'administrador',
 'no cambia el rol administrativo');
select is((select count(*)::integer from auth.users
 where id='b7000000-0000-0000-0000-000000000001'),1,
 'solicitar no borra Auth ni simula borrado completo');
select ok(exists(select 1 from public.establecimientos
 where propietario_id='b7000000-0000-0000-0000-000000000002'),
 'conserva el negocio compartido');
-- El borrado Auth real lo realiza la Edge Function; aquí se valida únicamente
-- la cascada de PostgreSQL con identidad sintética.
delete from auth.users where id='b7000000-0000-0000-0000-000000000001';
select is((select count(*)::integer from public.usuarios
 where id='b7000000-0000-0000-0000-000000000001'),0,
 'borrar Auth elimina el perfil');
select is((select count(*)::integer from public.miembros_establecimiento
 where usuario_id='b7000000-0000-0000-0000-000000000001'),0,
 'borrar Auth elimina la membresía sin borrar el negocio');
select is((select count(*)::integer from public.establecimientos
 where id='b7100000-0000-0000-0000-000000000001'),1,
 'negocio compartido permanece');
select public.finalizar_eliminacion_cuenta('b7000000-0000-0000-0000-000000000001');
select is((select count(*)::integer from cercly_account_private.solicitudes_eliminacion
 where usuario_id='b7000000-0000-0000-0000-000000000001'),0,
 'finalización retira el identificador de la cola');
select * from finish();
rollback;
