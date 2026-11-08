begin;
select no_plan();
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',('b8800000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,
'authenticated','authenticated','correccion-'||i||'@cercly.test','',now(),'{}','{}',now(),now() from generate_series(1,3)i;
update public.usuarios set rol='administrador' where id='b8800000-0000-0000-0000-000000000001';
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,descripcion,telefono_publico,latitud,longitud,estado,fuente,publicable)
select 'b8800000-0000-0000-0000-000000000010','b8800000-0000-0000-0000-000000000002',id,
'Nombre anterior','Dirección anterior','Descripción anterior','',0.8,-77.7,'aprobado','cercly',true
from public.categorias where activa order by id limit 1;
insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,fuente,publicable)
select 'b8800000-0000-0000-0000-000000000011','b8800000-0000-0000-0000-000000000003',id,
'Negocio ajeno','Otra dirección',0.81,-77.71,'aprobado','cercly',true
from public.categorias where activa order by id limit 1;
create temp table propuesta as select jsonb_build_object('cambios',jsonb_build_object(
  'nombre',jsonb_build_object('anterior',nombre,'nuevo','Nombre propuesto'),
  'direccion',jsonb_build_object('anterior',direccion,'nuevo','Dirección propuesta'),
  'latitud',jsonb_build_object('anterior',latitud,'nuevo',0.80525),
  'longitud',jsonb_build_object('anterior',longitud,'nuevo',-77.73434),
  'categoria_id',jsonb_build_object('anterior',categoria_id,'nuevo',
    (select id from public.categorias where activa and id<>categoria_id order by id limit 1)),
  'telefono_publico',jsonb_build_object('anterior',telefono_publico,'nuevo','0999999999'))) datos
from public.establecimientos where id='b8800000-0000-0000-0000-000000000010';
grant select on propuesta to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000003',true);
update public.establecimientos set nombre='Intrusión' where id='b8800000-0000-0000-0000-000000000010';
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Nombre anterior','propietario ajeno no edita negocio');
select throws_ok($$insert into public.solicitudes_establecimientos(solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion','No soy propietario',datos from propuesta$$,
'P0001','Solo el propietario o un colaborador activo puede solicitar una corrección.','tercero no propone corrección');
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000002',true);
select lives_ok($$insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
values('b8800000-0000-0000-0000-000000000030',auth.uid(),'b8800000-0000-0000-0000-000000000011','correccion','Texto libre heredado','{"descripcion_solicitud":"algo"}')$$,
'cliente manual sigue pudiendo presentar una solicitud');
select throws_ok($$insert into public.solicitudes_establecimientos(solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion','Campo inesperado',
jsonb_build_object('cambios',jsonb_build_object('propietario_id',jsonb_build_object('anterior',auth.uid(),'nuevo',null)))$$,
'P0001',null,'el usuario no propone propiedad');
select throws_ok($$insert into public.solicitudes_establecimientos(solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion','Valor anterior falso',
jsonb_build_object('cambios',jsonb_build_object('nombre',jsonb_build_object('anterior','Falso','nuevo','Nuevo')))$$,
'P0001','La ficha cambió. Actualiza la propuesta antes de enviarla.','valor actual falsificado se rechaza');
select throws_ok($$insert into public.solicitudes_establecimientos(solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion','Coordenada inválida',
jsonb_build_object('cambios',jsonb_build_object('latitud',jsonb_build_object('anterior',0.8,'nuevo',91)))$$,
'P0001','Coordenada inválida.','geografía inválida se rechaza');
select lives_ok($$insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select 'b8800000-0000-0000-0000-000000000020',auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion','Solicito datos propuestos',datos from propuesta$$,
'propietario presenta cambios estructurados');
select throws_ok($$insert into public.solicitudes_establecimientos(solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion','Duplicado',datos from propuesta$$,
'23505','duplicate key value violates unique constraint "solicitud_pendiente_unica"','duplicado pendiente rechazado');
select throws_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','motivo')$$,
'P0001','Solo un administrador autenticado puede aprobar correcciones.','propietario no se autoaprueba');
select throws_ok($$select public.moderar_estado_establecimiento('b8800000-0000-0000-0000-000000000010','aprobado',true)$$,
'42501','Administrador autenticado requerido','propietario no modera estado');
select ok(not has_function_privilege('anon','public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)','EXECUTE'),'anon no modera');
select ok(not has_function_privilege('anon','public.aplicar_correccion_establecimiento(uuid,text)','EXECUTE'),'anon sin permiso RPC');
select ok(not has_table_privilege('authenticated','public.correcciones_aplicadas','INSERT,UPDATE,DELETE'),'cliente sin escritura del historial');
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select ok(not has_table_privilege('authenticated','public.establecimientos','UPDATE'),'sin UPDATE general de establecimiento');
select throws_ok($$update public.establecimientos set nombre='Intrusión admin'
where id='b8800000-0000-0000-0000-000000000010'$$,
'42501','El administrador solo puede moderar el estado directamente','admin no edita información directa');
select throws_ok($$update public.establecimientos set nombre='Intrusión',estado='rechazado'
where id='b8800000-0000-0000-0000-000000000010'$$,
'42501','El administrador solo puede moderar el estado directamente','mezclar moderación y datos se rechaza');
select throws_ok($$update public.establecimientos set categoria_id=categoria_id
where id='b8800000-0000-0000-0000-000000000010'$$,
'42501',null,'sin privilegio directo sobre categoría');
select throws_ok($$insert into public.establecimiento_categorias(establecimiento_id,subcategoria_id,es_principal)
select 'b8800000-0000-0000-0000-000000000010',id,true from public.subcategorias where activa limit 1$$,
'42501',null,'admin no usa trigger de categoría para eludir aprobación');
select throws_ok($$select public.reemplazar_horarios_establecimiento(
'b8800000-0000-0000-0000-000000000010',
'[{"dia_semana":1,"apertura_minutos":480,"cierre_minutos":1080}]'::jsonb)$$,
'42501',null,'RPC invoker de horarios no permite eludir responsabilidad');
select throws_ok($$insert into public.fotos_establecimiento(establecimiento_id,ruta_storage)
values ('b8800000-0000-0000-0000-000000000010','qa/no-existe.jpg')$$,
'42501',null,'admin no modifica fotos como responsable');
select ok(not has_function_privilege('service_role','public.aplicar_correccion_establecimiento(uuid,text)','EXECUTE'),'RPC de corrección no concede entrada server innecesaria');
select lives_ok($$update public.establecimientos set estado='rechazado'
where id='b8800000-0000-0000-0000-000000000010'$$,'moderación de rechazo sigue disponible');
select is((select publicable from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),false,'rechazo retira publicación');
select lives_ok($$select public.moderar_estado_establecimiento('b8800000-0000-0000-0000-000000000010','aprobado',true)$$,'RPC de moderación aprueba y publica explícitamente');
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Nombre anterior','moderación no altera información');
select set_config('cercly.correction_rpc','true',true);
select throws_ok($$update public.establecimientos set nombre='GUC falsificado'
where id='b8800000-0000-0000-0000-000000000010'$$,
'42501',null,'un flag del cliente no autoriza edición');
select lives_ok($$select public.responder_solicitud_establecimiento('b8800000-0000-0000-0000-000000000030','aprobada','Revisión manual')$$,'solicitud de texto puede revisarse manualmente');
select is((select count(*)::int from public.correcciones_aplicadas),0,'revisión manual no inventa aplicación auditada');
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000011'),'Negocio ajeno','revisión manual no cambia ficha');
select throws_ok($$select public.responder_solicitud_establecimiento('b8800000-0000-0000-0000-000000000020','aprobada','sin cambios')$$,
'P0001','La corrección debe aplicarse y auditarse antes de aprobar.','RPC antigua no aprueba');
select throws_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','')$$,
'P0001','La justificación es obligatoria y admite hasta 1000 caracteres.','aprobación exige motivo');
reset role;
create function public.prueba_fallo_aprobacion() returns trigger language plpgsql as $$begin raise exception 'Fallo de aprobación'; end;$$;
create trigger prueba_fallo_aprobacion before update on public.solicitudes_establecimientos
for each row execute function public.prueba_fallo_aprobacion();
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','Verificado')$$,
'P0001','Fallo de aprobación','fallo final revierte toda la operación');
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Nombre anterior','rollback revierte negocio');
select is((select count(*)::integer from public.correcciones_aplicadas),0,'rollback no deja historial falso');
reset role;
drop trigger prueba_fallo_aprobacion on public.solicitudes_establecimientos;
drop function public.prueba_fallo_aprobacion();
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
reset role;
update public.categorias set activa=false where id=(select (datos->'cambios'->'categoria_id'->>'nuevo')::uuid from propuesta);
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','Verificado')$$,
'P0001','La categoría propuesta ya no está disponible.','categoría desactivada entre solicitud y aprobación impide aplicar');
reset role;
update public.categorias set activa=true where id=(select (datos->'cambios'->'categoria_id'->>'nuevo')::uuid from propuesta);

-- Simula una solicitud heredada anterior al trigger. La RPC debe validar
-- también el contenido interno, no asumir que todas las filas pasaron por él.
alter table public.solicitudes_establecimientos disable trigger validar_correccion_estructurada;
update public.solicitudes_establecimientos
set datos_propuestos=jsonb_build_object('cambios',jsonb_build_object(
  'nombre',jsonb_build_object('anterior','Nombre anterior')))
where id='b8800000-0000-0000-0000-000000000020';
alter table public.solicitudes_establecimientos enable trigger validar_correccion_estructurada;
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','Verificado')$$,
'P0001','La propuesta antigua no contiene un cambio estructurado válido.','RPC rechaza propuesta heredada incompleta');
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Nombre anterior','propuesta heredada inválida no modifica negocio');
reset role;
alter table public.solicitudes_establecimientos disable trigger validar_correccion_estructurada;
update public.solicitudes_establecimientos
set datos_propuestos=(select datos from propuesta)
where id='b8800000-0000-0000-0000-000000000020';
alter table public.solicitudes_establecimientos enable trigger validar_correccion_estructurada;

set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','Verificado')$$,
'administrador aprueba exactamente la propuesta');
select is((select estado::text from public.solicitudes_establecimientos where id='b8800000-0000-0000-0000-000000000020'),'aprobada','solicitud aprobada');
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Nombre propuesto','nombre solicitado aplicado');
select is((select direccion from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Dirección propuesta','dirección solicitada aplicada');
select is((select categoria_id from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),
(select (datos->'cambios'->'categoria_id'->>'nuevo')::uuid from propuesta),'categoría solicitada aplicada');
select is((select telefono_publico from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'0999999999','contacto solicitado aplicado');
select is((select descripcion from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Descripción anterior','campo no solicitado intacto');
select is((select propietario_id from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'b8800000-0000-0000-0000-000000000002'::uuid,'propiedad intacta');
select is((select extensions.st_y(ubicacion::extensions.geometry) from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),0.80525::double precision,'geografía recalculada');
select is((select antes->>'nombre' from public.correcciones_aplicadas),'Nombre anterior','auditoría conserva antes');
select is((select despues->>'nombre' from public.correcciones_aplicadas),'Nombre propuesto','auditoría conserva después');
select is((select solicitante_id from public.correcciones_aplicadas),'b8800000-0000-0000-0000-000000000002'::uuid,'historial guarda solicitante');
select is((select revisado_por from public.correcciones_aplicadas),auth.uid(),'historial guarda revisor');
select ok((select conservar_hasta >= cerrado_en + interval '24 months' - interval '1 minute' from public.correcciones_aplicadas),'retención 24 meses sin autoeliminación');
select throws_ok($$select public.aplicar_correccion_establecimiento('b8800000-0000-0000-0000-000000000020','otra vez')$$,
'P0001','Se requiere una corrección pendiente.','doble aprobación prohibida');
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000003',true);
select is((select count(*)::integer from public.correcciones_aplicadas),0,'tercero no lee historial');
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.correcciones_aplicadas),1,'solicitante lee historial');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000002',true);
insert into public.solicitudes_establecimientos(id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
select 'b8800000-0000-0000-0000-000000000021',auth.uid(),'b8800000-0000-0000-0000-000000000010','correccion',
'Otra solicitud estructurada',jsonb_build_object('cambios',jsonb_build_object('nombre',jsonb_build_object('anterior','Nombre propuesto','nuevo','Nuevo nombre')));
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.responder_solicitud_establecimiento('b8800000-0000-0000-0000-000000000021','rechazada','No procede')$$,'rechazo permitido');
select is((select nombre from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'),'Nombre propuesto','rechazo no cambia negocio');
select is((select count(*)::integer from public.correcciones_aplicadas),1,'rechazo sin auditoría de aplicación');
reset role;
select ok(cercly_account_private.tiene_dependencias('b8800000-0000-0000-0000-000000000002'),'eliminación de cuenta detecta solicitudes auditadas');
select throws_ok($$delete from auth.users where id='b8800000-0000-0000-0000-000000000002'$$,
'23503',null,'borrado de identidad no borra historial en cascada');
select throws_ok($$delete from public.establecimientos where id='b8800000-0000-0000-0000-000000000010'$$,
'23503',null,'ficha con historial exige tratamiento explícito de retención');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8800000-0000-0000-0000-000000000001',true);
select throws_ok($$update public.correcciones_aplicadas set motivo='Borrar trazabilidad'$$,
'42501',null,'admin de aplicación no reescribe auditoría');
delete from public.solicitudes_establecimientos where id='b8800000-0000-0000-0000-000000000021';
select is((select count(*)::int from public.solicitudes_establecimientos where id='b8800000-0000-0000-0000-000000000021'),1,'rechazo conserva la decisión cerrada');
select lives_ok($$update public.solicitudes_establecimientos set estado='pendiente'
where id='b8800000-0000-0000-0000-000000000020'$$,'RLS filtra actualización administrativa cerrada');
select is((select estado::text from public.solicitudes_establecimientos where id='b8800000-0000-0000-0000-000000000020'),'aprobada','admin no reabre aplicación auditada');
select lives_ok($$update public.solicitudes_establecimientos set mensaje='Alterar propuesta cerrada'
where id='b8800000-0000-0000-0000-000000000030'$$,'RLS filtra edición de revisión manual cerrada');
select is((select mensaje from public.solicitudes_establecimientos where id='b8800000-0000-0000-0000-000000000030'),'Texto libre heredado','revisión manual conserva contenido');
reset role;
select throws_ok($$update public.solicitudes_establecimientos set estado='pendiente'
where id='b8800000-0000-0000-0000-000000000020'$$,'42501','Una corrección cerrada no puede modificarse.','trigger también protege filas cerradas de rol de mantenimiento');
select * from finish();
rollback;
