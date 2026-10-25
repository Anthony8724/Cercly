-- Fixtures sintéticos; ejecutar solo en una instancia local aislada.
begin;
select plan(27);
insert into auth.users(id,email,raw_user_meta_data) values
 ('b6000000-0000-0000-0000-000000000001','recovery@cercly.test','{"nombre":"  ","full_name":"Persona Google","rol":"administrador"}'),
 ('b6000000-0000-0000-0000-000000000002','owner@cercly.test','{}'),
 ('b6000000-0000-0000-0000-000000000003','admin@cercly.test','{}');
select is((select nombre::text from public.usuarios where id='b6000000-0000-0000-0000-000000000001'), 'Persona Google', 'trigger admite nombre Google después de nombre vacío');
select is((select rol::text from public.usuarios where id='b6000000-0000-0000-0000-000000000001'), 'usuario', 'trigger ignora rol de metadatos');
update public.usuarios set rol='propietario', nombre='Nombre conservado' where id='b6000000-0000-0000-0000-000000000002';
update public.usuarios set rol='administrador' where id='b6000000-0000-0000-0000-000000000003';
delete from public.usuarios where id='b6000000-0000-0000-0000-000000000001';
select ok(not has_function_privilege('anon','public.recuperar_mi_perfil()','EXECUTE'), 'anon no ejecuta RPC');
select ok(not has_function_privilege('authenticated','cercly_auth_private.insertar_perfil_basico(uuid,jsonb,text)','EXECUTE'), 'cliente no invoca helper con otra identidad');
select ok(not has_table_privilege('authenticated','public.usuarios','INSERT'), 'cliente sin INSERT directo');
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok('select * from public.recuperar_mi_perfil()', '28000', 'Sesión requerida', 'sin identidad rechaza');
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000099',true);
select throws_ok('select * from public.recuperar_mi_perfil()', '28000', 'Sesión inválida', 'identidad inexistente rechaza');
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000001',true);
select is((select rol from public.recuperar_mi_perfil()),'usuario', 'recupera con rol mínimo');
select is((select id::text from public.recuperar_mi_perfil()),'b6000000-0000-0000-0000-000000000001', 'retorna solo identidad propia');
select is((select count(*)::integer from public.recuperar_mi_perfil()),1, 'repetición devuelve un perfil');
select is((select count(*)::integer from public.usuarios),1, 'RLS oculta perfiles ajenos');
select is((select nombre::text from public.usuarios),'Persona Google', 'recuperación admite metadatos descriptivos');
select throws_ok($$update public.usuarios set rol='administrador'$$,'42501','permission denied for table usuarios','no se autoconcede administrador');
select throws_ok($$update public.usuarios set rol='propietario'$$,'42501','permission denied for table usuarios','no se autoconcede propietario');
select throws_ok($$insert into public.usuarios(id,nombre,rol) values ('b6000000-0000-0000-0000-000000000001','Ataque','administrador')$$,'42501','permission denied for table usuarios','INSERT directo rechazado');
select throws_ok($$select * from public.recuperar_mi_perfil('b6000000-0000-0000-0000-000000000002'::uuid)$$,'42883',null,'RPC no acepta identidad ajena');
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000002',true);
select is((select rol from public.recuperar_mi_perfil()),'propietario','conserva propietario autorizado');
select is((select nombre::text from public.usuarios where id=auth.uid()),'Nombre conservado','conserva nombre existente');
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000003',true);
select is((select rol from public.recuperar_mi_perfil()),'administrador','conserva administrador autorizado');
select is((select count(*)::integer from public.recuperar_mi_perfil()),1,'administrador recibe solo su propio perfil');
reset role;
select is((select count(*)::integer from public.usuarios where id::text like 'b6000000%'),3,'sin duplicados');
select ok(not (select prosecdef from pg_proc where oid='public.recuperar_mi_perfil()'::regprocedure),'RPC pública conserva RLS');
-- Un fallo del perfil debe revertir el alta Auth, sin detalle sensible al cliente.
alter table public.usuarios add constraint prueba_fallo_perfil check(nombre <> 'Fallar perfil');
select throws_ok($$insert into auth.users(id,email,raw_user_meta_data) values ('b6000000-0000-0000-0000-000000000004','fail@cercly.test','{"nombre":"Fallar perfil"}')$$,'P0001','No se pudo crear el perfil','fallo de trigger visible y sanitizado');
select is((select count(*)::integer from auth.users where id='b6000000-0000-0000-0000-000000000004'),0,'fallo revierte alta sin huérfanos');
-- PostgREST actual transmite claims JSON; no limitar la prueba al GUC legacy.
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"sub":"b6000000-0000-0000-0000-000000000001","role":"authenticated","user_metadata":{"rol":"administrador"}}',true);
select is((select rol from public.recuperar_mi_perfil()),'usuario','claims JSON recuperan sin elevar rol desde metadatos');
select is((select count(*)::integer from public.usuarios),1,'RLS con claims JSON aísla perfiles');
select ok(not public.es_administrador(),'claims JSON de usuario no autorizan administración');
reset role;
select * from finish();
rollback;
