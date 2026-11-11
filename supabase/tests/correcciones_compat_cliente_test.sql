-- Solo fixtures locales: regresión del payload antiguo y del contrato actualizado.
-- El cliente corregido usa propuestas; nunca interpretar el rechazo como edición.
begin;
select plan(7);
insert into auth.users(id,email,raw_user_meta_data) values
 ('ba110000-0000-0000-0000-000000000001','compat-owner@cercly.test','{}'),
 ('ba110000-0000-0000-0000-000000000002','compat-admin@cercly.test','{}');
update public.usuarios set rol='administrador' where id='ba110000-0000-0000-0000-000000000002';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select 'ba110000-0000-0000-0000-000000000010','ba110000-0000-0000-0000-000000000001',id,
 'Compatibilidad original','Dirección sintética',0.8,-77.7,'aprobado',true
from public.categorias where activa order by id limit 1;
set local role authenticated;
select set_config('request.jwt.claim.sub','ba110000-0000-0000-0000-000000000001',true);
select throws_ok($$update public.establecimientos set nombre='Edición del cliente',estado='pendiente'
 where id='ba110000-0000-0000-0000-000000000010'$$,
 '42501','Ficha aprobada: solicitud de correccion requerida',
 'payload heredado sigue rechazado sin aplicar cambios parciales');
select is((select estado::text from public.establecimientos where id='ba110000-0000-0000-0000-000000000010'),
 'aprobado','rechazo no cambia estado');
select is((select nombre from public.establecimientos where id='ba110000-0000-0000-0000-000000000010'),
 'Compatibilidad original','rechazo no aplica parcialmente el nombre');
select throws_ok($$update public.establecimientos set nombre='Edición autorizada sin estado'
 where id='ba110000-0000-0000-0000-000000000010'$$,
 '42501','Ficha aprobada: solicitud de correccion requerida',
 'ficha aprobada exige propuesta incluso sin cambiar estado');
select set_config('request.jwt.claim.sub','ba110000-0000-0000-0000-000000000002',true);
update public.establecimientos set estado='rechazado' where id='ba110000-0000-0000-0000-000000000010';
select is((select publicable from public.establecimientos where id='ba110000-0000-0000-0000-000000000010'),false,
 'moderación heredada retira publicación al rechazar');
update public.establecimientos set estado='aprobado' where id='ba110000-0000-0000-0000-000000000010';
select is((select publicable from public.establecimientos where id='ba110000-0000-0000-0000-000000000010'),false,
 'panel heredado no vuelve a publicar por aprobar solo estado');
select public.moderar_estado_establecimiento('ba110000-0000-0000-0000-000000000010','aprobado',true);
select is((select publicable from public.establecimientos where id='ba110000-0000-0000-0000-000000000010'),true,
 'RPC autorizada permite publicación explícita sin editar información');
select * from finish();
rollback;
