begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) select ('b9900000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'caso-'||i||'@cercly.test','{}' from generate_series(1,4)i;
update public.usuarios set rol='administrador' where id='b9900000-0000-0000-0000-000000000001';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select 'b9900000-0000-0000-0000-000000000010','b9900000-0000-0000-0000-000000000002',id,'Nombre inicial','Dirección',0.8,-77.7,'aprobado',true from public.categorias where activa order by id limit 1;
insert into public.miembros_establecimiento(establecimiento_id,usuario_id,activo) values('b9900000-0000-0000-0000-000000000010','b9900000-0000-0000-0000-000000000003',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000003',true);
select lives_ok($$insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
values('b9900000-0000-0000-0000-000000000020',auth.uid(),'b9900000-0000-0000-0000-000000000010','correccion','',
'{"cambios":{"nombre":{"anterior":"Nombre inicial","nuevo":"Nombre propuesto"}}}')$$,'colaborador activo presenta propuesta con motivo opcional vacío');
select throws_ok($$select public.aplicar_correccion_establecimiento('b9900000-0000-0000-0000-000000000020','Revisión')$$,'P0001','Solo un administrador autenticado puede aprobar correcciones.','colaborador no aprueba');
reset role;
update public.miembros_establecimiento set activo=false where usuario_id='b9900000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b9900000-0000-0000-0000-000000000020','Revisión')$$,'P0001','El solicitante ya no tiene permisos sobre el establecimiento.','revocación posterior impide aplicar');
select is((select nombre from public.establecimientos where id='b9900000-0000-0000-0000-000000000010'),'Nombre inicial','permisos revocados no alteran ficha');
select is((select count(*)::int from public.correcciones_aplicadas),0,'sin auditoría ficticia tras rechazo de permisos');
select is((select estado::text from public.solicitudes_establecimientos where id='b9900000-0000-0000-0000-000000000020'),'pendiente','fallo conserva solicitud pendiente');
reset role;
update public.miembros_establecimiento set activo=true where usuario_id='b9900000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.aplicar_correccion_establecimiento('b9900000-0000-0000-0000-000000000020','Propuesta comprobada')$$,'admin aplica propuesta de colaborador vigente');
select is((select nombre from public.establecimientos where id='b9900000-0000-0000-0000-000000000010'),'Nombre propuesto','único campo propuesto aplicado');
select is((select direccion from public.establecimientos where id='b9900000-0000-0000-0000-000000000010'),'Dirección','campo no solicitado intacto');
select ok((select solicitado_en is not null and cerrado_en>=solicitado_en and solicitante_id='b9900000-0000-0000-0000-000000000003'::uuid and revisado_por=auth.uid() from public.correcciones_aplicadas),'auditoría contiene actores y fechas');
select is((select count(*)::int from public.correcciones_aplicadas a cross join lateral jsonb_object_keys(a.antes)),1,'historial limitado al campo solicitado');
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000004',true);
select is((select count(*)::int from public.correcciones_aplicadas),0,'usuario ajeno no lee auditoría');
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000002',true);
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
values('b9900000-0000-0000-0000-000000000021',auth.uid(),'b9900000-0000-0000-0000-000000000010','correccion','',
'{"cambios":{"nombre":{"anterior":"Nombre propuesto","nuevo":"Nombre siguiente"}}}');
reset role;
update public.establecimientos set nombre='Cambio concurrente' where id='b9900000-0000-0000-0000-000000000010';
set local role authenticated;
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b9900000-0000-0000-0000-000000000021','Revisión')$$,'P0001','La ficha cambió o la propuesta no es válida. Solicita una revisión nueva.','valor anterior obsoleto se rechaza');
select is((select nombre from public.establecimientos where id='b9900000-0000-0000-0000-000000000010'),'Cambio concurrente','no se pierde actualización concurrente');
select is((select count(*)::int from public.correcciones_aplicadas),1,'fallo de concurrencia no agrega auditoría');
select lives_ok($$select public.responder_solicitud_establecimiento('b9900000-0000-0000-0000-000000000021','rechazada','La ficha cambió; presentar una nueva propuesta')$$,'rechazo posterior conserva respuesta');
select is((select estado::text from public.solicitudes_establecimientos where id='b9900000-0000-0000-0000-000000000021'),'rechazada','solicitud rechazada permanece');
select is((select count(*)::int from public.correcciones_aplicadas),1,'rechazo no simula aplicación');
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000002',true);
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
values('b9900000-0000-0000-0000-000000000022',auth.uid(),'b9900000-0000-0000-0000-000000000010','correccion','',
'{"cambios":{"nombre":{"anterior":"Cambio concurrente","nuevo":"No debe aplicarse"}}}');
reset role;
create function public.prueba_valor_no_aplicado() returns trigger language plpgsql as $$ begin
 if new.id='b9900000-0000-0000-0000-000000000010'::uuid and new.nombre='No debe aplicarse' then new.nombre:=old.nombre; end if; return new; end $$;
create trigger prueba_valor_no_aplicado before update on public.establecimientos for each row execute function public.prueba_valor_no_aplicado();
set local role authenticated;
select set_config('request.jwt.claim.sub','b9900000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b9900000-0000-0000-0000-000000000022','Revisión')$$,'P0001','El valor aplicado no coincide con la propuesta; operación revertida.','un trigger que impide aplicar provoca rollback sin falso éxito');
select is((select estado::text from public.solicitudes_establecimientos where id='b9900000-0000-0000-0000-000000000022'),'pendiente','sin aplicación no se aprueba solicitud');
select is((select count(*)::int from public.correcciones_aplicadas),1,'sin cambio real no se registra otra aplicación');
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b9900000-0000-0000-0000-000000000021','Revisión')$$,'P0001','Solo un administrador autenticado puede aprobar correcciones.','sin identidad no aplica');
select * from finish();
rollback;
