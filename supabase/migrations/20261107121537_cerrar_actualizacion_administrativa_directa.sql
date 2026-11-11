-- Solo preparación local. Requiere 20261106034310; no modifica filas existentes.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Quitar tanto el grant general como posibles ACL de columnas heredadas.
revoke update on public.establecimientos from public, anon, authenticated;
do $$ declare columnas text; begin
 select string_agg(quote_ident(attname), ',') into columnas from pg_attribute
 where attrelid='public.establecimientos'::regclass and attnum>0 and not attisdropped;
 execute 'revoke update (' || columnas || ') on public.establecimientos from public,anon,authenticated';
end $$;
-- Contrato de la edición actual del propietario y moderación del panel.
grant update(nombre,descripcion,direccion,telefono_publico,estado)
 on public.establecimientos to authenticated;

drop policy "propietario o administrador actualiza establecimiento" on public.establecimientos;
create policy "propietario actualiza informacion propia" on public.establecimientos
 for update to authenticated
 using (propietario_id=(select auth.uid()))
 with check (propietario_id=(select auth.uid()));
create policy "administrador modera estado" on public.establecimientos
 for update to authenticated
 using ((select public.es_administrador()))
 with check ((select public.es_administrador()));

-- ubicacion es generada y NEW aún no la calcula en BEFORE UPDATE.
-- Sus entradas latitud/longitud siguen protegidas por ACL y comparación.
-- SECURITY INVOKER: current_user distingue DML del cliente de las RPC
-- SECURITY DEFINER revisadas. No se confía en flags/GUC elegidos por el cliente.
create function public.limitar_actualizacion_directa_establecimiento()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user in ('postgres','supabase_admin') then return new; end if;
 if current_user <> 'authenticated' or auth.uid() is null then
   raise exception using errcode='42501', message='Procedimiento autorizado requerido';
 end if;
 if public.es_administrador() then
   if (to_jsonb(new)-array['estado','actualizado_en','ubicacion']) is distinct from
      (to_jsonb(old)-array['estado','actualizado_en','ubicacion']) then
     raise exception using errcode='42501', message='El administrador solo puede moderar el estado directamente';
   end if;
   -- Rechazar una ficha publicada exige retirar su publicación por CHECK.
   if new.estado <> 'aprobado' then new.publicable := false; end if;
 elsif not public.puede_gestionar_como_propietario(old.id) then
   raise exception using errcode='42501', message='Establecimiento ajeno';
 end if;
 return new;
end $$;
revoke all on function public.limitar_actualizacion_directa_establecimiento()
 from public,anon,authenticated,service_role;
create trigger limitar_actualizacion_directa_establecimiento
 before update on public.establecimientos for each row
 execute function public.limitar_actualizacion_directa_establecimiento();

-- Rutas indirectas: categorías sincroniza categoria_id mediante un definer;
-- horarios/fotos son información del negocio, no moderación de su estado.
do $$ declare tabla text; operacion text; begin
 foreach tabla in array array['establecimiento_categorias','horarios_establecimiento','fotos_establecimiento'] loop
   foreach operacion in array array['insert','update','delete'] loop
     execute format('create policy %I on public.%I as restrictive for %s to authenticated %s',
       'informacion_solo_responsable_'||operacion,tabla,operacion,
       case operacion
       when 'insert' then 'with check (not public.es_administrador() and public.puede_gestionar_como_propietario(establecimiento_id))'
       when 'update' then 'using (not public.es_administrador() and public.puede_gestionar_como_propietario(establecimiento_id)) with check (not public.es_administrador() and public.puede_gestionar_como_propietario(establecimiento_id))'
       else 'using (not public.es_administrador() and public.puede_gestionar_como_propietario(establecimiento_id))' end);
   end loop;
 end loop;
end $$;
-- Ningún cliente necesita invocar directamente estos triggers privilegiados.
revoke all on function public.sincronizar_categoria_principal()
 from public,anon,authenticated,service_role;
alter function public.aplicar_correccion_establecimiento(uuid,text) owner to postgres;
revoke all on function public.aplicar_correccion_establecimiento(uuid,text)
 from public,anon,service_role;
-- Publicación explícita y estado mediante RPC de parámetros cerrados.
create function public.moderar_estado_establecimiento(
 p_id uuid, p_estado public.estado_establecimiento, p_publicable boolean default null)
returns void language plpgsql security definer set search_path='' as $$
declare e public.establecimientos%rowtype;
begin
 if auth.uid() is null or not public.es_administrador() then
   raise exception using errcode='42501', message='Administrador autenticado requerido';
 end if;
 if p_estado is null or (p_publicable is true and p_estado <> 'aprobado') then
   raise exception using errcode='22023', message='Estado y publicación incompatibles';
 end if;
 select * into e from public.establecimientos where id=p_id for update;
 if not found then raise exception using errcode='22023', message='Establecimiento inexistente'; end if;
 update public.establecimientos set estado=p_estado,
 publicable=case when p_estado <> 'aprobado' then false else coalesce(p_publicable,e.publicable) end
 where id=e.id;
end $$;
alter function public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean) owner to postgres;
revoke all on function public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)
 from public,anon,authenticated,service_role;
grant execute on function public.moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean) to authenticated;

-- La moderación no concede borrado de fichas ni de decisiones cerradas.
create policy "admin no borra ficha directamente" on public.establecimientos
 as restrictive for delete to authenticated using (not public.es_administrador());
create policy "conservar decisiones de correccion" on public.solicitudes_establecimientos
 as restrictive for delete to authenticated using (tipo <> 'correccion' or estado='pendiente');
commit;
