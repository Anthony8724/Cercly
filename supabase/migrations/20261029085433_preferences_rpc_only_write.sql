begin;

-- Keep direct reads protected by RLS, but force all client writes through the
-- validated RPC so revision and active-category checks cannot be bypassed.
revoke insert, update, delete
  on table public.preferencias_usuario,
           public.preferencias_usuario_categorias
  from public, anon, authenticated;
grant select
  on table public.preferencias_usuario,
           public.preferencias_usuario_categorias
  to authenticated;

create or replace function public.guardar_preferencias_usuario(
  p_categorias_ids pg_catalog.uuid[],
  p_radio_metros pg_catalog.int4,
  p_priorizar_promociones pg_catalog.bool,
  p_revision_esperada pg_catalog.int8
) returns pg_catalog.int8
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario pg_catalog.uuid := auth.uid();
  v_revision pg_catalog.int8;
  v_insertadas pg_catalog.int4;
  v_cantidad pg_catalog.int4;
begin
  if v_usuario is null then
    raise exception 'Autenticación requerida' using errcode = '28000';
  end if;
  if p_radio_metros is not null
     and p_radio_metros not in (1000, 3000, 5000, 10000) then
    raise exception 'Radio no permitido' using errcode = '22023';
  end if;
  if p_priorizar_promociones is null
     or p_revision_esperada is null
     or p_revision_esperada < 0 then
    raise exception 'Preferencias inválidas' using errcode = '22023';
  end if;

  select pg_catalog.count(*) into v_cantidad
  from (
    select distinct pg_catalog.unnest(
      coalesce(p_categorias_ids, array[]::pg_catalog.uuid[])
    ) as id
  ) as ids;

  if exists (
    select 1
    from pg_catalog.unnest(
      coalesce(p_categorias_ids, array[]::pg_catalog.uuid[])
    ) as seleccion(id)
    left join public.categorias as c
      on c.id = seleccion.id and c.activa
    where c.id is null
  ) then
    raise exception 'Una o más categorías no están disponibles'
      using errcode = '22023';
  end if;

  if pg_catalog.cardinality(
       coalesce(p_categorias_ids, array[]::pg_catalog.uuid[])
     ) <> v_cantidad then
    raise exception 'Categorías duplicadas' using errcode = '22023';
  end if;

  insert into public.preferencias_usuario(
    usuario_id, radio_metros, priorizar_promociones
  )
  values (v_usuario, p_radio_metros, p_priorizar_promociones)
  on conflict (usuario_id) do nothing;
  get diagnostics v_insertadas = row_count;

  if v_insertadas = 1 then
    if p_revision_esperada <> 0 then
      raise exception 'Las preferencias cambiaron en otro dispositivo'
        using errcode = '40001';
    end if;
    v_revision := 1;
  else
    select p.revision into v_revision
    from public.preferencias_usuario as p
    where p.usuario_id = v_usuario
    for update;
    if v_revision is distinct from p_revision_esperada then
      raise exception 'Las preferencias cambiaron en otro dispositivo'
        using errcode = '40001';
    end if;
    v_revision := v_revision + 1;
    update public.preferencias_usuario as p
    set radio_metros = p_radio_metros,
        priorizar_promociones = p_priorizar_promociones,
        revision = v_revision,
        actualizado_en = pg_catalog.now()
    where p.usuario_id = v_usuario;
  end if;

  delete from public.preferencias_usuario_categorias as pc
  where pc.usuario_id = v_usuario;
  insert into public.preferencias_usuario_categorias(usuario_id, categoria_id)
  select v_usuario, seleccion.id
  from pg_catalog.unnest(
    coalesce(p_categorias_ids, array[]::pg_catalog.uuid[])
  ) as seleccion(id);

  return v_revision;
end;
$$;

-- Pin the definer to the trusted database owner. This migration must be run
-- by the owner or a superuser, as in the existing Supabase migration flow.
alter function public.guardar_preferencias_usuario(
  pg_catalog.uuid[], pg_catalog.int4, pg_catalog.bool, pg_catalog.int8
) owner to postgres;

revoke all on function public.guardar_preferencias_usuario(
  pg_catalog.uuid[], pg_catalog.int4, pg_catalog.bool, pg_catalog.int8
) from public, anon, authenticated;
grant execute on function public.guardar_preferencias_usuario(
  pg_catalog.uuid[], pg_catalog.int4, pg_catalog.bool, pg_catalog.int8
) to authenticated;

commit;
