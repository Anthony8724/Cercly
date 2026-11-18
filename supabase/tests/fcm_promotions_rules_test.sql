-- Fixtures sintéticos. Corre únicamente contra el PostgreSQL local de Supabase.
begin;
select plan(31);

insert into auth.users(id, email, raw_user_meta_data, last_sign_in_at) values
  ('c8100000-0000-0000-0000-000000000001', 'fcm-owner@cercly.test', '{}', now()),
  ('c8100000-0000-0000-0000-000000000002', 'fcm-other@cercly.test', '{}', now());

insert into auth.sessions(id,user_id) select id,id from auth.users where email like 'fcm-%@cercly.test';

insert into public.establecimientos(
  id, propietario_id, categoria_id, nombre, direccion, latitud, longitud,
  estado, publicable
)
select 'c8200000-0000-0000-0000-000000000001',
       'c8100000-0000-0000-0000-000000000001', id,
       'FCM local uno', 'Fixture local', 0, 0, 'aprobado', true
from public.categorias where activa limit 1;
insert into public.establecimientos(
  id, propietario_id, categoria_id, nombre, direccion, latitud, longitud,
  estado, publicable
)
select 'c8200000-0000-0000-0000-000000000002',
       'c8100000-0000-0000-0000-000000000001', id,
       'FCM local dos', 'Fixture local', 0, 0, 'aprobado', true
from public.categorias where activa limit 1;

insert into public.promociones(
  id, establecimiento_id, titulo, descripcion, fecha_inicio, fecha_fin,
  radio_alerta_metros, activa
) values
  ('c8300000-0000-0000-0000-000000000001', 'c8200000-0000-0000-0000-000000000001', 'Oferta uno', '', now() - interval '1 hour', now() + interval '1 day', 1500, true),
  ('c8300000-0000-0000-0000-000000000002', 'c8200000-0000-0000-0000-000000000001', 'Oferta dos', '', now() - interval '1 hour', now() + interval '1 day', 1500, true),
  ('c8300000-0000-0000-0000-000000000003', 'c8200000-0000-0000-0000-000000000002', 'Oferta tres', '', now() - interval '1 hour', now() + interval '1 day', 1500, true);

select is((select column_default::text from information_schema.columns
  where table_schema='public' and table_name='push_preferences' and column_name='daily_limit'), '6',
  'frecuencia predeterminada es Normal: seis por ventana de 24 horas');
select is((select column_default::text from information_schema.columns
  where table_schema='public' and table_name='push_preferences' and column_name='radius_meters'), '1500',
  'radio predeterminado es 1.500 metros');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8100000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000001"}',true);
select throws_ok(
  $$select public.configurar_mis_alertas_push_promociones(true,false,6::smallint,null::smallint,null::smallint,1500::smallint)$$,
  '42501', 'location consent required for proximity push',
  'rechaza activar push si no hay consentimiento de ubicación');
select lives_ok(
  $$select public.configurar_mis_alertas_push_promociones(true,true,6::smallint,null::smallint,null::smallint,1500::smallint)$$,
  'acepta preferencias consentidas con frecuencia Normal');
reset role;
create temporary table fcm_consent_fixture as
  select consented_at from public.push_preferences
  where user_id='c8100000-0000-0000-0000-000000000001';
select is((select daily_limit::integer from public.push_preferences
  where user_id='c8100000-0000-0000-0000-000000000001'), 6,
  'guarda el límite Normal de seis');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8100000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000001"}',true);
select public.configurar_mis_alertas_push_promociones(true,true,3::smallint,null::smallint,null::smallint,1500::smallint);
reset role;
select is((select daily_limit::integer from public.push_preferences
  where user_id='c8100000-0000-0000-0000-000000000001'), 3,
  'acepta el límite Bajo de tres');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8100000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000001"}',true);
select public.configurar_mis_alertas_push_promociones(true,true,10::smallint,null::smallint,null::smallint,1500::smallint);
reset role;
select is((select daily_limit::integer from public.push_preferences
  where user_id='c8100000-0000-0000-0000-000000000001'), 10,
  'acepta el límite Alto de diez');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8100000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000001"}',true);
select public.configurar_mis_alertas_push_promociones(true,true,6::smallint,null::smallint,null::smallint,1500::smallint);
reset role;
select is((select consented_at from public.push_preferences
  where user_id='c8100000-0000-0000-0000-000000000001'),
  (select consented_at from fcm_consent_fixture),
  'los cambios de frecuencia conservan la fecha del consentimiento original');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c8100000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000001"}',true);
select lives_ok(
  $$select public.registrar_mi_instalacion_fcm('c8400000-0000-0000-0000-000000000001','fid-local-cercly-123456','android')$$,
  'registra el FID de la instalación propia');
select lives_ok(
  $$select public.registrar_mi_instalacion_fcm('c8400000-0000-0000-0000-000000000003','fid-local-cercly-device2','android')$$,
  'registra una segunda instalación del mismo usuario');
select set_config('request.jwt.claim.sub', 'c8100000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000002"}',true);
select public.configurar_mis_alertas_push_promociones(true,true,6::smallint,null::smallint,null::smallint,1500::smallint);
select throws_ok(
  $$select public.registrar_mi_instalacion_fcm('c8400000-0000-0000-0000-000000000001','fid-ajeno-cercly-123456','android')$$,
  '42501', 'installation belongs to another account',
  'no permite reclamar la instalación de otra cuenta');
reset role;

set local role service_role;
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000001', 0.0::double precision, 0.0::double precision, 20.0::double precision, now(), 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 1,
  'reserva una promoción activa dentro del radio y con posición precisa');
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000003',
  'c8500000-0000-0000-0000-000000000001', 0.0::double precision, 0.0::double precision, 20.0::double precision, now(), 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 0,
  'un event_id repetido es idempotente entre dos instalaciones');
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000002', 0.0::double precision, 0.0::double precision, 20.0::double precision, now(), 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 0,
  'no repite una promoción ya reservada');
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000003', 0.0::double precision, 0.0::double precision, 20.0::double precision, now() - interval '121 seconds', 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 0,
  'rechaza una ubicación con más de dos minutos');
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000004', 0.0::double precision, 0.0::double precision, 100.1::double precision, now(), 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 0,
  'rechaza una ubicación con precisión peor que 100 metros');
update public.promotion_push_reservations
set created_at=now() - interval '4 hours'
where user_id='c8100000-0000-0000-0000-000000000001'
  and promotion_id='c8300000-0000-0000-0000-000000000001';
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000005', 0.0::double precision, 0.0::double precision, 20.0::double precision, now(), 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 1,
  'libera el cooldown del negocio exactamente a las cuatro horas');
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001', 'c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000006', 0.0::double precision, 0.0::double precision, 20.0::double precision, now(), 0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)), 0,
  'aplica el intervalo global de quince minutos a otra promoción');
reset role;

select is((select count(*)::integer from public.fcm_installations
  where installation_id='c8400000-0000-0000-0000-000000000001'
    and user_id='c8100000-0000-0000-0000-000000000001'), 1,
  'el intento de otra cuenta no cambió el propietario de la instalación');

set local role service_role;
select lives_ok($$select public.finalizar_reserva_promocion_push(
  (select id from public.promotion_push_reservations where event_id='c8500000-0000-0000-0000-000000000001'),
  'sent','provider-original')$$, 'finaliza una reserva enviada');
select lives_ok($$select public.finalizar_reserva_promocion_push(
  (select id from public.promotion_push_reservations where event_id='c8500000-0000-0000-0000-000000000001'),
  'invalid_token',null)$$, 'ignora un resultado contradictorio posterior');
reset role;
select is((select status from public.promotion_push_reservations where event_id='c8500000-0000-0000-0000-000000000001'),
  'sent', 'un resultado posterior no cambia el estado final');
select is((select provider_message_id from public.promotion_push_reservations where event_id='c8500000-0000-0000-0000-000000000001'),
  'provider-original', 'un reintento conserva el identificador original');
select ok((select active from public.fcm_installations where installation_id='c8400000-0000-0000-0000-000000000001'),
  'un invalid_token tardío no desactiva la instalación');
set local role service_role;
select throws_ok($$select public.finalizar_reserva_promocion_push(null,null,null)$$,
  '22023','invalid delivery status','rechaza un estado nulo');
select lives_ok($$select public.finalizar_reserva_promocion_push(
  (select id from public.promotion_push_reservations where event_id='c8500000-0000-0000-0000-000000000005'),
  'invalid_token',null)$$, 'acepta token inválido en una reserva pendiente');
reset role;
select ok(not (select active from public.fcm_installations where installation_id='c8400000-0000-0000-0000-000000000001'),
  'un token inválido confirmado desactiva la instalación');
update public.fcm_installations set active=true where installation_id='c8400000-0000-0000-0000-000000000001';

delete from public.promotion_push_reservations where user_id='c8100000-0000-0000-0000-000000000001';
set local role service_role;
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000002','c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000010',0::double precision,0::double precision,20::double precision,now(),0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)),0,
  'no reserva usando una instalación perteneciente a otro usuario');
reset role;
update public.promociones set activa=false where id in
 ('c8300000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000002','c8300000-0000-0000-0000-000000000003');
set local role service_role;
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000011',0::double precision,0::double precision,20::double precision,now(),0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)),0,
  'no reserva promociones desactivadas');
reset role;
update public.promociones set activa=true,fecha_inicio=now()-interval '2 days',fecha_fin=now()-interval '1 day' where id in
 ('c8300000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000002','c8300000-0000-0000-0000-000000000003');
set local role service_role;
select is((select count(*)::integer from public.reservar_promocion_push_reciente(
  'c8100000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001',
  'c8500000-0000-0000-0000-000000000012',0::double precision,0::double precision,20::double precision,now(),0::smallint,'c8100000-0000-0000-0000-000000000001'::uuid)),0,
  'no reserva promociones caducadas');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','c8100000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"c8100000-0000-0000-0000-000000000001"}',true);
select public.configurar_mis_alertas_push_promociones(false,false,6::smallint,null::smallint,null::smallint,1500::smallint);
reset role;
select is((select count(*)::integer from public.fcm_installations where user_id='c8100000-0000-0000-0000-000000000001' and active),0,
  'retirar consentimiento desactiva las instalaciones asociadas');

select * from finish();
rollback;
