-- Solo PostgreSQL aislado; fixtures sintéticos dentro de rollback.
begin;
select plan(12);
insert into auth.users(id,email,raw_user_meta_data) values
 ('b7200000-0000-0000-0000-000000000001','owner-op@cercly.test','{}'),
 ('b7200000-0000-0000-0000-000000000002','ordinary-op@cercly.test','{}'),
 ('b7200000-0000-0000-0000-000000000003','admin-op@cercly.test','{}'),
 ('b7200000-0000-0000-0000-000000000004','member-op@cercly.test','{}');
update public.usuarios set rol='propietario' where id='b7200000-0000-0000-0000-000000000001';
update public.usuarios set rol='administrador' where id='b7200000-0000-0000-0000-000000000003';
insert into public.establecimientos
 (id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado)
select 'b7210000-0000-0000-0000-000000000001',
 'b7200000-0000-0000-0000-000000000001',id,'Negocio propietario','Tulcán',0.8,-77.7,'pendiente'
from public.categorias limit 1;
insert into public.miembros_establecimiento(establecimiento_id,usuario_id,rol,activo)
values ('b7210000-0000-0000-0000-000000000001',
 'b7200000-0000-0000-0000-000000000004','editor',true);

set local role authenticated;
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000002',true);
select ok(not public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000001'),
  'usuario normal no administra negocio ajeno');
select ok(not public.puede_gestionar_establecimiento('b7210000-0000-0000-0000-000000000001'),
  'usuario normal tampoco pasa control general');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000003',true);
select ok(public.es_administrador(), 'rol administrativo anterior sigue activo');
select ok(public.puede_gestionar_establecimiento('b7210000-0000-0000-0000-000000000001'),
  'administrador conserva privilegio en ruta administrativa');
select ok(not public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000001'),
  'ruta propietaria ignora privilegio administrativo');
update public.establecimientos set nombre='Cambio accidental'
where id='b7210000-0000-0000-0000-000000000001'
  and public.puede_gestionar_como_propietario(id);
select is((select count(*)::integer from public.establecimientos
  where id='b7210000-0000-0000-0000-000000000001' and nombre='Cambio accidental'),0,
  'flujo propietario no ejecuta actualización para admin no asignado');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000004',true);
select ok(public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000001'),
  'miembro activo pasa verificación estricta');
reset role;
update public.miembros_establecimiento set activo=false
where usuario_id='b7200000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000004',true);
select ok(not public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000001'),
  'miembro revocado pierde acceso propietario');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b7200000-0000-0000-0000-000000000001',true);
select ok(public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000001'),
  'propietario explícito pasa verificación');
select ok(not public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000099'),
  'UUID de negocio manipulado se deniega');
reset role;

select set_config('request.jwt.claim.sub','',true);
set local role anon;
select throws_ok($$select public.puede_gestionar_como_propietario('b7210000-0000-0000-0000-000000000001')$$,
  '42501',null,'anon no puede invocar helper propietario');
reset role;
select ok(not has_function_privilege('anon',
  'public.puede_gestionar_como_propietario(uuid)','EXECUTE'),
  'función sin permiso anon');
select * from finish();
rollback;
