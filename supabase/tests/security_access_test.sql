-- Solo base local desechable; fixtures sintéticos y rollback.
begin;
select plan(58);
insert into auth.users(id,email,raw_user_meta_data) values
 ('b4000000-0000-0000-0000-000000000001','admin-b4@cercly.test','{}'),
 ('b4000000-0000-0000-0000-000000000002','user-b4@cercly.test','{"rol":"administrador","tipo_cuenta":"propietario"}'),
 ('b4000000-0000-0000-0000-000000000003','owner-b4@cercly.test','{}'),
 ('b4000000-0000-0000-0000-000000000004','member-b4@cercly.test','{}');
update public.usuarios set rol='administrador' where id='b4000000-0000-0000-0000-000000000001';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select 'b4100000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000003',id,'Negocio aprobado B4','Tulcán',0.8,-77.7,'aprobado',true from public.categorias where activa limit 1;
insert into public.promociones(id,establecimiento_id,titulo,fecha_inicio,fecha_fin) values
 ('b4200000-0000-0000-0000-000000000001','b4100000-0000-0000-0000-000000000001','Oferta B4',now()-interval '1 day',now()+interval '1 day');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000002',true);
select ok(not public.es_administrador(), 'metadatos falsos no autorizan');
select throws_ok($test$insert into public.miembros_establecimiento(establecimiento_id,usuario_id) values ('b4100000-0000-0000-0000-000000000001',auth.uid())$test$, '42501', null, 'no se agrega como colaborador');
select throws_ok($test$select public.responder_solicitud_establecimiento('b4300000-0000-0000-0000-000000000001','aprobada','')$test$, 'P0001', null, 'RPC exige administrador antes de consultar solicitud');
select throws_ok($test$insert into public.usuarios(id,nombre,rol) values (auth.uid(),'Ataque','administrador')$test$, '42501', null, 'no inserta perfil privilegiado');
select throws_ok($test$update public.usuarios set id=gen_random_uuid() where id=auth.uid()$test$, '42501', null, 'no cambia identidad');
select throws_ok($test$update public.usuarios set creado_en=now() where id=auth.uid()$test$, '42501', null, 'no cambia fecha del perfil');
select throws_ok($test$insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud) select 'b4100000-0000-0000-0000-000000000002',auth.uid(),id,'Pendiente B4','Tulcán',0.8,-77.7 from public.categorias where activa limit 1$test$, '42501', null, 'nuevo establecimiento debe entrar por solicitud revisable');
select ok((select rol='usuario' from public.usuarios where id=auth.uid()), 'la solicitud pendiente no concede propietario');
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
select is((select count(*)::integer from public.establecimientos where id='b4100000-0000-0000-0000-000000000002'),0,'anon no ve negocio pendiente');
select is((select count(*)::integer from public.promociones where id='b4200000-0000-0000-0000-000000000002'),0,'anon no ve promocion del pendiente');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000002',true);

select lives_ok($test$update public.establecimientos set estado='aprobado' where id='b4100000-0000-0000-0000-000000000002'$test$,'no puede aprobar una ficha por actualización directa');
select is((select count(*)::integer from public.establecimientos where id='b4100000-0000-0000-0000-000000000002'),0,'no se crea ficha pública antes de la aprobación por solicitud');
select lives_ok($test$update public.establecimientos set publicable=true where id='b4100000-0000-0000-0000-000000000002'$test$,'no puede publicar una ficha por actualización directa');
select is((select count(*)::integer from public.establecimientos where id='b4100000-0000-0000-0000-000000000002'),0,'no hay ficha publicable antes de la aprobación');
select throws_ok($test$insert into public.establecimientos(propietario_id,categoria_id,nombre,direccion,latitud,longitud,verificado_en,verificado_por) select auth.uid(),id,'Verificación falsa','Tulcán',0.8,-77.7,now(),auth.uid() from public.categorias where activa limit 1$test$, '42501', null, 'no puede falsificar verificacion al insertar');
select throws_ok($test$insert into public.promociones(establecimiento_id,titulo,fecha_inicio,fecha_fin) values ('b4100000-0000-0000-0000-000000000001','Ataque',now(),now()+interval '1 day')$test$, '42501', null, 'no crea promociones de otro negocio');
select lives_ok($test$insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje) values ('b4300000-0000-0000-0000-000000000001',auth.uid(),'b4100000-0000-0000-0000-000000000001','acceso','Solicito acceso autorizado')$test$, 'solicitud propia pendiente admitida');
select ok(not public.puede_gestionar_establecimiento('b4100000-0000-0000-0000-000000000001'), 'solicitud pendiente no concede acceso');
select lives_ok($test$update public.solicitudes_establecimientos set estado='aprobada' where id='b4300000-0000-0000-0000-000000000001'$test$, 'RLS filtra intento directo de autoaprobacion');
select ok((select estado='pendiente' from public.solicitudes_establecimientos where id='b4300000-0000-0000-0000-000000000001'), 'autoaprobacion no modifica solicitud');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000001',true);
select ok(public.es_administrador(), 'administrador autorizado conserva autorizacion');
select lives_ok($test$insert into public.establecimientos(propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,verificado_en,verificado_por)
select auth.uid(),id,'Alta autorizada','Tulcán',0.8,-77.7,'aprobado',now(),auth.uid() from public.categorias where activa limit 1$test$,'administrador conserva alta verificada');
select is((select rol::text from public.usuarios where id=auth.uid()),'administrador','trigger no degrada administrador propietario');

select is((select count(*)::integer from public.establecimientos where id='b4100000-0000-0000-0000-000000000002'),0,'la ficha no existe hasta una solicitud de registro aprobada');
select ok((select rol='usuario' from public.usuarios where id='b4000000-0000-0000-0000-000000000002'), 'no recibe rol propietario sin solicitud de registro aprobada');
select lives_ok($test$select public.responder_solicitud_establecimiento('b4300000-0000-0000-0000-000000000001','aprobada','')$test$, 'RPC administrativo aprueba acceso');
select ok((select activo from public.miembros_establecimiento where usuario_id='b4000000-0000-0000-0000-000000000002' and establecimiento_id='b4100000-0000-0000-0000-000000000001'), 'aprobacion crea colaborador activo');
select throws_ok($test$select public.responder_solicitud_establecimiento('b4300000-0000-0000-0000-000000000001','aprobada','')$test$, 'P0001', null, 'no responde dos veces');
select ok((select rol='administrador' from public.usuarios where id=auth.uid()), 'administrador no pierde rol');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000002',true);
select lives_ok($test$update public.promociones set titulo='Oferta editada B4' where id='b4200000-0000-0000-0000-000000000001'$test$, 'colaborador activo edita promocion');
select ok((select titulo='Oferta editada B4' from public.promociones where id='b4200000-0000-0000-0000-000000000001'), 'edicion del colaborador efectiva');
select throws_ok($test$update public.establecimientos set propietario_id=auth.uid() where id='b4100000-0000-0000-0000-000000000001'$test$, 'P0001', null, 'colaborador no roba propiedad');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000001',true);
update public.miembros_establecimiento set activo=false where usuario_id='b4000000-0000-0000-0000-000000000002';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000002',true);
select ok(not public.puede_gestionar_establecimiento('b4100000-0000-0000-0000-000000000001'), 'colaborador desactivado pierde gestion');
update public.promociones set titulo='Edición indebida' where id='b4200000-0000-0000-0000-000000000001';
select ok((select titulo='Oferta editada B4' from public.promociones where id='b4200000-0000-0000-0000-000000000001'), 'colaborador desactivado no edita');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4000000-0000-0000-0000-000000000003',true);
select ok(public.puede_gestionar_establecimiento('b4100000-0000-0000-0000-000000000001'), 'propietario legitimo conserva acceso');
select lives_ok($test$update public.establecimientos set nombre='Propietario conserva acceso' where id='b4100000-0000-0000-0000-000000000001'$test$, 'propietario mantiene edicion');
reset role; select set_config('request.jwt.claim.sub','',true); set local role anon;
select ok(exists(select 1 from public.establecimientos where id='b4100000-0000-0000-0000-000000000001'), 'anon consulta negocio publicado');
select ok(exists(select 1 from public.promociones where id='b4200000-0000-0000-0000-000000000001'), 'anon consulta promocion publicada');
select throws_ok($test$select * from public.usuarios$test$, '42501', null, 'anon no lee perfiles');
reset role;
select ok(not has_table_privilege('anon','public.usuarios','TRUNCATE'), 'anon sin TRUNCATE en usuarios');
select ok(not has_table_privilege('authenticated','public.usuarios','TRUNCATE'), 'authenticated sin TRUNCATE en usuarios');
select ok(not has_table_privilege('anon','public.establecimientos','TRUNCATE'), 'anon sin TRUNCATE en establecimientos');
select ok(not has_table_privilege('authenticated','public.establecimientos','TRUNCATE'), 'authenticated sin TRUNCATE en establecimientos');
select ok(not has_table_privilege('anon','public.solicitudes_establecimientos','TRUNCATE'), 'anon sin TRUNCATE en solicitudes_establecimientos');
select ok(not has_table_privilege('authenticated','public.solicitudes_establecimientos','TRUNCATE'), 'authenticated sin TRUNCATE en solicitudes_establecimientos');
select ok(not has_table_privilege('anon','public.miembros_establecimiento','TRUNCATE'), 'anon sin TRUNCATE en miembros_establecimiento');
select ok(not has_table_privilege('authenticated','public.miembros_establecimiento','TRUNCATE'), 'authenticated sin TRUNCATE en miembros_establecimiento');
select ok(not has_table_privilege('anon','public.promociones','TRUNCATE'), 'anon sin TRUNCATE en promociones');
select ok(not has_table_privilege('authenticated','public.promociones','TRUNCATE'), 'authenticated sin TRUNCATE en promociones');
select ok(not has_function_privilege('anon','public.crear_perfil_nuevo_usuario()','EXECUTE'),'anon sin EXECUTE directo sobre crear_perfil_nuevo_usuario()');
select ok(not has_function_privilege('authenticated','public.crear_perfil_nuevo_usuario()','EXECUTE'),'authenticated sin EXECUTE directo sobre crear_perfil_nuevo_usuario()');
select ok(not has_function_privilege('anon','public.convertir_en_propietario()','EXECUTE'),'anon sin EXECUTE directo sobre convertir_en_propietario()');
select ok(not has_function_privilege('authenticated','public.convertir_en_propietario()','EXECUTE'),'authenticated sin EXECUTE directo sobre convertir_en_propietario()');
select ok(not has_function_privilege('anon','public.proteger_rol_usuario()','EXECUTE'),'anon sin EXECUTE directo sobre proteger_rol_usuario()');
select ok(not has_function_privilege('authenticated','public.proteger_rol_usuario()','EXECUTE'),'authenticated sin EXECUTE directo sobre proteger_rol_usuario()');
select ok(not has_function_privilege('anon','public.sincronizar_categoria_principal()','EXECUTE'),'anon sin EXECUTE directo sobre sincronizar_categoria_principal()');
select ok(not has_function_privilege('authenticated','public.sincronizar_categoria_principal()','EXECUTE'),'authenticated sin EXECUTE directo sobre sincronizar_categoria_principal()');
select ok(not exists(select 1 from pg_class where oid in ('public.usuarios'::regclass,'public.establecimientos'::regclass,'public.solicitudes_establecimientos'::regclass,'public.miembros_establecimiento'::regclass,'public.promociones'::regclass) and not relrowsecurity),'RLS activo en las cinco tablas');
select * from finish();
rollback;
