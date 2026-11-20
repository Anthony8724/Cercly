-- Solo identidades sintéticas y rollback; ejecutar en contenedor nuevo sin red.
begin;
select plan(15);

select ok(cercly_account_private.es_referencia_identidad_plataforma(
  (select oid from pg_constraint where conrelid='cercly_rutas_privado.rutas_limites_usuarios'::regclass
   and conname='rutas_limites_usuarios_usuario_id_fkey')),
  'la FK exacta de cuota se reconoce como cascada segura');
select ok(not has_schema_privilege('authenticated','cercly_rutas_privado','usage'),
  'el arreglo no expone el esquema de cuota');
select ok(not has_function_privilege('authenticated',
  'cercly_account_private.es_referencia_identidad_plataforma(oid)','execute'),
  'el cliente no obtiene acceso al helper privado');

insert into auth.users(id,email,raw_user_meta_data) values
 ('c9260000-0000-0000-0000-000000000001','rutas-borrado@cercly.test','{}');
insert into auth.sessions(id,user_id,created_at) values
 ('c9260000-0000-0000-0000-000000000001','c9260000-0000-0000-0000-000000000001',now());
insert into cercly_rutas_privado.rutas_limites_usuarios values
 ('c9260000-0000-0000-0000-000000000001',now(),2);
select ok(not cercly_account_private.tiene_dependencias('c9260000-0000-0000-0000-000000000001'),
  'una fila de cuota propia no bloquea la eliminación');

-- Incluso una cascada desconocida vacía obliga a revisar; no ampliar la lista.
create table public.rutas_qa_dependencia_desconocida (
 usuario_id uuid references auth.users(id) on delete cascade
);
select ok(cercly_account_private.tiene_dependencias('c9260000-0000-0000-0000-000000000001'),
  'una nueva FK desconocida conserva el cierre seguro');
drop table public.rutas_qa_dependencia_desconocida;

-- La coincidencia del nombre no basta: debe conservarse CASCADE validada.
alter table cercly_rutas_privado.rutas_limites_usuarios
 drop constraint rutas_limites_usuarios_usuario_id_fkey;
alter table cercly_rutas_privado.rutas_limites_usuarios add constraint rutas_limites_usuarios_usuario_id_fkey
 foreign key(usuario_id) references auth.users(id) on delete restrict;
select ok(cercly_account_private.tiene_dependencias('c9260000-0000-0000-0000-000000000001'),
  'cambiar CASCADE por RESTRICT vuelve a bloquear');
alter table cercly_rutas_privado.rutas_limites_usuarios
 drop constraint rutas_limites_usuarios_usuario_id_fkey;
alter table cercly_rutas_privado.rutas_limites_usuarios add constraint rutas_limites_usuarios_usuario_id_fkey
 foreign key(usuario_id) references auth.users(id) on delete cascade not valid;
select ok(cercly_account_private.tiene_dependencias('c9260000-0000-0000-0000-000000000001'),
  'una FK sin validar no entra en la excepción');
alter table cercly_rutas_privado.rutas_limites_usuarios validate constraint rutas_limites_usuarios_usuario_id_fkey;
select ok(not cercly_account_private.tiene_dependencias('c9260000-0000-0000-0000-000000000001'),
  'solo la definición exacta validada restaura el caso permitido');

set local role authenticated;
select set_config('request.jwt.claim.sub','c9260000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"session_id":"c9260000-0000-0000-0000-000000000001"}',true);
select is(public.solicitar_eliminacion_cuenta(),'pendiente',
  'el usuario con cuota y sesión reciente puede solicitar eliminación');
reset role;
select ok(public.validar_eliminacion_cuenta('c9260000-0000-0000-0000-000000000001'),
  'la validación del servidor permite la identidad sintética sin dependencias');
select lives_ok($$delete from auth.users where id='c9260000-0000-0000-0000-000000000001'$$,
  'se elimina la identidad sintética con sus cascadas');
select is((select count(*)::int from cercly_rutas_privado.rutas_limites_usuarios
 where usuario_id='c9260000-0000-0000-0000-000000000001'),0,'la cuota desaparece');
select is((select count(*)::int from public.usuarios
 where id='c9260000-0000-0000-0000-000000000001'),0,'el perfil desaparece');
select is((select count(*)::int from auth.sessions
 where user_id='c9260000-0000-0000-0000-000000000001'),0,'las sesiones desaparecen');
select lives_ok($$select public.finalizar_eliminacion_cuenta('c9260000-0000-0000-0000-000000000001')$$,
  'se finaliza el caso sin conservar la solicitud de la identidad borrada');

select * from finish();
rollback;
