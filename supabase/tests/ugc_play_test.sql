-- Solo contenedor nuevo y datos sintéticos. Nunca ejecutar en un proyecto alojado.
begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('e9260000-0000-0000-0000-000000000001','ugc-owner@cercly.test','{}'),
 ('e9260000-0000-0000-0000-000000000002','ugc-reader@cercly.test','{}'),
 ('e9260000-0000-0000-0000-000000000003','ugc-admin@cercly.test','{}'),
 ('e9260000-0000-0000-0000-000000000004','ugc-other@cercly.test','{}');
insert into auth.sessions(id,user_id,created_at) select id,id,now() from auth.users where email like 'ugc-%@cercly.test';
update public.usuarios set rol='administrador' where id='e9260000-0000-0000-0000-000000000003';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
select ('e9270000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'e9260000-0000-0000-0000-000000000001',
 (select id from public.categorias limit 1),'Negocio UGC '||i,'Dirección sintética',0,0,'aprobado',true from generate_series(1,12)i;
insert into public.fotos_establecimiento(id,establecimiento_id,ruta_storage) values
 ('e9280000-0000-0000-0000-000000000001','e9270000-0000-0000-0000-000000000001','e9260000-0000-0000-0000-000000000001/foto.png');
insert into public.promociones(id,establecimiento_id,titulo,fecha_inicio,fecha_fin) values
 ('e9290000-0000-0000-0000-000000000001','e9270000-0000-0000-0000-000000000001','Promoción UGC',now()-interval '1 day',now()+interval '1 day');
select ok(not has_schema_privilege('authenticated','cercly_ugc_privado','usage'),'esquema privado sin API directa');
select ok(not has_table_privilege('authenticated','cercly_ugc_privado.denuncias','insert'),'no se pueden falsificar denuncias por tabla');
select ok(not has_table_privilege('authenticated','cercly_ugc_privado.bloqueos','delete'),'no se pueden borrar bloqueos ajenos');
select ok(not cercly_account_private.tiene_dependencias('00000000-0000-0000-0000-000000000000'),'las FK nuevas no bloquean globalmente la eliminación');

set local role authenticated;
select set_config('request.jwt.claim.sub','e9260000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"e9260000-0000-0000-0000-000000000001","session_id":"e9260000-0000-0000-0000-000000000001"}',true);
select throws_ok($$select public.ugc_exigir_normas()$$,'42501',null,'sin aceptación no puede publicar');
select throws_ok($$update public.establecimientos set descripcion='Sin aceptación' where id='e9270000-0000-0000-0000-000000000001'$$,'42501',null,'REST directo tampoco evita la aceptación');
select throws_ok($$select public.ugc_aceptar_normas('inventada','inventada')$$,'22023',null,'rechaza versión o huella falsa');
select lives_ok($$select public.ugc_aceptar_normas(public.ugc_normas_publicacion()->>'version',public.ugc_normas_publicacion()->>'huella')$$,'aceptación versionada registrada por servidor');
select is(public.ugc_normas_publicacion()->>'aceptadas','true','recupera aceptación propia');
select results_eq(
 $$insert into public.fotos_establecimiento(id,establecimiento_id,ruta_storage,orden)
   values ('e9280000-0000-0000-0000-000000000002','e9270000-0000-0000-0000-000000000001',
           'e9260000-0000-0000-0000-000000000001/portada.png',1) returning id$$,
 $$values ('e9280000-0000-0000-0000-000000000002'::uuid)$$,
 'la foto recién insertada es visible para RETURNING del propietario'
);
select results_eq(
 $$insert into public.promociones(id,establecimiento_id,titulo,fecha_inicio,fecha_fin)
   values ('e9290000-0000-0000-0000-000000000002','e9270000-0000-0000-0000-000000000001',
           'Promoción nueva',now()-interval '1 day',now()+interval '1 day') returning id$$,
 $$values ('e9290000-0000-0000-0000-000000000002'::uuid)$$,
 'la promoción recién insertada es visible para RETURNING del propietario'
);
select lives_ok($$update public.promociones set titulo='Contenido válido' where id='e9290000-0000-0000-0000-000000000001'$$,'puede publicar tras aceptar');
reset role;
select is((select count(*)::int from cercly_ugc_privado.aceptaciones where usuario_id='e9260000-0000-0000-0000-000000000001'),1,'aceptación única y con sujeto de sesión');
select ok((select aceptada_en<=now() and huella ~ '^[a-f0-9]{64}$' from cercly_ugc_privado.aceptaciones limit 1),'fecha y SHA de normas verificables');

set local role authenticated;
select set_config('request.jwt.claim.sub','e9260000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"e9260000-0000-0000-0000-000000000002","session_id":"e9260000-0000-0000-0000-000000000002"}',true);
select lives_ok($$select public.ugc_denunciar('establecimiento','e9270000-0000-0000-0000-000000000001','enganoso','Descripción engañosa')$$,'denuncia sin exigir aceptar términos de publicación');
select is(public.ugc_denunciar('establecimiento','e9270000-0000-0000-0000-000000000001','enganoso','Duplicado'),public.ugc_denunciar('establecimiento','e9270000-0000-0000-0000-000000000001','ofensivo','Duplicado'),'duplicados abiertos devuelven mismo caso');
select is(jsonb_array_length(public.ugc_mis_denuncias()),1,'duplicación no crea filas masivas');
select lives_ok($$select public.ugc_denunciar('fotografia','e9280000-0000-0000-0000-000000000001','derechos','Foto sin derechos')$$,'denuncia foto');
select lives_ok($$select public.ugc_denunciar('promocion','e9290000-0000-0000-0000-000000000001','ilegal','Promoción ilegal')$$,'denuncia promoción');
select lives_ok($$select public.ugc_denunciar('propietario','e9270000-0000-0000-0000-000000000001','spam','Conducta del responsable')$$,'denuncia responsable sin aceptar UUID arbitrario de usuario');
select throws_ok($$select public.ugc_denunciar('inventado','e9270000-0000-0000-0000-000000000001','otro','')$$,'22023',null,'tipo inválido rechazado');
select throws_ok($$select public.ugc_denunciar('establecimiento','e9270000-0000-0000-0000-000000000001','otro',repeat('x',501))$$,'22023',null,'texto excesivo rechazado');
select throws_ok($$select public.ugc_denuncias_admin()$$,'42501',null,'cliente no puede leer cola ajena');
select lives_ok($$select public.ugc_bloquear_responsable('establecimiento','e9270000-0000-0000-0000-000000000001')$$,'bloqueo por responsable real del servidor');
select is(jsonb_array_length(public.ugc_mis_bloqueos()),1,'bloqueo persistido');
select is((select count(*)::int from public.establecimientos where id='e9270000-0000-0000-0000-000000000001'),0,'RLS oculta ficha bloqueada');
select is((select count(*)::int from public.fotos_establecimiento where id='e9280000-0000-0000-0000-000000000001'),0,'RLS oculta fotos del responsable');
select is((select count(*)::int from public.promociones where id='e9290000-0000-0000-0000-000000000001'),0,'RLS oculta promociones del responsable');
select lives_ok($$select public.ugc_desbloquear('e9260000-0000-0000-0000-000000000001')$$,'puede revertir bloqueo propio');
select is((select count(*)::int from public.establecimientos where id='e9270000-0000-0000-0000-000000000001'),1,'ficha vuelve tras desbloquear');
select public.ugc_denunciar('establecimiento',('e9270000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'spam','Reporte de prueba') from generate_series(2,7)i;
select throws_ok($$select public.ugc_denunciar('establecimiento','e9270000-0000-0000-0000-000000000008','spam','Exceso')$$,'P0001',null,'cuota compartida impide reporte 11 en una hora');

select set_config('request.jwt.claim.sub','e9260000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"e9260000-0000-0000-0000-000000000004","session_id":"e9260000-0000-0000-0000-000000000004"}',true);
select is(jsonb_array_length(public.ugc_mis_denuncias()),0,'no ve denuncias ajenas');
select is(jsonb_array_length(public.ugc_mis_bloqueos()),0,'no ve bloqueos ajenos');

select set_config('request.jwt.claim.sub','e9260000-0000-0000-0000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"e9260000-0000-0000-0000-000000000003","session_id":"e9260000-0000-0000-0000-000000000003"}',true);
select is(jsonb_array_length(public.ugc_denuncias_admin()),10,'admin recibe cola limitada');
select lives_ok($$select public.ugc_revisar_denuncia((select (x->>'id')::uuid from jsonb_array_elements(public.ugc_denuncias_admin()) x where x->>'tipo'='establecimiento' and x->>'objetivo_id'='e9270000-0000-0000-0000-000000000001'),'en_revision','Revisión iniciada por administrador')$$,'admin cambia estado con motivo');
select lives_ok($$select public.ugc_revisar_denuncia((public.ugc_denuncias_admin('en_revision')->0->>'id')::uuid,'retirada','Contenido retirado por incumplimiento')$$,'admin retira contenido');
reset role;
select is((select count(*)::int from cercly_ugc_privado.revisiones),2,'historial de transiciones mínimo e inmutable para clientes');
select ok(cercly_account_private.tiene_dependencias('e9260000-0000-0000-0000-000000000002'),'denunciante requiere revisión de privacidad sin destruir evidencia ajena');
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
select is((select count(*)::int from public.establecimientos where id='e9270000-0000-0000-0000-000000000001'),0,'retirada oculta contenido al público');
select throws_ok($$select public.ugc_denunciar('establecimiento','e9270000-0000-0000-0000-000000000002','otro','')$$,'42501',null,'anónimo no puede denunciar');
reset role;
select * from finish();
rollback;
