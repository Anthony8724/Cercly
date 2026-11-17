-- Exclusivo para PostgreSQL desechable y rollback. Identidades sintéticas.
begin;
select plan(36);

insert into auth.users(id,email,raw_user_meta_data,last_sign_in_at) values
 ('f9100000-0000-0000-0000-000000000001','fcm-delete-clean@cercly.test','{}',now()),
 ('f9100000-0000-0000-0000-000000000002','fcm-delete-pref@cercly.test','{}',now()),
 ('f9100000-0000-0000-0000-000000000003','fcm-delete-device@cercly.test','{}',now()),
 ('f9100000-0000-0000-0000-000000000004','fcm-delete-reserve@cercly.test','{}',now()),
 ('f9100000-0000-0000-0000-000000000005','fcm-delete-owner@cercly.test','{}',now()),
 ('f9100000-0000-0000-0000-000000000006','fcm-delete-unknown@cercly.test','{}',now());
insert into auth.sessions(id,user_id,created_at)
select ('f9200000-0000-0000-0000-'||lpad(row_number() over(order by id)::text,12,'0'))::uuid,id,now()
from auth.users where id between 'f9100000-0000-0000-0000-000000000001'::uuid
 and 'f9100000-0000-0000-0000-000000000006'::uuid;

insert into public.push_preferences(user_id,enabled,consented_at,location_consent_at)
values('f9100000-0000-0000-0000-000000000002',false,null,null),
 ('f9100000-0000-0000-0000-000000000003',true,now(),now()),
 ('f9100000-0000-0000-0000-000000000004',true,now(),now());
insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform)
values ('f9300000-0000-0000-0000-000000000003','f9100000-0000-0000-0000-000000000003','fcm-delete-device-fixture-0003','android'),
 ('f9300000-0000-0000-0000-000000000004','f9100000-0000-0000-0000-000000000004','fcm-delete-device-fixture-0004','android');

insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select 'f9400000-0000-0000-0000-000000000001','f9100000-0000-0000-0000-000000000005',id,
 'Negocio protegido de prueba','Fixture local',0,0,'aprobado',true
from public.categorias where activa order by id limit 1;
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select 'f9400000-0000-0000-0000-000000000002','f9100000-0000-0000-0000-000000000005',id,
 'Negocio FCM de prueba','Fixture local',0,0,'aprobado',true
from public.categorias where activa order by id limit 1;
insert into public.promociones(id,establecimiento_id,titulo,descripcion,fecha_inicio,fecha_fin,radio_alerta_metros,activa)
values('f9500000-0000-0000-0000-000000000001','f9400000-0000-0000-0000-000000000002',
 'Reserva FCM de prueba','',now()-interval '1 hour',now()+interval '1 day',1500,true);
insert into public.promotion_push_reservations(user_id,installation_id,promotion_id,establishment_id,event_id,status)
values('f9100000-0000-0000-0000-000000000004','f9300000-0000-0000-0000-000000000004',
 'f9500000-0000-0000-0000-000000000001','f9400000-0000-0000-0000-000000000002',
 'f9600000-0000-0000-0000-000000000001','reserved');

-- Las referencias FCM exactas son cascadas de datos privados, no dependencias protegidas.
select ok(not cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000001'),
 'cuenta sin FCM conserva elegibilidad de eliminación');
select ok(not cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000002'),
 'preferencia push desactivada no exige revisión');
select ok(not cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000003'),
 'instalación FCM propia no exige revisión');
select ok(not cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000004'),
 'instalación y reserva FCM no exigen revisión');

set local role authenticated;
select set_config('request.jwt.claim.sub','f9100000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"f9200000-0000-0000-0000-000000000001"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente','cuenta sin FCM obtiene caso pendiente');
select is(public.solicitar_eliminacion_cuenta(),'pendiente','solicitudes repetidas son idempotentes');
reset role;
select lives_ok($$delete from auth.users where id='f9100000-0000-0000-0000-000000000001'$$,'eliminación simple permitida');
select ok(not exists(select 1 from auth.users where id='f9100000-0000-0000-0000-000000000001'),'identidad simple eliminada');
select lives_ok($$select public.finalizar_eliminacion_cuenta('f9100000-0000-0000-0000-000000000001')$$,'caso se cierra después de eliminar identidad');
select is((select count(*)::int from cercly_account_private.solicitudes_eliminacion where usuario_id='f9100000-0000-0000-0000-000000000001'),0,'no queda solicitud identificable');

set local role authenticated;
select set_config('request.jwt.claim.sub','f9100000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"f9200000-0000-0000-0000-000000000002"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente','preferencia desactivada usa el flujo normal');
select set_config('request.jwt.claim.sub','f9100000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"f9200000-0000-0000-0000-000000000003"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente','instalación propia usa el flujo normal');
select set_config('request.jwt.claim.sub','f9100000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"session_id":"f9200000-0000-0000-0000-000000000004"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente','reserva propia usa el flujo normal');
reset role;

select lives_ok($$delete from auth.users where id='f9100000-0000-0000-0000-000000000002'$$,'preferencia desactivada se elimina por cascada');
select is((select count(*)::int from public.push_preferences where user_id='f9100000-0000-0000-0000-000000000002'),0,'no queda preferencia del usuario borrado');
select lives_ok($$delete from auth.users where id='f9100000-0000-0000-0000-000000000003'$$,'instalación registrada se elimina por cascada');
select is((select count(*)::int from public.fcm_installations where user_id='f9100000-0000-0000-0000-000000000003'),0,'no queda FID asociado tras eliminar cuenta');
select is((select count(*)::int from public.push_preferences where user_id='f9100000-0000-0000-0000-000000000003'),0,'no queda consentimiento FCM tras eliminar cuenta');
select lives_ok($$delete from auth.users where id='f9100000-0000-0000-0000-000000000004'$$,'instalación y reserva relacionadas se eliminan');
select is((select count(*)::int from public.fcm_installations where user_id='f9100000-0000-0000-0000-000000000004'),0,'no queda instalación de cuenta borrada');
select is((select count(*)::int from public.promotion_push_reservations where user_id='f9100000-0000-0000-0000-000000000004'),0,'no queda historial de reservas de cuenta borrada');
select is((select count(*)::int from public.push_preferences where user_id='f9100000-0000-0000-0000-000000000004'),0,'no queda preferencia de cuenta borrada');
select is((select count(*)::int from public.promotion_push_reservations where installation_id='f9300000-0000-0000-0000-000000000004'),0,'no quedan relaciones de reserva con instalación borrada');

set local role authenticated;
select set_config('request.jwt.claim.sub','f9100000-0000-0000-0000-000000000005',true);
select set_config('request.jwt.claims','{"session_id":"f9200000-0000-0000-0000-000000000005"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision','propietario con establecimiento sigue requiriendo revisión');
reset role;
select throws_ok($$delete from auth.users where id='f9100000-0000-0000-0000-000000000005'$$,
 '42501','Supresion requiere caso autorizado sin dependencias','dependencia comercial protegida bloquea borrado');
select ok(exists(select 1 from auth.users where id='f9100000-0000-0000-0000-000000000005')
 and exists(select 1 from public.establecimientos where propietario_id='f9100000-0000-0000-0000-000000000005'),
 'identidad y negocio protegido permanecen intactos');

create table public.qa_unknown_auth_reference(user_id uuid references auth.users(id) on delete cascade);
select ok(cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000006'),
 'FK no clasificada conserva bloqueo incluso sin filas');
set local role authenticated;
select set_config('request.jwt.claim.sub','f9100000-0000-0000-0000-000000000006',true);
select set_config('request.jwt.claims','{"session_id":"f9200000-0000-0000-0000-000000000006"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision','FK desconocida deriva a revisión');
reset role;
select throws_ok($$delete from auth.users where id='f9100000-0000-0000-0000-000000000006'$$,
 '42501','Supresion requiere caso autorizado sin dependencias','FK desconocida no se omite por nombre o cascada');
select ok(exists(select 1 from auth.users where id='f9100000-0000-0000-0000-000000000006'),
 'cuenta con dependencia desconocida sigue intacta');
drop table public.qa_unknown_auth_reference;
create table public.qa_reused_fk_name (
  user_id uuid constraint usuarios_id_fkey references auth.users(id) on delete cascade
);
select ok(cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000006'),
 'FK desconocida con nombre permitido sigue bloqueando eliminación');
select ok(cercly_account_private.bloqueo_externo_supresion('f9100000-0000-0000-0000-000000000006'),
 'FK desconocida con nombre permitido sigue bloqueando supresión revisada');
drop table public.qa_reused_fk_name;
select ok(not cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000006'),
 'sin FK desconocida el detector conserva la clasificación FCM');
alter table public.push_preferences drop constraint push_preferences_user_id_fkey;
alter table public.push_preferences add constraint push_preferences_user_id_fkey
  foreign key(user_id) references auth.users(id) on delete no action;
select ok(cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000006'),
 'una FK FCM con acción distinta vuelve a bloquear la eliminación');
select ok(cercly_account_private.bloqueo_externo_supresion('f9100000-0000-0000-0000-000000000006'),
 'el bloqueo externo también rechaza una FK FCM alterada');
alter table public.push_preferences drop constraint push_preferences_user_id_fkey;
alter table public.push_preferences add constraint push_preferences_user_id_fkey
  foreign key(user_id) references auth.users(id) on delete cascade;
select ok(not cercly_account_private.tiene_dependencias('f9100000-0000-0000-0000-000000000006')
 and not cercly_account_private.bloqueo_externo_supresion('f9100000-0000-0000-0000-000000000006'),
 'restaurar la FK exacta retira el bloqueo sin ampliar la excepción');

select * from finish();
rollback;
