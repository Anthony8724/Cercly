-- Identidades y categoría sintéticas; todo se revierte al terminar.
begin;
select plan(39);
insert into auth.users(id,email,raw_user_meta_data) values
 ('b8100000-0000-0000-0000-000000000001','pref-uno@cercly.test','{}'),
 ('b8100000-0000-0000-0000-000000000002','pref-dos@cercly.test','{}');
insert into public.categorias(id,nombre,icono,activa,orden,slug)
values
 ('b8110000-0000-0000-0000-000000000001','Categoría preferencias prueba','category',true,999999,'categoria-preferencias-prueba'),
 ('b8110000-0000-0000-0000-000000000002','Categoría inactiva prueba','category',false,999998,'categoria-inactiva-prueba');

select ok((select relrowsecurity from pg_class where oid='public.preferencias_usuario'::regclass), 'RLS activo en preferencias');
select ok((select relrowsecurity from pg_class where oid='public.preferencias_usuario_categorias'::regclass), 'RLS activo en categorías preferidas');
select ok(not has_table_privilege('anon','public.preferencias_usuario','SELECT'), 'anon no lee preferencias');
select ok(not has_table_privilege('anon','public.preferencias_usuario_categorias','INSERT'), 'anon no escribe categorías preferidas');
select ok(not has_function_privilege('anon','public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)','EXECUTE'), 'anon no ejecuta RPC de escritura');
select ok(not has_function_privilege('service_role','public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)','EXECUTE'), 'service_role no ejecuta la RPC de usuario');
select ok(not exists (
  select 1
  from pg_catalog.aclexplode(
    (select proacl from pg_catalog.pg_proc
     where oid='public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)'::regprocedure)
  ) as acl
  where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
), 'PUBLIC no ejecuta RPC de escritura');
select ok(has_function_privilege('authenticated','public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)','EXECUTE'), 'authenticated ejecuta RPC de escritura');
select ok((select prosecdef from pg_catalog.pg_proc where oid='public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)'::regprocedure), 'RPC usa SECURITY DEFINER');
select is((select proowner::pg_catalog.regrole::text from pg_catalog.pg_proc where oid='public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)'::regprocedure),'postgres','RPC pertenece al rol de base de datos previsto');
select ok((select proconfig @> array['search_path=""'] from pg_catalog.pg_proc where oid='public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)'::regprocedure), 'RPC fija search_path vacío');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario','INSERT'), 'authenticated no inserta preferencias directamente');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario','UPDATE'), 'authenticated no actualiza preferencias directamente');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario','DELETE'), 'authenticated no elimina preferencias directamente');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario_categorias','INSERT'), 'authenticated no inserta categorías directamente');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario_categorias','UPDATE'), 'authenticated no actualiza categorías directamente');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario_categorias','DELETE'), 'authenticated no elimina categorías directamente');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario','TRUNCATE'), 'RLS no se elude con TRUNCATE en preferencias');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario','REFERENCES'), 'no se permiten FKs creadas por authenticated en preferencias');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario','TRIGGER'), 'no se permiten triggers creados por authenticated en preferencias');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario_categorias','TRUNCATE'), 'RLS no se elude con TRUNCATE en categorías preferidas');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario_categorias','REFERENCES'), 'no se permiten FKs creadas por authenticated en categorías preferidas');
select ok(not has_table_privilege('authenticated','public.preferencias_usuario_categorias','TRIGGER'), 'no se permiten triggers creados por authenticated en categorías preferidas');

set local role authenticated;
select set_config('request.jwt.claim.sub','b8100000-0000-0000-0000-000000000001',true);
select is(public.guardar_preferencias_usuario(array['b8110000-0000-0000-0000-000000000001']::uuid[],3000,true,0),1::bigint,'guarda la primera revisión y categoría');
select is((select count(*)::integer from public.preferencias_usuario where usuario_id=auth.uid()),1,'usuario lee su fila');
select is((select count(*)::integer from public.preferencias_usuario_categorias where usuario_id=auth.uid()),1,'usuario lee su categoría');
select throws_ok($$insert into public.preferencias_usuario(usuario_id) values (auth.uid())$$,'42501',null,'usuario no puede insertar preferencias directamente');
select throws_ok($$update public.preferencias_usuario set revision=revision+1 where usuario_id=auth.uid()$$,'42501',null,'usuario no puede actualizar preferencias directamente');
select throws_ok($$delete from public.preferencias_usuario where usuario_id=auth.uid()$$,'42501',null,'usuario no puede borrar preferencias directamente');
select throws_ok($$insert into public.preferencias_usuario_categorias(usuario_id,categoria_id) values (auth.uid(),'b8110000-0000-0000-0000-000000000001')$$,'42501',null,'usuario no puede insertar categorías directamente');
select throws_ok($$update public.preferencias_usuario_categorias set categoria_id='b8110000-0000-0000-0000-000000000002' where usuario_id=auth.uid()$$,'42501',null,'usuario no puede actualizar categorías directamente');
select throws_ok($$delete from public.preferencias_usuario_categorias where usuario_id=auth.uid()$$,'42501',null,'usuario no puede borrar categorías directamente');
select throws_ok($$select public.guardar_preferencias_usuario(array[]::uuid[],2000,false,1)$$,'22023',null,'radio fuera de lista rechazado');
select throws_ok($$select public.guardar_preferencias_usuario(array[]::uuid[],5000,false,0)$$,'40001',null,'revisión obsoleta no sobrescribe cambios');
select throws_ok($$select public.guardar_preferencias_usuario(array['b8110000-0000-0000-0000-000000000002']::uuid[],5000,false,1)$$,'22023',null,'categoría inactiva no se asocia');
select throws_ok($$insert into public.preferencias_usuario(usuario_id) values ('b8100000-0000-0000-0000-000000000002')$$,'42501',null,'no escribe preferencias de otro usuario');
reset role;

set local role anon;
select throws_ok($$select public.guardar_preferencias_usuario(array[]::uuid[],null,false,0)$$,'42501',null,'anon no puede invocar la RPC de escritura');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','b8100000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.preferencias_usuario),0,'otro usuario no ve preferencias ajenas');
reset role;

delete from auth.users where id='b8100000-0000-0000-0000-000000000001';
select is((select count(*)::integer from public.preferencias_usuario where usuario_id='b8100000-0000-0000-0000-000000000001'),0,'borrar cuenta elimina la fila de preferencias');
select * from finish();
rollback;
