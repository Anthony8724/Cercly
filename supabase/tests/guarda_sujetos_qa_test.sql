-- Solo instancia local desechable. Ninguna identidad de STAGING/Production.
begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data,created_at) select
 ('bd150000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 'qa-guard-'||i||'@cercly.test','{}',now() from generate_series(1,6)i;
update public.usuarios set rol='administrador' where id='bd150000-0000-0000-0000-000000000001';
insert into auth.sessions(id,user_id,created_at) values('bd150000-0000-0000-0000-000000000090','bd150000-0000-0000-0000-000000000001',now());
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado)
 select id,'pendiente' from auth.users where id in('bd150000-0000-0000-0000-000000000002','bd150000-0000-0000-0000-000000000003','bd150000-0000-0000-0000-000000000004');
-- Una identidad clasificada QA sin inscripción NO se vuelve una cuenta normal.
update auth.users set raw_app_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd150000-0000-0000-0000-000000000099"}}'
 where id='bd150000-0000-0000-0000-000000000003';
select ok(not cercly_account_private.sujeto_qa_autorizado('bd150000-0000-0000-0000-000000000002'),'lista vacía deniega aun con solicitud pendiente');
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'no existe atajo por cuenta simple sin historial');
select throws_ok($$delete from auth.users where id='bd150000-0000-0000-0000-000000000003'$$,'42501','Identidad fuera del ensayo QA autorizado','Auth DELETE directo de identidad ajena denegado');
select is((select count(*)::int from auth.users where id='bd150000-0000-0000-0000-000000000003'),1,'identidad no autorizada se conserva');
select is((select count(*)::int from cercly_account_private.resultados_supresion),0,'denegación no deja recibo de éxito');
-- Una marca del servidor sola NO inscribe al usuario.
update auth.users set raw_app_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd150000-0000-0000-0000-000000000099"}}' where id in
 ('bd150000-0000-0000-0000-000000000001','bd150000-0000-0000-0000-000000000002','bd150000-0000-0000-0000-000000000004');
select ok(not cercly_account_private.sujeto_qa_autorizado('bd150000-0000-0000-0000-000000000002'),'app_metadata no sustituye UUID explícito');
-- Inscripción explícita SOLO de los dos sujetos y revisor del ensayo.
insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado)
 select id,'bd150000-0000-0000-0000-000000000099',created_at,now()+interval '1 hour',true from auth.users where id in
 ('bd150000-0000-0000-0000-000000000001','bd150000-0000-0000-0000-000000000002','bd150000-0000-0000-0000-000000000004');
select ok(cercly_account_private.sujeto_qa_autorizado('bd150000-0000-0000-0000-000000000002'),'UUID, fecha y marca de servidor coinciden');
select ok(not cercly_account_private.sujeto_qa_autorizado(null),'NULL denegado');
select ok(not cercly_account_private.sujeto_qa_autorizado('bd150000-0000-0000-0000-000000000002','bd150000-0000-0000-0000-000000000098'),'otro ensayo denegado');
update cercly_account_private.sujetos_qa_supresion set habilitado=false where usuario_id='bd150000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'revocación de inscripción impide eliminación simple');
update cercly_account_private.sujetos_qa_supresion set habilitado=true,vence_en=now()-interval '1 second' where usuario_id='bd150000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'inscripción vencida impide eliminación');
update cercly_account_private.sujetos_qa_supresion set vence_en=now()+interval '1 hour',auth_creado_en=auth_creado_en-interval '1 second' where usuario_id='bd150000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'fecha distinta rechaza reutilización de UUID');
update cercly_account_private.sujetos_qa_supresion q set auth_creado_en=a.created_at from auth.users a where q.usuario_id=a.id;
update auth.users set raw_app_meta_data='{}',raw_user_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd150000-0000-0000-0000-000000000099"}}' where id='bd150000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'user_metadata editable no falsifica autorización QA');
update auth.users set raw_app_meta_data='{"cercly_qa_privacidad":{"autorizada":"true","ensayo_id":"bd150000-0000-0000-0000-000000000099"}}' where id='bd150000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'texto true no sustituye booleano de servidor');
update auth.users set raw_app_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd150000-0000-0000-0000-000000000098"}}' where id='bd150000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'marca de otro ensayo no basta');
update auth.users set raw_app_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd150000-0000-0000-0000-000000000099"}}' where id='bd150000-0000-0000-0000-000000000002';
select ok(public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'cuenta QA simple autorizada sí supera puerta');
-- Política de otro ensayo, aunque habilitada, no puede usarse.
insert into cercly_account_private.politicas_supresion(codigo,referencia_decision,habilitada,ensayo_qa) values
 ('POLITICA_QA','DECISION_SINTETICA',true,'bd150000-0000-0000-0000-000000000098');
set local role authenticated;
select set_config('request.jwt.claim.sub','bd150000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"bd150000-0000-0000-0000-000000000090"}',true);
select throws_ok($$select public.autorizar_supresion_revisada_qa('bd150000-0000-0000-0000-000000000003','', 'POLITICA_QA',true)$$,'42501','Identidad fuera del ensayo QA autorizado','administrador no aprueba identidad ajena');
select throws_ok($$select public.revocar_plan_supresion_qa('bd150000-0000-0000-0000-000000000003')$$,'42501','Identidad fuera del ensayo QA autorizado','revocación no modifica casos ajenos');
select throws_ok($$select public.obtener_huella_revision_privacidad_qa('bd150000-0000-0000-0000-000000000003')$$,'42501','Identidad fuera del ensayo QA autorizado','no se inventaría identidad fuera de whitelist');
select throws_ok($$select public.autorizar_supresion_revisada_qa('bd150000-0000-0000-0000-000000000002',public.obtener_huella_revision_privacidad_qa('bd150000-0000-0000-0000-000000000002'),'POLITICA_QA',true)$$,'42501','Revision externa y politica aprobada sin bloqueos requeridas','política no permite cruce de ensayos');
select throws_ok($$insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en) values(auth.uid(),gen_random_uuid(),now(),now()+interval '1 hour')$$,'42501',null,'administrador autenticado no puede autoinscribirse');
reset role;
update cercly_account_private.politicas_supresion set ensayo_qa='bd150000-0000-0000-0000-000000000099';
set local role authenticated;
select lives_ok($$select public.autorizar_supresion_revisada_qa('bd150000-0000-0000-0000-000000000002',public.obtener_huella_revision_privacidad_qa('bd150000-0000-0000-0000-000000000002'),'POLITICA_QA',true)$$,'misma política, titular y revisor QA admitidos');
reset role;
select ok(public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'plan QA aprobado es válido');
update cercly_account_private.sujetos_qa_supresion set habilitado=false where usuario_id='bd150000-0000-0000-0000-000000000001';
select ok(not public.validar_eliminacion_cuenta_qa('bd150000-0000-0000-0000-000000000002'),'revocación QA del revisor invalida aprobación previa');
update cercly_account_private.sujetos_qa_supresion set habilitado=true where usuario_id='bd150000-0000-0000-0000-000000000001';
update cercly_account_private.sujetos_qa_supresion set habilitado=false where usuario_id='bd150000-0000-0000-0000-000000000002';
select throws_ok($$delete from auth.users where id='bd150000-0000-0000-0000-000000000002'$$,'42501','Identidad fuera del ensayo QA autorizado','Auth revalida inscripción al borrar aun con plan aprobado');
select is((select count(*)::int from auth.users where id='bd150000-0000-0000-0000-000000000002'),1,'denegación conserva la identidad QA');
update cercly_account_private.sujetos_qa_supresion set habilitado=true where usuario_id='bd150000-0000-0000-0000-000000000002';
select lives_ok($$delete from auth.users where id='bd150000-0000-0000-0000-000000000002'$$,'Auth elimina exclusivamente el titular QA autorizado');
select is((select count(*)::int from cercly_account_private.sujetos_qa_supresion where usuario_id='bd150000-0000-0000-0000-000000000002'),0,'sin registro QA huérfano después del borrado');
select is((select count(*)::int from auth.users where id='bd150000-0000-0000-0000-000000000003'),1,'identidad no inscrita permanece intacta al final');
select is((select estado from cercly_account_private.solicitudes_eliminacion where usuario_id='bd150000-0000-0000-0000-000000000003'),'pendiente','caso ajeno no cambia de estado');
select is((select count(*)::int from cercly_account_private.resultados_supresion),1,'solo eliminación autorizada genera recibo');
select ok(not has_table_privilege('anon','cercly_account_private.sujetos_qa_supresion','SELECT') and not has_table_privilege('authenticated','cercly_account_private.sujetos_qa_supresion','INSERT') and not has_table_privilege('service_role','cercly_account_private.sujetos_qa_supresion','UPDATE'),'registro privado sin privilegios de cliente o service_role');
select ok(not has_function_privilege('authenticated','cercly_account_private.sujeto_qa_autorizado(uuid,uuid)','EXECUTE'),'helper no invocable por cliente');
select * from finish();
rollback;
