-- Solo PostgreSQL local desechable, identidades sintéticas; rollback obligatorio.
begin;
select plan(32);
insert into auth.users(id,email,raw_user_meta_data)
 select ('bd110000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 'privacidad-local-'||i||'@cercly.test','{}' from generate_series(1,5)i;
-- Registro manual y explícito de identidades sintéticas; no pertenece a la migración.
do $fixture$ begin
 if to_regclass('cercly_account_private.sujetos_qa_supresion') is not null then
  update auth.users set created_at=coalesce(created_at,clock_timestamp()),
   raw_app_meta_data=coalesce(raw_app_meta_data,'{}')||jsonb_build_object('cercly_qa_privacidad',jsonb_build_object('autorizada',true,'ensayo_id','bd110000-0000-0000-0000-000000000099'))
   where id in ('bd110000-0000-0000-0000-000000000001'::uuid,'bd110000-0000-0000-0000-000000000002'::uuid,'bd110000-0000-0000-0000-000000000003'::uuid,'bd110000-0000-0000-0000-000000000004'::uuid,'bd110000-0000-0000-0000-000000000005'::uuid);
  insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado)
   select id,'bd110000-0000-0000-0000-000000000099',created_at,clock_timestamp()+interval '1 hour',true from auth.users where id in ('bd110000-0000-0000-0000-000000000001'::uuid,'bd110000-0000-0000-0000-000000000002'::uuid,'bd110000-0000-0000-0000-000000000003'::uuid,'bd110000-0000-0000-0000-000000000004'::uuid,'bd110000-0000-0000-0000-000000000005'::uuid);
 end if;
end $fixture$;
update public.usuarios set rol='administrador'
 where id in ('bd110000-0000-0000-0000-000000000001','bd110000-0000-0000-0000-000000000005');
insert into auth.sessions(id,user_id,created_at)
 values('bd110000-0000-0000-0000-000000000090','bd110000-0000-0000-0000-000000000001',now());
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado)
 values('bd110000-0000-0000-0000-000000000002','revision');
select ok(not has_function_privilege('anon','public.preparar_revision_privacidad(uuid)','EXECUTE'),'anónimo sin informe');
select ok(not has_function_privilege('service_role','public.preparar_revision_privacidad(uuid)','EXECUTE'),'clave servidor no sustituye revisión autenticada');
select ok(has_function_privilege('authenticated','public.preparar_revision_privacidad(uuid)','EXECUTE'),'entrada autenticada limitada');
select ok(not has_function_privilege('authenticated','public.validar_eliminacion_cuenta(uuid)','EXECUTE')
 and has_function_privilege('service_role','public.validar_eliminacion_cuenta(uuid)','EXECUTE'),'validación conserva ACL de servidor');
select ok(not has_function_privilege('authenticated','public.finalizar_eliminacion_cuenta(uuid)','EXECUTE')
 and not has_function_privilege('anon','public.finalizar_eliminacion_cuenta(uuid)','EXECUTE'),'finalización sigue privada');
set local role authenticated;
select set_config('request.jwt.claim.sub','bd110000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"bd110000-0000-0000-0000-000000000090"}',true);
select is(public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002')->>'correcciones','0','informe sin historial inventado');
select is(public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002')->>'decision_de_privacidad_pendiente','true','no inventa decisión legal');
select is(public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002')->>'supresion_de_historial_habilitada','false','no habilita redacción indiscriminada');
select ok(not (public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002') ?| array['email','nombre','antes','despues','mensaje']),'sin contenidos personales');
select throws_ok($$select public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000004')$$,'22023','Caso de privacidad inexistente','sin caso no hay exploración');
select throws_ok($$select public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000001')$$,'42501','Revisor autorizado con sesion reciente requerido','no se revisa a sí mismo');
select set_config('request.jwt.claim.sub','bd110000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002')$$,'42501','Revisor autorizado con sesion reciente requerido','usuario ajeno denegado');
select set_config('request.jwt.claim.sub','bd110000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002')$$,'42501','Revisor autorizado con sesion reciente requerido','sesión sin prueba reciente denegada');
reset role;
select is(public.validar_eliminacion_cuenta('bd110000-0000-0000-0000-000000000003'),false,'ausencia de solicitud no equivale a autorización');
select is(public.validar_eliminacion_cuenta('bd110000-0000-0000-0000-000000000002'),false,'revisión pendiente no autoriza borrar');
select throws_ok($$delete from auth.users where id='bd110000-0000-0000-0000-000000000003'$$,'42501','Supresion requiere caso autorizado sin dependencias','borrado Auth sin caso bloqueado');
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado)
 values('bd110000-0000-0000-0000-000000000004','pendiente');
select lives_ok($$delete from auth.users where id='bd110000-0000-0000-0000-000000000004'$$,'cuenta sin dependencias conserva borrado permitido');
select is((select count(*)::int from auth.users where id='bd110000-0000-0000-0000-000000000004'),0,'identidad simple eliminada localmente');
select lives_ok($$select public.finalizar_eliminacion_cuenta('bd110000-0000-0000-0000-000000000004')$$,'finalización solo después del borrado Auth');
select throws_ok($$insert into cercly_account_private.auditoria_eliminacion(solicitud_id,sujeto_id,actor_id,accion)
 select solicitud_id,usuario_id,'bd110000-0000-0000-0000-000000000004','aprobar'
 from cercly_account_private.solicitudes_eliminacion where usuario_id='bd110000-0000-0000-0000-000000000002'$$,
 '23503','Identidad de auditoria inexistente','historial privado no introduce actor eliminado');
select throws_ok($$select public.finalizar_eliminacion_cuenta('bd110000-0000-0000-0000-000000000002')$$,'42501','Identidad Auth todavia existente','no borra caso mientras vive la identidad');
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado)
 values('bd110000-0000-0000-0000-000000000003','pendiente');
insert into cercly_account_private.auditoria_eliminacion(solicitud_id,sujeto_id,actor_id,accion)
 select solicitud_id,usuario_id,'bd110000-0000-0000-0000-000000000003','aprobar'
 from cercly_account_private.solicitudes_eliminacion where usuario_id='bd110000-0000-0000-0000-000000000002';
select ok(cercly_account_private.tiene_dependencias('bd110000-0000-0000-0000-000000000003'),'actor solo en historial privado se detecta');
select throws_ok($$delete from auth.users where id='bd110000-0000-0000-0000-000000000003'$$,'42501','Supresion requiere caso autorizado sin dependencias','historial privado impide borrado silencioso del actor');
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
 select 'bd110000-0000-0000-0000-000000000010','bd110000-0000-0000-0000-000000000002',id,
 'Negocio sintético','Dirección sintética',0.8,-77.7,'aprobado',true from public.categorias where activa order by id limit 1;
set local role authenticated;
select set_config('request.jwt.claim.sub','bd110000-0000-0000-0000-000000000002',true);
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
 values('bd110000-0000-0000-0000-000000000020',auth.uid(),'bd110000-0000-0000-0000-000000000010','correccion','',
 '{"cambios":{"nombre":{"anterior":"Negocio sintético","nuevo":"Nombre corregido sintético"}}}');
select set_config('request.jwt.claim.sub','bd110000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.aplicar_correccion_establecimiento('bd110000-0000-0000-0000-000000000020','Revisión sintética')$$,'protección permite corrección y auditoría legítimas');
select set_config('request.jwt.claims','{"session_id":"bd110000-0000-0000-0000-000000000090"}',true);
select is(public.preparar_revision_privacidad('bd110000-0000-0000-0000-000000000002')->>'correcciones','1','informe registra dependencia real');
reset role;
select throws_ok($$delete from auth.users where id='bd110000-0000-0000-0000-000000000002'$$,'42501','Supresion requiere caso autorizado sin dependencias','titular con historial bloqueado dentro de Auth DELETE');
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado)
 values('bd110000-0000-0000-0000-000000000001','aprobada');
select throws_ok($$delete from auth.users where id='bd110000-0000-0000-0000-000000000001'$$,'42501','Supresion requiere caso autorizado sin dependencias','revisor con historial no desaparece por aprobación antigua');
select throws_ok($$insert into public.auditoria_moderacion_establecimientos(establecimiento_id,actor_id,ejecutor_db,estado_anterior,estado_nuevo,publicable_anterior,publicable_nuevo)
 values('bd110000-0000-0000-0000-000000000010','bd110000-0000-0000-0000-000000000004','postgres','pendiente','aprobado',false,true)$$,
 '23503','Identidad de auditoria inexistente','no se crea referencia a identidad ya eliminada');
select lives_ok($$insert into public.auditoria_moderacion_establecimientos(establecimiento_id,actor_id,ejecutor_db,estado_anterior,estado_nuevo,publicable_anterior,publicable_nuevo)
 values('bd110000-0000-0000-0000-000000000010',null,'postgres','pendiente','aprobado',false,true)$$,'operación técnica sin actor conserva representación');
select throws_ok($$update public.auditoria_moderacion_establecimientos set actor_id=null$$,'42501','Auditoria inmutable: requiere procedimiento de privacidad revisado','no se debilita inmutabilidad');
select is((select count(*)::int from public.correcciones_aplicadas where solicitud_id='bd110000-0000-0000-0000-000000000020'),1,'fallos conservan historial completo');
select ok(not exists(select 1 from pg_proc p cross join (values('anon'),('authenticated'),('service_role')) r(rol)
 where p.oid in ('cercly_account_private.proteger_supresion_auth()'::regprocedure,'cercly_account_private.proteger_identidades_historial()'::regprocedure)
 and has_function_privilege(r.rol,p.oid,'EXECUTE')),'triggers no invocables desde clientes');
select * from finish();
rollback;
