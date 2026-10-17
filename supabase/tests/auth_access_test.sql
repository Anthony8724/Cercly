-- Ejecutar en Supabase LOCAL con pgTAP, después de las migraciones. Sin SMS.
begin;
select plan(11);
insert into auth.users(id, aud, role, email, phone, raw_user_meta_data)
values
 ('b3000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
  'auth-a@cercly.test', null, '{"nombre":"Persona A","tipo_cuenta":"administrador","rol":"administrador"}'),
 ('b3000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
  null, '593990000002', '{}'),
 ('b3000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
  'auth-oauth@cercly.test', null, '{"full_name":"Cuenta OAuth","tipo_cuenta":"propietario"}');
select is((select rol::text from public.usuarios where id = 'b3000000-0000-0000-0000-000000000001'), 'usuario', 'metadatos no otorgan administrador');
select is((select nombre from public.usuarios where id = 'b3000000-0000-0000-0000-000000000002')::text, 'Usuario', 'perfil telefónico sin email');
select is((select nombre from public.usuarios where id = 'b3000000-0000-0000-0000-000000000003')::text, 'Cuenta OAuth', 'nombre OAuth');
select is((select rol::text from public.usuarios where id = 'b3000000-0000-0000-0000-000000000003'), 'usuario', 'intención propietario no eleva rol');
select ok(not has_table_privilege('authenticated', 'public.usuarios', 'UPDATE'), 'sin UPDATE general');
select ok(has_column_privilege('authenticated', 'public.usuarios', 'nombre', 'UPDATE'), 'nombre editable');
select ok(not has_column_privilege('authenticated', 'public.usuarios', 'rol', 'UPDATE'), 'rol protegido por privilegios SQL');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b3000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.usuarios where id in ('b3000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000002')), 1, 'RLS aísla perfiles');
select lives_ok($$update public.usuarios set nombre = 'Nuevo nombre' where id = 'b3000000-0000-0000-0000-000000000001'$$, 'actualiza su nombre');
select throws_ok($$update public.usuarios set rol = 'propietario' where id = 'b3000000-0000-0000-0000-000000000001'$$, '42501', 'permission denied for table usuarios', 'no puede promoverse');
select ok(not public.es_administrador(), 'metadatos no autorizan RLS administrativo');
reset role;
select * from finish();
rollback;
