-- Una corrección aprobada aplica exactamente los campos solicitados.
-- Conservación interna provisional: 24 meses desde el cierre; sin borrado automático.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create table public.correcciones_aplicadas (
  solicitud_id uuid primary key references public.solicitudes_establecimientos(id) on delete restrict,
  establecimiento_id uuid not null,
  solicitante_id uuid not null,
  revisado_por uuid not null,
  solicitado_en timestamptz not null,
  cerrado_en timestamptz not null default now(),
  conservar_hasta timestamptz not null default (now() + interval '24 months'),
  motivo text not null,
  antes jsonb not null,
  despues jsonb not null
);
alter table public.correcciones_aplicadas enable row level security;
revoke all on public.correcciones_aplicadas from public, anon, authenticated;
grant select on public.correcciones_aplicadas to authenticated;
create policy "revisor y solicitante leen correccion aplicada"
  on public.correcciones_aplicadas for select to authenticated
  using ((select public.es_administrador()) or solicitante_id = (select auth.uid()));

-- Se ejecuta antes del validador existente. No revalida solicitudes antiguas
-- al cambiar solo estado/motivo. Las estructuradas exigen aplicación auditada;
-- las de texto conservan una revisión manual que no modifica la ficha.
create function public.validar_correccion_estructurada()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  e public.establecimientos%rowtype;
  cambios jsonb;
  campo text;
  item jsonb;
  nuevo text;
  categoria uuid;
  permitidos text[] := array['nombre','direccion','categoria_id','descripcion','telefono_publico','latitud','longitud'];
begin
  if tg_op='UPDATE' and old.tipo='correccion' and old.estado <> 'pendiente'
     and (to_jsonb(new)-'actualizado_en') is distinct from (to_jsonb(old)-'actualizado_en') then
    raise exception using errcode='42501', message='Una corrección cerrada no puede modificarse.';
  end if;
  if new.tipo <> 'correccion' then return new; end if;
  if tg_op = 'UPDATE' and
     (new.establecimiento_id,new.tipo,new.datos_propuestos) is not distinct from
     (old.establecimiento_id,old.tipo,old.datos_propuestos) then return new; end if;
  -- Compatibilidad con solicitudes de texto y clientes manuales existentes.
  -- Nunca interpretar texto libre ni tratarlo como una propuesta aplicable.
  if not (coalesce(new.datos_propuestos,'{}'::jsonb) ? 'cambios') then return new; end if;
  if auth.uid() is null or not public.puede_gestionar_como_propietario(new.establecimiento_id) then
    raise exception 'Solo el propietario o un colaborador activo puede solicitar una corrección.';
  end if;
  select * into e from public.establecimientos where id = new.establecimiento_id;
  if not found or e.estado is distinct from 'aprobado' or e.publicable is not true then
    raise exception 'El establecimiento no está disponible.';
  end if;
  if jsonb_typeof(new.datos_propuestos) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(new.datos_propuestos)) <> 1
     or not (new.datos_propuestos ? 'cambios') then
    raise exception 'La propuesta debe contener únicamente cambios estructurados.';
  end if;
  cambios := new.datos_propuestos->'cambios';
  if jsonb_typeof(cambios) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(cambios)) not between 1 and 7 then
    raise exception 'Propón al menos un campo válido.';
  end if;
  for campo in select jsonb_object_keys(cambios) loop
    if not (campo = any(permitidos)) then raise exception 'Campo no permitido: %', campo; end if;
    item := cambios->campo;
    if jsonb_typeof(item) is distinct from 'object'
       or (select count(*) from jsonb_object_keys(item)) <> 2
       or not (item ?& array['anterior','nuevo']) then
      raise exception 'Cada cambio requiere valor anterior y nuevo.';
    end if;
    if item->'anterior' is distinct from to_jsonb(e)->campo then
      raise exception 'La ficha cambió. Actualiza la propuesta antes de enviarla.';
    end if;
    if item->'nuevo' = item->'anterior' then raise exception 'No hay cambio en %.', campo; end if;
    if campo in ('latitud','longitud') then
      if jsonb_typeof(item->'nuevo') is distinct from 'number'
         or (campo='latitud' and (item->>'nuevo')::double precision not between -90 and 90)
         or (campo='longitud' and (item->>'nuevo')::double precision not between -180 and 180) then
        raise exception 'Coordenada inválida.';
      end if;
    else
      if jsonb_typeof(item->'nuevo') is distinct from 'string' then
        raise exception 'Valor de texto inválido.';
      end if;
      nuevo := item->>'nuevo';
      if nuevo is distinct from trim(nuevo) then raise exception 'Elimina espacios sobrantes.'; end if;
      if (campo='nombre' and char_length(nuevo) not between 2 and 120)
         or (campo='direccion' and char_length(nuevo) not between 1 and 250)
         or (campo='descripcion' and char_length(nuevo)>1000)
         or (campo='telefono_publico' and char_length(nuevo)>20) then
        raise exception 'Longitud de texto inválida.';
      end if;
      if campo='categoria_id' then
        categoria := nuevo::uuid;
        if not exists(select 1 from public.categorias c where c.id=categoria and c.activa) then
          raise exception 'Categoría no disponible.';
        end if;
      end if;
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.validar_correccion_estructurada() from public,anon,authenticated;
create trigger validar_correccion_estructurada before insert or update on public.solicitudes_establecimientos
  for each row execute function public.validar_correccion_estructurada();

create function public.validar_aprobacion_correccion()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.tipo='correccion' and new.datos_propuestos ? 'cambios' and new.estado='aprobada'
     and old.estado is distinct from new.estado
     and not exists(select 1 from public.correcciones_aplicadas a where a.solicitud_id=new.id) then
    raise exception 'La corrección debe aplicarse y auditarse antes de aprobar.';
  end if;
  return new;
end;
$$;
revoke all on function public.validar_aprobacion_correccion() from public,anon,authenticated;
create trigger validar_aprobacion_correccion before update on public.solicitudes_establecimientos
  for each row execute function public.validar_aprobacion_correccion();

create function public.aplicar_correccion_establecimiento(p_solicitud_id uuid,p_motivo text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  s public.solicitudes_establecimientos%rowtype;
  e public.establecimientos%rowtype;
  cambios jsonb;
  campo text;
  item jsonb;
  nuevo text;
  categoria uuid;
  antes jsonb := '{}'::jsonb;
  despues jsonb := '{}'::jsonb;
  motivo text := trim(coalesce(p_motivo,''));
begin
  if auth.uid() is null or not public.es_administrador() then
    raise exception 'Solo un administrador autenticado puede aprobar correcciones.';
  end if;
  if char_length(motivo) not between 1 and 1000 then
    raise exception 'La justificación es obligatoria y admite hasta 1000 caracteres.';
  end if;
  select * into s from public.solicitudes_establecimientos where id=p_solicitud_id for update;
  if not found or s.tipo <> 'correccion' or s.estado <> 'pendiente' then
    raise exception 'Se requiere una corrección pendiente.';
  end if;
  select * into e from public.establecimientos where id=s.establecimiento_id for update;
  if not found or e.estado is distinct from 'aprobado' or e.publicable is not true then
    raise exception 'El establecimiento no está disponible.';
  end if;
  if e.propietario_id is distinct from s.solicitante_id then
    perform 1 from public.miembros_establecimiento m where m.establecimiento_id=e.id
      and m.usuario_id=s.solicitante_id and m.activo for share;
    if not found then
      raise exception 'El solicitante ya no tiene permisos sobre el establecimiento.';
    end if;
  end if;
  cambios := s.datos_propuestos->'cambios';
  if jsonb_typeof(cambios) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(cambios)) not between 1 and 7 then
    raise exception 'La solicitud antigua no contiene cambios estructurados.';
  end if;
  for campo in select jsonb_object_keys(cambios) loop
    if not (campo=any(array['nombre','direccion','categoria_id','descripcion','telefono_publico','latitud','longitud'])) then
      raise exception 'La propuesta contiene un campo no permitido.';
    end if;
    item := cambios->campo;
    if jsonb_typeof(item) is distinct from 'object'
       or (select count(*) from jsonb_object_keys(item)) <> 2
       or not (item ?& array['anterior','nuevo']) then
      raise exception 'La propuesta antigua no contiene un cambio estructurado válido.';
    end if;
    if item->'anterior' is distinct from to_jsonb(e)->campo then
      raise exception 'La ficha cambió o la propuesta no es válida. Solicita una revisión nueva.';
    end if;
    if item->'nuevo' is not distinct from item->'anterior' then
      raise exception 'La propuesta no cambia el valor de %.', campo;
    end if;
    if campo in ('latitud','longitud') then
      if jsonb_typeof(item->'nuevo') is distinct from 'number'
         or (campo='latitud' and (item->>'nuevo')::double precision not between -90 and 90)
         or (campo='longitud' and (item->>'nuevo')::double precision not between -180 and 180) then
        raise exception 'Coordenada inválida.';
      end if;
    else
      if jsonb_typeof(item->'nuevo') is distinct from 'string' then
        raise exception 'Valor de texto inválido.';
      end if;
      nuevo := item->>'nuevo';
      if nuevo is distinct from trim(nuevo) then raise exception 'Elimina espacios sobrantes.'; end if;
      if (campo='nombre' and char_length(nuevo) not between 2 and 120)
         or (campo='direccion' and char_length(nuevo) not between 1 and 250)
         or (campo='descripcion' and char_length(nuevo)>1000)
         or (campo='telefono_publico' and char_length(nuevo)>20) then
        raise exception 'Longitud de texto inválida.';
      end if;
      if campo='categoria_id' then
        categoria := nuevo::uuid;
        if not exists(select 1 from public.categorias c where c.id=categoria and c.activa) then
          raise exception 'La categoría propuesta ya no está disponible.';
        end if;
      end if;
    end if;
    antes := antes || jsonb_build_object(campo,to_jsonb(e)->campo);
  end loop;
  update public.establecimientos set
    nombre=coalesce(cambios->'nombre'->>'nuevo',e.nombre),
    direccion=coalesce(cambios->'direccion'->>'nuevo',e.direccion),
    categoria_id=coalesce((cambios->'categoria_id'->>'nuevo')::uuid,e.categoria_id),
    descripcion=coalesce(cambios->'descripcion'->>'nuevo',e.descripcion),
    telefono_publico=coalesce(cambios->'telefono_publico'->>'nuevo',e.telefono_publico),
    latitud=coalesce((cambios->'latitud'->>'nuevo')::double precision,e.latitud),
    longitud=coalesce((cambios->'longitud'->>'nuevo')::double precision,e.longitud)
  where id=e.id returning * into e;
  for campo in select jsonb_object_keys(cambios) loop
    if to_jsonb(e)->campo is distinct from cambios->campo->'nuevo' then
      raise exception 'El valor aplicado no coincide con la propuesta; operación revertida.';
    end if;
    despues := despues || jsonb_build_object(campo,to_jsonb(e)->campo);
  end loop;
  insert into public.correcciones_aplicadas
    (solicitud_id,establecimiento_id,solicitante_id,revisado_por,solicitado_en,motivo,antes,despues)
  values (s.id,s.establecimiento_id,s.solicitante_id,auth.uid(),s.creado_en,motivo,antes,despues);
  perform public.responder_solicitud_establecimiento(s.id,'aprobada',motivo);
end;
$$;
revoke all on function public.aplicar_correccion_establecimiento(uuid,text) from public,anon;
grant execute on function public.aplicar_correccion_establecimiento(uuid,text) to authenticated;
commit;
