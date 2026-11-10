-- Incremental local sobre 28 migraciones. No cambia reglas, datos ni ACL.
-- 40001 es serialización del motor; un conflicto de negocio devuelve PT409.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
do $patch$
declare
 spec record;
 target regprocedure;
 previous record;
 updated record;
 new_body text;
 definition text;
begin
 for spec in select * from (values
  ('public.autorizar_supresion_revisada_qa(uuid,text,text,boolean)',
   '81737dfa35a319793cd99b7c1a3759c5','errcode=''40001''','errcode=''PT409''',1),
  ('public.guardar_preferencias_usuario(uuid[],integer,boolean,bigint)',
   'ddfb081f6d7681e612628213812e7a37','errcode = ''40001''','errcode = ''PT409''',2)
 ) v(signature,expected_body_md5,old_token,new_token,expected_count) loop
  target:=to_regprocedure(spec.signature);
  if target is null then
   raise exception using errcode='42883',message='Falta una RPC prevista para el cambio de conflictos';
  end if;
  select proowner,prosecdef,proconfig,proacl,prosrc into previous from pg_proc where oid=target;
  if md5(previous.prosrc)<>spec.expected_body_md5 then
   raise exception using errcode='P0001',message='La RPC no coincide con la versión revisada de 28 migraciones';
  end if;
  if (length(previous.prosrc)-length(replace(previous.prosrc,spec.old_token,'')))/length(spec.old_token)
     <>spec.expected_count then
   raise exception using errcode='P0001',message='Cantidad de errores de negocio distinta de la revisada';
  end if;
  new_body:=replace(previous.prosrc,spec.old_token,spec.new_token);
  definition:=pg_get_functiondef(target);
  -- Solo sustituye los tokens acreditados. No captura errores reales del motor,
  -- reintenta transacciones ni reescribe las reglas de autorización.
  execute replace(definition,spec.old_token,spec.new_token);
  select proowner,prosecdef,proconfig,proacl,prosrc into updated from pg_proc where oid=target;
  if updated.prosrc is distinct from new_body
   or (updated.proowner,updated.prosecdef,updated.proconfig,updated.proacl)
      is distinct from (previous.proowner,previous.prosecdef,previous.proconfig,previous.proacl) then
   raise exception using errcode='P0001',message='Cambio inesperado de cuerpo o seguridad al corregir conflictos';
  end if;
 end loop;
end $patch$;
commit;
