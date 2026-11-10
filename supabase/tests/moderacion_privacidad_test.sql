-- Transacción sintética; nunca ejecutar en una base con usuarios reales.
begin;
select plan(48);
insert into auth.users(id,email,raw_user_meta_data) select
 ('bc110000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
 'moderacion-'||i||'@cercly.test','{}' from generate_series(1,3)i;
update public.usuarios set rol='administrador' where id='bc110000-0000-0000-0000-000000000001';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select 'bc110000-0000-0000-0000-000000000010','bc110000-0000-0000-0000-000000000002',id,
 'Moderación original','Dirección local',0.8,-77.7,'pendiente',false
from public.categorias where activa order by id limit 1;
set local role authenticated;
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000002',true);
select lives_ok($$update public.establecimientos set nombre='Nombre pendiente' where id='bc110000-0000-0000-0000-000000000010'$$,'propietario conserva edición pendiente');
select throws_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','aprobado',true)$$,'42501','Administrador autenticado requerido','propietario no modera');
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000003',true);
select results_eq($$update public.establecimientos set nombre='Ajeno' where id='bc110000-0000-0000-0000-000000000010' returning id$$,$$select null::uuid where false$$,'ajeno no edita');
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','rechazado',true)$$,'22023','Estado y publicacion incompatibles','rechazo no admite publicación');
select lives_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','aprobado',true)$$,'aprobación inicial explícita');
select ok((select estado='aprobado' and publicable from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),'aprobada y publicada');
select is((select count(*)::int from public.auditoria_moderacion_establecimientos where establecimiento_id='bc110000-0000-0000-0000-000000000010'),1,'una auditoría inicial');
select ok((select actor_id=auth.uid() and estado_anterior='pendiente' and estado_nuevo='aprobado' and not publicable_anterior and publicable_nuevo and creado_en is not null and conservar_hasta is null from public.auditoria_moderacion_establecimientos where establecimiento_id='bc110000-0000-0000-0000-000000000010'),'auditoría mínima exacta sin plazo inventado');
select lives_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','aprobado',true)$$,'repetición idempotente');
select is((select count(*)::int from public.auditoria_moderacion_establecimientos where establecimiento_id='bc110000-0000-0000-0000-000000000010'),1,'repetición no duplica auditoría');
select throws_ok($$update public.establecimientos set nombre='Bypass admin' where id='bc110000-0000-0000-0000-000000000010'$$,'42501','El administrador solo puede moderar el estado directamente','administrador no edita información');
select lives_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','rechazado',false)$$,'rechazo autorizado');
select ok((select estado='rechazado' and not publicable from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),'rechazo retira publicación');
select lives_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','aprobado',false)$$,'aprobar sin publicar');
select is((select publicable from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),false,'privada hasta decisión explícita');
select lives_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','aprobado',true)$$,'republicación autorizada');
select is((select publicable from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),true,'republicación efectiva');
select is((select nombre from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),'Nombre pendiente','moderación no altera datos');
select throws_ok($$update public.auditoria_moderacion_establecimientos set actor_id=null$$,'42501',null,'no se reescribe auditoría desde cliente');
select throws_ok($$delete from public.auditoria_moderacion_establecimientos$$,'42501',null,'no se borra auditoría desde cliente');
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000002',true);
select is((select count(*)::int from public.auditoria_moderacion_establecimientos where establecimiento_id='bc110000-0000-0000-0000-000000000010'),0,'propietario no lee auditoría administrativa');
select throws_ok($$update public.establecimientos set nombre='Bypass propietario' where id='bc110000-0000-0000-0000-000000000010'$$,'42501','Ficha aprobada: solicitud de correccion requerida','aprobada exige solicitud');
select throws_ok($$insert into public.establecimiento_categorias(establecimiento_id,subcategoria_id,es_principal)
 select 'bc110000-0000-0000-0000-000000000010',s.id,true from public.subcategorias s
 where s.categoria_id<>(select categoria_id from public.establecimientos where id='bc110000-0000-0000-0000-000000000010') order by s.id limit 1$$,
 '42501','Ficha aprobada: solicitud de correccion requerida','sincronización definer no elude solicitud de categoría');
select is((select count(*)::int from public.establecimiento_categorias where establecimiento_id='bc110000-0000-0000-0000-000000000010'),0,'fallo indirecto no deja relación parcial');
select lives_ok($$insert into public.establecimiento_categorias(establecimiento_id,subcategoria_id,es_principal)
 select 'bc110000-0000-0000-0000-000000000010',s.id,true from public.subcategorias s
 where s.categoria_id=(select categoria_id from public.establecimientos where id='bc110000-0000-0000-0000-000000000010') order by s.id limit 1$$,
 'subcategoría de la categoría ya aprobada conserva su operación');
select is((select count(*)::int from public.establecimiento_categorias where establecimiento_id='bc110000-0000-0000-0000-000000000010'),1,'relación autorizada creada');
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos) values
 ('bc110000-0000-0000-0000-000000000020',auth.uid(),'bc110000-0000-0000-0000-000000000010','correccion','',
 '{"cambios":{"nombre":{"anterior":"Nombre pendiente","nuevo":"Corrección aplicada"}}}');
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.aplicar_correccion_establecimiento('bc110000-0000-0000-0000-000000000020','Comprobada')$$,'corrección estructurada sigue funcionando');
select is((select nombre from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),'Corrección aplicada','solo propuesta aplicada');
select is((select count(*)::int from public.auditoria_moderacion_establecimientos where establecimiento_id='bc110000-0000-0000-0000-000000000010'),4,'corrección informativa no inventa evento de moderación');
select is((select conservar_hasta from public.correcciones_aplicadas where solicitud_id='bc110000-0000-0000-0000-000000000020'),null::timestamptz,'corrección sin retención automática');
reset role;
select ok(cercly_account_private.tiene_dependencias('bc110000-0000-0000-0000-000000000001'),'revisor con historial requiere revisión de eliminación');
select ok(cercly_account_private.tiene_dependencias('bc110000-0000-0000-0000-000000000002'),'solicitante con historial requiere revisión');
update public.usuarios set rol='usuario' where id='bc110000-0000-0000-0000-000000000001';
select ok(cercly_account_private.tiene_dependencias('bc110000-0000-0000-0000-000000000001'),'exadministrador conserva dependencia sin FK de actor');
select throws_ok($$delete from public.solicitudes_establecimientos where id='bc110000-0000-0000-0000-000000000020'$$,'23503',null,'FK impide destruir historia para borrar solicitud');
select throws_ok($$delete from auth.users where id='bc110000-0000-0000-0000-000000000002'$$,'42501','Supresion requiere caso autorizado sin dependencias','eliminación no destruye historial del solicitante');
select throws_ok($$update public.auditoria_moderacion_establecimientos set actor_id=null$$,'42501','Auditoria inmutable: requiere procedimiento de privacidad revisado','ni mantenimiento reescribe sin procedimiento de privacidad');
-- Un error al insertar auditoría debe revertir la operación completa.
create function pg_temp.fallar_auditoria() returns trigger language plpgsql as $$begin raise exception 'fallo sintético de auditoría'; end$$;
create trigger fallo_sintetico before insert on public.auditoria_moderacion_establecimientos for each row execute function pg_temp.fallar_auditoria();
update public.usuarios set rol='administrador' where id='bc110000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','rechazado',false)$$,'P0001','fallo sintético de auditoría','fallo de auditoría revierte moderación');
select ok((select estado='aprobado' and publicable from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),'rollback conserva estado y publicación');
select is((select count(*)::int from public.auditoria_moderacion_establecimientos where establecimiento_id='bc110000-0000-0000-0000-000000000010'),4,'rollback conserva cantidad de auditorías');
select ok(not has_function_privilege('anon','public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)','EXECUTE'),'anónimo no modera');
select ok(not has_function_privilege('service_role','public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)','EXECUTE'),'no se amplía RPC a service_role');
select ok(not exists(select 1 from pg_proc p cross join (values('anon'),('authenticated'),('service_role')) r(rol)
 where p.oid in ('public.proteger_categoria_aprobada()'::regprocedure,'public.registrar_moderacion_establecimiento()'::regprocedure,'public.conservar_auditoria_moderacion()'::regprocedure)
 and has_function_privilege(r.rol,p.oid,'EXECUTE')),'triggers internos no invocables por clientes');
select ok(not has_column_privilege('authenticated','public.establecimientos','publicable','UPDATE'),'no se amplía UPDATE a publicación');
select ok((select relrowsecurity from pg_class where oid='public.auditoria_moderacion_establecimientos'::regclass),'RLS activo en nuevo historial');
reset role;
-- Revisor que solo aparece en moderación: sin propiedad ni solicitud/FK de usuario.
drop trigger fallo_sintetico on public.auditoria_moderacion_establecimientos;
insert into auth.users(id,email,raw_user_meta_data) values('bc110000-0000-0000-0000-000000000004','moderador-sin-solicitudes@cercly.test','{}');
update public.usuarios set rol='administrador' where id='bc110000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000004',true);
select lives_ok($$select public.moderar_estado_establecimiento('bc110000-0000-0000-0000-000000000010','aprobado',false)$$,'otro revisor retira publicación sin editar datos');
reset role;
update public.usuarios set rol='usuario' where id='bc110000-0000-0000-0000-000000000004';
select ok(cercly_account_private.tiene_dependencias('bc110000-0000-0000-0000-000000000004'),'actor solo en moderación requiere revisión aun tras perder rol');
set local role authenticated;
select set_config('request.jwt.claim.sub','bc110000-0000-0000-0000-000000000003',true);
select is((select count(*)::int from public.establecimientos where id='bc110000-0000-0000-0000-000000000010'),0,'ficha aprobada sin publicar no es visible a tercero');
set local role anon;
select throws_ok($$select * from public.auditoria_moderacion_establecimientos$$,'42501',null,'anónimo no lee historial administrativo');
select * from finish();
rollback;
