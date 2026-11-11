-- Compatibilidad focal, exclusivamente PostgreSQL desechable sin red.
begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data,created_at) select
 ('bd180000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 'isolation-local-'||i||'@cercly.test','{}',now() from generate_series(1,7)i;
update public.usuarios set rol='administrador' where id in
 ('bd180000-0000-0000-0000-000000000002','bd180000-0000-0000-0000-000000000004');
insert into auth.sessions(id,user_id,created_at) select
 ('bd180000-0000-0000-0000-'||lpad((i+90)::text,12,'0'))::uuid,id,now() from auth.users,
 lateral(select right(id::text,12)::int i)x where id in
 ('bd180000-0000-0000-0000-000000000001','bd180000-0000-0000-0000-000000000002','bd180000-0000-0000-0000-000000000003','bd180000-0000-0000-0000-000000000004','bd180000-0000-0000-0000-000000000006');
-- Solo H (3) y R (4) están inscritos; 5 tiene marca QA pero NO inscripción.
update auth.users set raw_app_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd180000-0000-0000-0000-000000000099"}}'
 where id in('bd180000-0000-0000-0000-000000000003','bd180000-0000-0000-0000-000000000004','bd180000-0000-0000-0000-000000000005');
insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado)
 select id,'bd180000-0000-0000-0000-000000000099',created_at,now()+interval '1 hour',true from auth.users
 where id in('bd180000-0000-0000-0000-000000000003','bd180000-0000-0000-0000-000000000004');
insert into cercly_account_private.politicas_supresion(codigo,referencia_decision,habilitada,ensayo_qa) values('POLITICA_QA','DECISION_SINTETICA',true,'bd180000-0000-0000-0000-000000000099');
set local role authenticated;
select set_config('request.jwt.claim.sub','bd180000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"bd180000-0000-0000-0000-000000000091"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente','normal no requiere inscripción QA');
select throws_ok($$select public.solicitar_eliminacion_cuenta_qa()$$,'42501','Identidad fuera del ensayo QA autorizado','normal no activa QA llamando otra RPC');
select throws_ok($$select public.solicitar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000006'::uuid)$$,'42883',null,'solicitud normal no acepta otro ID');
select throws_ok($$select cercly_account_private.validar_eliminacion_base('bd180000-0000-0000-0000-000000000006',true)$$,'42501',null,'modo interno no está disponible al cliente');
reset role;
select ok(public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000001'),'se corrige contraejemplo: normal legítimo validado');
select ok(not public.validar_eliminacion_cuenta_qa('bd180000-0000-0000-0000-000000000001'),'normal no usa la validación QA privilegiada');
-- Aprobación normal conserva autoridad y hecho, sin convertir el acto de
-- aprobar el caso actual en una dependencia imposible de resolver.
set local role authenticated;
select set_config('request.jwt.claim.sub','bd180000-0000-0000-0000-000000000006',true);
select set_config('request.jwt.claims','{"session_id":"bd180000-0000-0000-0000-000000000096"}',true);
select throws_ok($$select public.revisar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000001','aprobar')$$,'42501','Administrador autorizado con sesión reciente requerido','usuario ajeno no aprueba eliminación');
select throws_ok($$select public.revisar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000003','aprobar')$$,'42501','Administrador autorizado con sesión reciente requerido','sin permiso no se expone clasificación QA ajena');
select set_config('request.jwt.claim.sub','bd180000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"session_id":"bd180000-0000-0000-0000-000000000092"}',true);
select is(public.revisar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000001','aprobar'),'aprobada','administrador normal mantiene aprobación legítima');
select is(public.preparar_revision_privacidad('bd180000-0000-0000-0000-000000000001')->>'supresion_de_historial_habilitada','false','política QA activa no indica supresión normal habilitada');
reset role;
select ok(public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000001'),'aprobación mínima actual no provoca autobloqueo');
-- Fallo posterior al cierre mínimo: rollback también en la rama normal.
create function pg_temp.fallar_cierre_normal() returns trigger language plpgsql as $$
begin raise exception using errcode='P0001',message='Fallo sintetico normal'; end; $$;
create trigger zz_fallar_cierre_normal before delete on auth.users for each row
 when (old.id='bd180000-0000-0000-0000-000000000001') execute function pg_temp.fallar_cierre_normal();
select throws_ok($$delete from auth.users where id='bd180000-0000-0000-0000-000000000001'$$,'P0001','Fallo sintetico normal','fallo normal no produce eliminación parcial');
select is((select count(*)::int from cercly_account_private.auditoria_eliminacion where sujeto_id='bd180000-0000-0000-0000-000000000001'),1,'rollback normal conserva el vínculo antes del cierre');
select is((select count(*)::int from cercly_account_private.solicitudes_eliminacion where usuario_id='bd180000-0000-0000-0000-000000000001'),1,'rollback normal conserva el caso');
select is((select count(*)::int from cercly_account_private.resultados_supresion),0,'rollback normal no deja recibo falso');
drop trigger zz_fallar_cierre_normal on auth.users;
select lives_ok($$delete from auth.users where id='bd180000-0000-0000-0000-000000000001'$$,'Auth permite borrado normal verificado');
select is((select count(*)::int from public.usuarios where id='bd180000-0000-0000-0000-000000000001'),0,'perfil normal eliminado por CASCADE');
select is((select count(*)::int from auth.sessions where user_id='bd180000-0000-0000-0000-000000000001'),0,'sesiones normales retiradas');
select is((select count(*)::int from cercly_account_private.auditoria_eliminacion where accion='aprobar' and sujeto_id is null and actor_id='bd180000-0000-0000-0000-000000000002'),1,'aprobación conservada con sujeto desvinculado');
select is((select count(*)::int from cercly_account_private.solicitudes_eliminacion where usuario_id='bd180000-0000-0000-0000-000000000001'),0,'sin caso nominativo huérfano');
select throws_ok($$delete from auth.users where id='bd180000-0000-0000-0000-000000000006'$$,'42501','Supresion requiere caso autorizado sin dependencias','Auth normal sigue exigiendo solicitud válida');
-- QA no puede caer a normal, con o sin inscripción vigente.
set local role authenticated;
select set_config('request.jwt.claim.sub','bd180000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"bd180000-0000-0000-0000-000000000093"}',true);
select throws_ok($$select public.solicitar_eliminacion_cuenta()$$,'42501','Identidad QA requiere su ruta especifica','QA no usa normal como bypass');
select is(public.solicitar_eliminacion_cuenta_qa(),'pendiente','QA autorizado solicita por ruta específica');
reset role;
select ok(not public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000003'),'validación normal no procesa QA');
select ok(public.validar_eliminacion_cuenta_qa('bd180000-0000-0000-0000-000000000003'),'validación QA procesa sujeto autorizado');
update cercly_account_private.sujetos_qa_supresion set vence_en=now()-interval '1 second' where usuario_id='bd180000-0000-0000-0000-000000000003';
select ok(not public.validar_eliminacion_cuenta_qa('bd180000-0000-0000-0000-000000000003'),'ensayo vencido denegado');
select ok(not public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000003'),'vencimiento no habilita fallback normal');
select throws_ok($$delete from auth.users where id='bd180000-0000-0000-0000-000000000003'$$,'42501','Identidad fuera del ensayo QA autorizado','Auth no pierde guarda al separar rutas');
update cercly_account_private.sujetos_qa_supresion set vence_en=now()+interval '1 hour' where usuario_id='bd180000-0000-0000-0000-000000000003';
-- QArevisor no opera sobre casos normales por la RPC administrativa antigua.
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado) values('bd180000-0000-0000-0000-000000000006','revision');
set local role authenticated;
select set_config('request.jwt.claim.sub','bd180000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"session_id":"bd180000-0000-0000-0000-000000000094"}',true);
select throws_ok($$select public.revisar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000006','aprobar')$$,'42501','Revision QA requiere su ruta especifica','QA no cambia casos de titulares normales');
select throws_ok($$select public.preparar_revision_privacidad('bd180000-0000-0000-0000-000000000006')$$,'42501','Identidad fuera del ensayo QA autorizado','revisor QA no inventaría datos de casos normales');
reset role;
select is((select estado from cercly_account_private.solicitudes_eliminacion where usuario_id='bd180000-0000-0000-0000-000000000006'),'revision','caso ajeno intacto');
-- No se excluye del detector cualquier auditoría de aprobación: solo el
-- evento mínimo del caso actual. Otro caso histórico mantiene revisión.
update cercly_account_private.solicitudes_eliminacion set estado='aprobada' where usuario_id='bd180000-0000-0000-0000-000000000006';
insert into cercly_account_private.auditoria_eliminacion(solicitud_id,sujeto_id,actor_id,accion) values
 ('bd180000-0000-0000-0000-000000000088','bd180000-0000-0000-0000-000000000006','bd180000-0000-0000-0000-000000000002','aprobar');
select ok(not public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000006'),'historia de otro caso no es un bypass normal');
select throws_ok($$delete from auth.users where id='bd180000-0000-0000-0000-000000000006'$$,'42501','Supresion requiere caso autorizado sin dependencias','otra auditoría exige resolución de privacidad');
select is((select count(*)::int from cercly_account_private.auditoria_eliminacion where sujeto_id='bd180000-0000-0000-0000-000000000006'),1,'otra auditoría no fue redactada ni borrada');
-- Retirar el registro o falsificar user_metadata no abre la ruta normal.
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado) values('bd180000-0000-0000-0000-000000000005','pendiente');
select ok(not public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000005'),'marca de servidor sin inscripción no cae a normal');
select ok(not public.validar_eliminacion_cuenta_qa('bd180000-0000-0000-0000-000000000005'),'marca de servidor sola no autoriza QA');
update auth.users set raw_user_meta_data='{"cercly_qa_privacidad":{"autorizada":true,"ensayo_id":"bd180000-0000-0000-0000-000000000099"}}' where id='bd180000-0000-0000-0000-000000000007';
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado) values('bd180000-0000-0000-0000-000000000007','pendiente');
select ok(public.validar_eliminacion_cuenta('bd180000-0000-0000-0000-000000000007'),'user_metadata falso no convierte normal en QA');
select ok(not public.validar_eliminacion_cuenta_qa('bd180000-0000-0000-0000-000000000007'),'user_metadata no activa QA');
select lives_ok($$delete from auth.users where id='bd180000-0000-0000-0000-000000000003'$$,'Auth QA válido sigue permitido tras separación');
select ok(not exists(select 1 from auth.users where id in('bd180000-0000-0000-0000-000000000001','bd180000-0000-0000-0000-000000000003')),'solo sujetos con autorización propia fueron eliminados');
select ok(exists(select 1 from auth.users where id='bd180000-0000-0000-0000-000000000006'),'identidad ajena conservada');
select ok(not has_function_privilege('authenticated','public.validar_eliminacion_cuenta_qa(uuid)','EXECUTE') and not has_function_privilege('anon','public.solicitar_eliminacion_cuenta_qa()','EXECUTE'),'no se amplían permisos de servidor/anon');
select * from finish();
rollback;
