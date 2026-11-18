-- Synthetic fixtures, only inside an isolated transaction.
begin;
select plan(34);
insert into auth.users(id,email,raw_user_meta_data) values
 ('e8100000-0000-4000-8000-000000000001','geo-one@cercly.test','{}'),
 ('e8100000-0000-4000-8000-000000000002','geo-two@cercly.test','{}'),
 ('e8100000-0000-4000-8000-000000000003','geo-three@cercly.test','{}');
insert into auth.sessions(id,user_id) select id,id from auth.users where email like 'geo-%@cercly.test';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
 select 'e8200000-0000-4000-8000-000000000001','e8100000-0000-4000-8000-000000000001',id,
 'Geo fixture','synthetic',0,0,'aprobado',true from public.categorias where activa limit 1;
insert into public.promociones(id,establecimiento_id,titulo,descripcion,fecha_inicio,fecha_fin,radio_alerta_metros,activa)
 values('e8300000-0000-4000-8000-000000000001','e8200000-0000-4000-8000-000000000001',
 'Geo fixture','',now()-interval '1 hour',now()+interval '1 day',1500,true);

select ok(not has_function_privilege('anon','public.reservar_promocion_geofencing(uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)','execute'), 'anonymous cannot reserve');
select ok(not has_schema_privilege('authenticated','cercly_notification_private','usage'), 'private schema unavailable to clients');
select ok(not has_function_privilege('authenticated','cercly_notification_private.reservar_comun(text,uuid,uuid,uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)','execute'), 'client cannot provide arbitrary user to internal function');
select ok(position('fcm_installation_id' in pg_get_function_result('public.reservar_promocion_geofencing(uuid,uuid,double precision,double precision,double precision,timestamptz,smallint)'::regprocedure))=0, 'geofence result excludes FCM identifier');

set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000001"}',true);
select throws_ok($$select * from cercly_notification_private.reservar_comun('geofencing','e8300000-0000-4000-8000-000000000001','e8100000-0000-4000-8000-000000000002',null,'e8500000-0000-4000-8000-000000000099',0::float8,0::float8,20::float8,now(),0::smallint)$$,
 '42501','permission denied for schema cercly_notification_private','client cannot reserve using another user identity');
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000001',0::float8,0::float8,20::float8,now(),0::smallint)),0,'no consent means no reservation');
select throws_ok($$select public.configurar_mis_alertas_geofencing(true,false)$$,'42501','location consent required','consent must be explicit');
select lives_ok($$select public.configurar_mis_alertas_geofencing(true,true)$$,'enable geofencing separately');
select public.configurar_mis_alertas_push_promociones(true,true,6::smallint,null::smallint,null::smallint,1500::smallint);
select public.configurar_mis_alertas_push_promociones(false,false,6::smallint,null::smallint,null::smallint,1500::smallint);
reset role;
select ok(not (select enabled from public.push_preferences where user_id='e8100000-0000-4000-8000-000000000001'),'enabling geofencing does not enable FCM');
select ok((select geofencing_enabled from public.push_preferences where user_id='e8100000-0000-4000-8000-000000000001'),'withdrawing FCM consent preserves separate geofencing consent');
select is((select count(*)::int from public.fcm_installations where user_id='e8100000-0000-4000-8000-000000000001'),0,'no FCM registration required');
insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform,authorized_session_id)
 values('e8400000-0000-4000-8000-000000000001','e8100000-0000-4000-8000-000000000001','synthetic-fid-without-consent','android','e8100000-0000-4000-8000-000000000001');
set local role service_role;
select is((select count(*)::int from public.reservar_promocion_push_reciente('e8100000-0000-4000-8000-000000000001','e8400000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000002',0::float8,0::float8,20::float8,now(),0::smallint,'e8100000-0000-4000-8000-000000000001'::uuid)),0,'FCM refuses when disabled');
reset role;
delete from public.fcm_installations where installation_id='e8400000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000001"}',true);
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000003',0::float8,0::float8,20::float8,now(),0::smallint)),1,'geofencing works without FCM');
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000003',0::float8,0::float8,20::float8,now(),0::smallint)),0,'event replay cannot authorize another delivery');
reset role;
select is((select channel from public.promotion_push_reservations where event_id='e8500000-0000-4000-8000-000000000003'),'geofencing','ledger identifies winning channel');
select set_config('qa.geo_reservation',(select id::text from public.promotion_push_reservations where event_id='e8500000-0000-4000-8000-000000000003'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000002"}',true);
select lives_ok($$select public.finalizar_reserva_geofencing(current_setting('qa.geo_reservation')::uuid,'failed')$$,'other user cannot finalize reservation');
reset role;
select is((select status from public.promotion_push_reservations where id=current_setting('qa.geo_reservation')::uuid),'reserved','other user did not change status');
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000001"}',true);
select lives_ok($$select public.finalizar_reserva_geofencing(current_setting('qa.geo_reservation')::uuid,'sent')$$,'owner finalizes local delivery');
select lives_ok($$select public.finalizar_reserva_geofencing(current_setting('qa.geo_reservation')::uuid,'failed')$$,'repeat finalization is harmless');
reset role;
select is((select status from public.promotion_push_reservations where id=current_setting('qa.geo_reservation')::uuid),'sent','repeat keeps first status');
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000002"}',true);
select public.configurar_mis_alertas_geofencing(true,true);
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000005',0::float8,0::float8,20::float8,now(),0::smallint)),1,'another user reserves independently');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000003"}',true);
select public.configurar_mis_alertas_push_promociones(true,true,6::smallint,null::smallint,null::smallint,1500::smallint);
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000007',0::float8,0::float8,20::float8,now(),0::smallint)),0,'FCM consent alone does not authorize geofencing');
select public.configurar_mis_alertas_geofencing(true,true);
reset role;
update public.promociones set fecha_inicio=now()-interval '2 days',fecha_fin=now()-interval '1 day' where id='e8300000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000003"}',true);
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000006',0::float8,0::float8,20::float8,now(),0::smallint)),0,'expired promotion cannot be reserved');
reset role;
select ok((select geofencing_enabled from public.push_preferences where user_id='e8100000-0000-4000-8000-000000000001'),'other account cannot change original consent');
update public.promociones set fecha_inicio=now()-interval '1 hour',fecha_fin=now()+interval '1 day' where id='e8300000-0000-4000-8000-000000000001';
delete from public.promotion_push_reservations where user_id='e8100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000001"}',true);
select throws_ok($$select public.finalizar_reserva_geofencing(null,'invalid_token')$$,'22023','invalid delivery status','geofence cannot report invalid FCM token');
select lives_ok($$select public.configurar_mis_alertas_geofencing(false,false)$$,'withdraw geofencing consent');
select is((select count(*)::int from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000004',0::float8,0::float8,20::float8,now(),0::smallint)),0,'revoked consent prevents reservation');
reset role;
select ok(not (select geofencing_enabled from public.push_preferences where user_id='e8100000-0000-4000-8000-000000000001'),'revocation persisted for authenticated user');
-- JWT subject and session must identify the same still-active session.
set local role authenticated;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select public.configurar_mis_alertas_geofencing(true,true)$$,'28000','active session required','missing session denied');
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000002"}',true);
select throws_ok($$select public.configurar_mis_alertas_geofencing(true,true)$$,'28000','active session required','another account session denied');
select set_config('request.jwt.claims','{"session_id":"e8100000-0000-4000-8000-000000000001"}',true);
select lives_ok($$select public.configurar_mis_alertas_geofencing(true,true)$$,'active session accepted');
reset role;
delete from auth.sessions where id='e8100000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.configurar_mis_alertas_geofencing(true,true)$$,'28000','active session required','deleted session rejected');
select throws_ok($$select public.finalizar_reserva_geofencing(null,'sent')$$,'28000','active session required','deleted session cannot finalize');
select throws_ok($$select * from public.reservar_promocion_geofencing('e8300000-0000-4000-8000-000000000001','e8500000-0000-4000-8000-000000000088',0::float8,0::float8,20::float8,now(),0::smallint)$$,'28000','active session required','deleted session cannot reserve');
reset role;
select * from finish();
rollback;
