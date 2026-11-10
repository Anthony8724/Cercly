begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('bd130000-0000-0000-0000-000000000001','reviewer@cercly.test','{}'),
 ('bd130000-0000-0000-0000-000000000002','subject@cercly.test','{}'),
 ('bd130000-0000-0000-0000-000000000003','outsider@cercly.test','{}'),
 ('bd130000-0000-0000-0000-000000000004','simple@cercly.test','{}');
-- Registro manual y explícito de identidades sintéticas; no pertenece a la migración.
do $fixture$ begin
 if to_regclass('cercly_account_private.sujetos_qa_supresion') is not null then
  update auth.users set created_at=coalesce(created_at,clock_timestamp()),
   raw_app_meta_data=coalesce(raw_app_meta_data,'{}')||jsonb_build_object('cercly_qa_privacidad',jsonb_build_object('autorizada',true,'ensayo_id','bd130000-0000-0000-0000-000000000099'))
   where id in ('bd130000-0000-0000-0000-000000000001'::uuid,'bd130000-0000-0000-0000-000000000002'::uuid,'bd130000-0000-0000-0000-000000000003'::uuid,'bd130000-0000-0000-0000-000000000004'::uuid);
  insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado)
   select id,'bd130000-0000-0000-0000-000000000099',created_at,clock_timestamp()+interval '1 hour',true from auth.users where id in ('bd130000-0000-0000-0000-000000000001'::uuid,'bd130000-0000-0000-0000-000000000002'::uuid,'bd130000-0000-0000-0000-000000000003'::uuid,'bd130000-0000-0000-0000-000000000004'::uuid);
 end if;
end $fixture$;
update public.usuarios set rol='administrador' where id='bd130000-0000-0000-0000-000000000001';
insert into auth.sessions(id,user_id,created_at) values('bd130000-0000-0000-0000-000000000090','bd130000-0000-0000-0000-000000000001',now());
insert into auth.sessions(id,user_id,created_at) values('bd130000-0000-0000-0000-000000000091','bd130000-0000-0000-0000-000000000002',now());
insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado) values
 ('bd130000-0000-0000-0000-000000000002','revision'),('bd130000-0000-0000-0000-000000000004','pendiente');
select ok(not exists(select 1 from cercly_account_private.politicas_supresion),'ninguna retención ni política habilitada automáticamente');
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
 select 'bd130000-0000-0000-0000-000000000010','bd130000-0000-0000-0000-000000000003',id,
 'Negocio compartido','Dirección compartida',0.8,-77.7,'aprobado',true from public.categorias where activa order by id limit 1;
-- El sujeto es colaborador, no se elimina la ficha del otro propietario.
insert into public.miembros_establecimiento(establecimiento_id,usuario_id,rol,activo)
 values('bd130000-0000-0000-0000-000000000010','bd130000-0000-0000-0000-000000000002','editor',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','bd130000-0000-0000-0000-000000000002',true);
select ok(public.identidad_cercly_existente(),'identidad existente conserva permisos');
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
 values('bd130000-0000-0000-0000-000000000020',auth.uid(),'bd130000-0000-0000-0000-000000000010','correccion','Motivo personal 123',
 '{"cambios":{"nombre":{"anterior":"Negocio compartido","nuevo":"Nombre corregido compartido"}}}');
select set_config('request.jwt.claim.sub','bd130000-0000-0000-0000-000000000001',true);
select public.aplicar_correccion_establecimiento('bd130000-0000-0000-0000-000000000020','Firma personal de revisión');
select set_config('request.jwt.claim.sub','bd130000-0000-0000-0000-000000000002',true);
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
 values('bd130000-0000-0000-0000-000000000021',auth.uid(),'bd130000-0000-0000-0000-000000000010','correccion','Contenido personal pendiente',
 '{"cambios":{"nombre":{"anterior":"Nombre corregido compartido","nuevo":"Otro nombre propuesto"}}}');
reset role;
insert into public.auditoria_moderacion_establecimientos(establecimiento_id,actor_id,ejecutor_db,estado_anterior,estado_nuevo,publicable_anterior,publicable_nuevo)
 values('bd130000-0000-0000-0000-000000000010','bd130000-0000-0000-0000-000000000002','postgres','pendiente','aprobado',false,true);
insert into cercly_account_private.auditoria_eliminacion(solicitud_id,sujeto_id,actor_id,accion)
 select solicitud_id,usuario_id,'bd130000-0000-0000-0000-000000000001','aprobar' from cercly_account_private.solicitudes_eliminacion where usuario_id='bd130000-0000-0000-0000-000000000002';
select ok(not public.validar_eliminacion_cuenta_qa('bd130000-0000-0000-0000-000000000002'),'sin revisión no autoriza borrar historial');
select throws_ok($$update public.auditoria_moderacion_establecimientos set actor_id=null$$,'42501','Auditoria inmutable: requiere procedimiento de privacidad revisado','sin capacidad privada no hay bypass aun como postgres');
select ok(not has_function_privilege('service_role','public.autorizar_supresion_revisada_qa(uuid,text,text,boolean)','EXECUTE'),'servidor no sustituye revisor autenticado');
select ok(not has_function_privilege('anon','public.autorizar_supresion_revisada_qa(uuid,text,text,boolean)','EXECUTE'),'anónimo sin aprobación');
select ok(not has_table_privilege('authenticated','cercly_account_private.planes_supresion','SELECT'),'no exposición de planes');
select ok(not has_table_privilege('authenticated','cercly_account_private.ejecuciones_supresion','INSERT'),'no se puede falsificar capacidad privada');
select ok(not has_table_privilege('service_role','cercly_account_private.politicas_supresion','INSERT'),'sin habilitación jurídica por API');
set local role authenticated;
select set_config('request.jwt.claim.sub','bd130000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.autorizar_supresion_revisada_qa('bd130000-0000-0000-0000-000000000002','', 'POLITICA_QA',true)$$,'42501','Revisor autorizado con sesion reciente requerido','usuario ajeno no aprueba');
select set_config('request.jwt.claim.sub','bd130000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"bd130000-0000-0000-0000-000000000090"}',true);
select throws_ok($$select public.autorizar_supresion_revisada_qa('bd130000-0000-0000-0000-000000000002','', 'POLITICA_QA',true)$$,'42501','Revision externa y politica aprobada sin bloqueos requeridas','sin política jurídica explícita no se autoriza');
reset role;
insert into cercly_account_private.politicas_supresion(codigo,referencia_decision,habilitada,ensayo_qa) values('POLITICA_QA','DECISION_SINTETICA',true,'bd130000-0000-0000-0000-000000000099');
set local role authenticated;
select throws_ok($$select public.autorizar_supresion_revisada_qa('bd130000-0000-0000-0000-000000000002','', 'POLITICA_QA',true)$$,'PT409','Inventario de privacidad obsoleto','huella falsa rechazada');
select throws_ok($$select public.autorizar_supresion_revisada_qa('bd130000-0000-0000-0000-000000000002','', 'POLITICA_QA',false)$$,'42501','Revision externa y politica aprobada sin bloqueos requeridas','revisión de textos externos obligatoria');
select lives_ok($$select public.autorizar_supresion_revisada_qa('bd130000-0000-0000-0000-000000000002',public.obtener_huella_revision_privacidad_qa('bd130000-0000-0000-0000-000000000002'),'POLITICA_QA',true)$$,'plan autorizado con huella exacta');
reset role;
select ok(public.validar_eliminacion_cuenta_qa('bd130000-0000-0000-0000-000000000002'),'plan vigente permite únicamente supresión revisada');
select is(public.preparar_revision_privacidad('bd130000-0000-0000-0000-000000000002')->>'supresion_de_historial_habilitada','true','diagnóstico refleja política sintética habilitada');
select is(public.preparar_revision_privacidad('bd130000-0000-0000-0000-000000000002')->>'decision_de_privacidad_pendiente','false','diagnóstico distingue plan revisado de caso pendiente');
select throws_ok($$insert into cercly_account_private.planes_supresion select * from cercly_account_private.planes_supresion$$,'23505',null,'sin aprobaciones duplicadas');
-- Cambiar la ficha de la política invalida de verdad el plan, sin reparaciones.
update cercly_account_private.politicas_supresion set habilitada=false;
select ok(not public.validar_eliminacion_cuenta_qa('bd130000-0000-0000-0000-000000000002'),'revocación de política invalida plan');
update cercly_account_private.politicas_supresion set habilitada=true;
update public.usuarios set rol='usuario' where id='bd130000-0000-0000-0000-000000000001';
select ok(not public.validar_eliminacion_cuenta_qa('bd130000-0000-0000-0000-000000000002'),'revisor sin rol no conserva aprobación');
update public.usuarios set rol='administrador' where id='bd130000-0000-0000-0000-000000000001';
-- Fixture temporal: se prueba el bloqueo y se revierte la inserción.
create function pg_temp.comprobar_storage_qa()
returns boolean language plpgsql as $qa$
declare bloqueo_confirmado boolean;
begin
  begin
    insert into storage.objects(id,name,owner_id)
    values(
      'bd130000-0000-0000-0000-000000000060',
      'documento-qa',
      'bd130000-0000-0000-0000-000000000002'
    );

    bloqueo_confirmado :=
      not public.validar_eliminacion_cuenta_qa(
        'bd130000-0000-0000-0000-000000000002'
      );

    raise exception using
      errcode='PZ001',
      message='Revertir fixture temporal Storage';

  exception when sqlstate 'PZ001' then
    return bloqueo_confirmado;
  end;
end;
$qa$;

select ok(
  pg_temp.comprobar_storage_qa(),
  'Storage posterior bloquea borrado sin tocar archivos'
);
-- Una modificación posterior no se ignora ni se incluye automáticamente en el plan.
insert into public.auditoria_moderacion_establecimientos(establecimiento_id,actor_id,ejecutor_db,estado_anterior,estado_nuevo,publicable_anterior,publicable_nuevo)
 values('bd130000-0000-0000-0000-000000000010','bd130000-0000-0000-0000-000000000002','postgres','aprobado','rechazado',true,false);
select ok(not public.validar_eliminacion_cuenta_qa('bd130000-0000-0000-0000-000000000002'),'nuevo historial invalida huella');
select throws_ok($$delete from auth.users where id='bd130000-0000-0000-0000-000000000002'$$,'42501','Supresion requiere caso autorizado sin dependencias','Auth DELETE obsoleto no altera datos');
select is((select count(*)::int from public.correcciones_aplicadas where not datos_suprimidos),1,'fallo anterior conserva auditoría');
-- La revocación es autenticada, no una reparación manual del catálogo.
set local role authenticated;
select lives_ok($$select public.revocar_plan_supresion_qa('bd130000-0000-0000-0000-000000000002')$$,'revisor revoca plan obsoleto antes de una nueva revisión');
select public.autorizar_supresion_revisada_qa('bd130000-0000-0000-0000-000000000002',public.obtener_huella_revision_privacidad_qa('bd130000-0000-0000-0000-000000000002'),'POLITICA_QA',true);
reset role;
create function public.qa_fallo_despues_supresion() returns trigger language plpgsql as $$
begin raise exception using errcode='P0001',message='Fallo sintetico despues de redaccion'; end; $$;
create trigger zz_fallo_despues_supresion before delete on auth.users for each row execute function public.qa_fallo_despues_supresion();
select throws_ok($$delete from auth.users where id='bd130000-0000-0000-0000-000000000002'$$,'P0001','Fallo sintetico despues de redaccion','fallo posterior revierte todos los pasos');
select is((select count(*)::int from auth.users where id='bd130000-0000-0000-0000-000000000002'),1,'rollback conserva Auth');
select is((select count(*)::int from public.correcciones_aplicadas where not datos_suprimidos and solicitante_id='bd130000-0000-0000-0000-000000000002'),1,'rollback recupera snapshots e identidad');
select is((select count(*)::int from cercly_account_private.resultados_supresion),0,'rollback no deja recibo falso');
select is((select count(*)::int from cercly_account_private.ejecuciones_supresion),0,'rollback no deja capacidad abierta');
drop trigger zz_fallo_despues_supresion on auth.users;
drop function public.qa_fallo_despues_supresion();
select lives_ok($$delete from auth.users where id='bd130000-0000-0000-0000-000000000002'$$,'supresión, desvinculación y Auth atómicos');
select is((select count(*)::int from auth.users where id='bd130000-0000-0000-0000-000000000002'),0,'identidad Auth eliminada');
select is((select count(*)::int from public.usuarios where id='bd130000-0000-0000-0000-000000000002'),0,'perfil eliminado');
select is((select count(*)::int from auth.sessions where user_id='bd130000-0000-0000-0000-000000000002'),0,'sesiones destruidas por CASCADE Auth');
select is((select count(*)::int from public.miembros_establecimiento where usuario_id='bd130000-0000-0000-0000-000000000002'),0,'membresías eliminadas');
select is((select count(*)::int from public.solicitudes_establecimientos where solicitante_id='bd130000-0000-0000-0000-000000000002' or revisado_por='bd130000-0000-0000-0000-000000000002'),0,'identificadores de solicitudes desvinculados');
select is((select count(*)::int from public.solicitudes_establecimientos where datos_suprimidos and mensaje='' and motivo_respuesta='' and datos_propuestos='{}' and nombre_propuesto is null),2,'textos y propuestas personales suprimidos');
select is((select estado::text from public.solicitudes_establecimientos where id='bd130000-0000-0000-0000-000000000021'),'rechazada','pendiente retirada sin aplicación');
select is((select estado::text from public.solicitudes_establecimientos where id='bd130000-0000-0000-0000-000000000020'),'aprobada','hecho de aplicación preservado');
select is((select count(*)::int from public.correcciones_aplicadas where datos_suprimidos and solicitante_id is null and motivo='' and antes='{}' and despues='{}'),1,'auditoría conserva hecho sin snapshots personales');
select is((select count(*)::int from public.auditoria_moderacion_establecimientos where actor_id is null and datos_suprimidos),2,'eventos moderación conservados sin actor eliminado');
select is((select count(*)::int from cercly_account_private.auditoria_eliminacion where sujeto_id is null),1,'auditoría privacidad conserva hecho sin sujeto eliminado');
select is((select count(*)::int from cercly_account_private.ejecuciones_supresion),0,'capacidad transaccional destruida');
select is((select count(*)::int from cercly_account_private.planes_supresion),0,'plan con identificadores eliminado');
select is((select count(*)::int from cercly_account_private.solicitudes_eliminacion where usuario_id='bd130000-0000-0000-0000-000000000002'),0,'caso identificable cerrado sin huérfano');
select is((select count(*)::int from cercly_account_private.resultados_supresion),1,'recibo mínimo sin sujeto');
select is((select nombre from public.establecimientos where id='bd130000-0000-0000-0000-000000000010')::text,'Nombre corregido compartido','ficha del otro propietario intacta');
select ok(not exists(select 1 from pg_constraint where not convalidated and connamespace='public'::regnamespace),'sin FK inválidas');
set local role authenticated;
select set_config('request.jwt.claim.sub','bd130000-0000-0000-0000-000000000002',true);
select ok(not public.identidad_cercly_existente(),'JWT anterior no equivale a identidad activa');
select is((select count(*)::int from public.solicitudes_establecimientos),0,'token eliminado no lee solicitudes por RLS');
select is((select count(*)::int from storage.objects),0,'token eliminado no lee Storage');
select throws_ok($$insert into storage.objects(bucket_id,name,owner_id) values(null,'bd130000-0000-0000-0000-000000000002/personal','bd130000-0000-0000-0000-000000000002')$$,'42501',null,'token eliminado no recrea archivos');
reset role;
select lives_ok($$delete from auth.users where id='bd130000-0000-0000-0000-000000000004'$$,'cuenta sin historial continúa eliminación simple');
select is((select count(*)::int from cercly_account_private.resultados_supresion),2,'recibo para cada eliminación efectiva');
select is((select count(*)::int from auth.users where id in('bd130000-0000-0000-0000-000000000001','bd130000-0000-0000-0000-000000000003')),2,'otras identidades intactas');
select * from finish();
rollback;
