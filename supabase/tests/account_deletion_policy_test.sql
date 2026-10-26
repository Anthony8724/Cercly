begin;
select plan(19);
insert into auth.users(id,email,raw_user_meta_data) values
 ('b7200000-0000-0000-0000-000000000001','policy-owner@cercly.test','{}'),
 ('b7200000-0000-0000-0000-000000000002','policy-target@cercly.test','{}'),
 ('b7200000-0000-0000-0000-000000000003','policy-admin@cercly.test','{}');
insert into auth.sessions(id,user_id) values
 ('b7200000-0000-0000-0000-000000000001','b7200000-0000-0000-0000-000000000001'),
 ('b7200000-0000-0000-0000-000000000002','b7200000-0000-0000-0000-000000000002'),
 ('b7200000-0000-0000-0000-000000000003','b7200000-0000-0000-0000-000000000003');
update public.usuarios set rol='propietario' where id='b7200000-0000-0000-0000-000000000002';
update public.usuarios set rol='administrador' where id='b7200000-0000-0000-0000-000000000003';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
 select 'b7210000-0000-0000-0000-000000000001',
 'b7200000-0000-0000-0000-000000000001',id,'Negocio sintético','Tulcán',0,0,'aprobado',true
 from public.categorias limit 1;
insert into public.miembros_establecimiento(establecimiento_id,usuario_id,rol)
 values ('b7210000-0000-0000-0000-000000000001',
 'b7200000-0000-0000-0000-000000000002','administrador');

set local role authenticated;
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"b7200000-0000-0000-0000-000000000001"}',true);
select is(public.solicitar_eliminacion_cuenta(),'revision','propietario requiere revisión');
select throws_ok('select * from public.listar_solicitudes_eliminacion()',
 '42501',null,'usuario no consulta la cola privada');
select throws_ok($$select public.revisar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001','aprobar')$$,
 '42501',null,'propietario no se aprueba a sí mismo');
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"session_id":"b7200000-0000-0000-0000-000000000003"}',true);
select ok(exists(select 1 from public.listar_solicitudes_eliminacion()
 where usuario_id='b7200000-0000-0000-0000-000000000001'),
 'administrador reciente puede localizar la solicitud');
select throws_ok($$select public.revisar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001','aprobar')$$,
 '23503',null,'no se aprueba con propiedad pendiente');
select throws_ok($$select public.revisar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001','transferir',
 'b7210000-0000-0000-0000-000000000001',
 'b7200000-0000-0000-0000-000000000003')$$,
 '22023',null,'destino sin membresía no autorizado');
select throws_ok($$update public.establecimientos set estado='rechazado'
 where id='b7210000-0000-0000-0000-000000000001'$$,
 '42501','Usar revisión administrativa',
 'administrador no desactiva por un atajo sin auditoría');
select throws_ok($$delete from public.establecimientos
 where id='b7210000-0000-0000-0000-000000000001'$$,
 '42501','Negocio compartido en revisión',
 'administrador no borra negocio de una solicitud activa');
select is(public.revisar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001','desactivar',
 'b7210000-0000-0000-0000-000000000001'),'revision',
 'desactivación no equivale a borrado');
select is((select publicable from public.establecimientos
 where id='b7210000-0000-0000-0000-000000000001'),false,
 'negocio desactivado deja de publicarse');
select is(public.revisar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001','transferir',
 'b7210000-0000-0000-0000-000000000001',
 'b7200000-0000-0000-0000-000000000002'),'revision',
 'transferencia a miembro administrador autorizado');
select is((select propietario_id from public.establecimientos
 where id='b7210000-0000-0000-0000-000000000001'),
 'b7200000-0000-0000-0000-000000000002'::uuid,
 'propiedad cambia sin borrar negocio');
select is(public.revisar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001','aprobar'),'aprobada',
 'admin aprueba al resolver dependencias');
reset role;
select is((select count(*)::integer from cercly_account_private.auditoria_eliminacion
 where sujeto_id='b7200000-0000-0000-0000-000000000001'),3,
 'auditoría registra acciones efectivas');
set local role service_role;
select is(public.validar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001'),true,
 'servicio revalida antes de borrar Auth');
reset role;
create table public.deletion_fk_sintetica (
  usuario_id uuid references public.usuarios(id) on delete cascade
);
set local role service_role;
select is(public.validar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001'),false,
 'FK nueva incluso CASCADE bloquea hasta revisar su semántica');
reset role;
drop table public.deletion_fk_sintetica;
update public.usuarios set rol='usuario' where rol='administrador'
  and id <> 'b7200000-0000-0000-0000-000000000003';
update public.usuarios set rol='administrador'
  where id='b7200000-0000-0000-0000-000000000001';
set local role service_role;
select is(public.validar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001'),true,
 'dos administradores permiten procedimiento especial');
reset role;
update public.usuarios set rol='usuario'
  where id='b7200000-0000-0000-0000-000000000003';
set local role service_role;
select is(public.validar_eliminacion_cuenta(
 'b7200000-0000-0000-0000-000000000001'),false,
 'último administrador bloqueado justo antes de Auth');
reset role;
select throws_ok($$delete from auth.users
 where id='b7200000-0000-0000-0000-000000000001'$$,
 '42501','Último administrador activo',
 'trigger transaccional protege incluso un borrado Auth directo');
select * from finish();
rollback;
