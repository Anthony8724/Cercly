begin;

create table if not exists public.preferencias_usuario (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  radio_metros integer null check (radio_metros is null or radio_metros in (1000, 3000, 5000, 10000)),
  priorizar_promociones boolean not null default false,
  revision bigint not null default 1 check (revision > 0),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.preferencias_usuario_categorias (
  usuario_id uuid not null references public.preferencias_usuario(usuario_id) on delete cascade,
  categoria_id uuid not null references public.categorias(id) on delete cascade,
  primary key (usuario_id, categoria_id)
);

alter table public.preferencias_usuario enable row level security;
alter table public.preferencias_usuario_categorias enable row level security;

drop policy if exists "usuario gestiona sus preferencias" on public.preferencias_usuario;
create policy "usuario gestiona sus preferencias"
  on public.preferencias_usuario for all to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

drop policy if exists "usuario gestiona sus categorias preferidas" on public.preferencias_usuario_categorias;
create policy "usuario gestiona sus categorias preferidas"
  on public.preferencias_usuario_categorias for all to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

revoke all on public.preferencias_usuario from public, anon;
revoke all on public.preferencias_usuario_categorias from public, anon;
grant select, insert, update, delete on public.preferencias_usuario to authenticated;
grant select, insert, delete on public.preferencias_usuario_categorias to authenticated;

-- La FK en cascada de preferencias no debe dejar bloqueada una eliminación
-- de cuenta; las dependencias de negocio siguen requiriendo revisión.
create or replace function cercly_account_private.tiene_dependencias(p_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.establecimientos where propietario_id = p_id)
    or exists(select 1 from public.solicitudes_establecimientos where solicitante_id = p_id)
    or exists(select 1 from pg_catalog.pg_constraint c
      join pg_catalog.pg_class t on t.oid = c.conrelid
      join pg_catalog.pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public' and c.contype = 'f' and c.confrelid in
        ('public.usuarios'::regclass, 'auth.users'::regclass)
        and c.conname not in ('usuarios_id_fkey',
          'miembros_establecimiento_usuario_id_fkey',
          'establecimientos_propietario_id_fkey',
          'solicitudes_establecimientos_solicitante_id_fkey',
          'establecimientos_verificado_por_fkey',
          'solicitudes_establecimientos_revisado_por_fkey',
          'preferencias_usuario_usuario_id_fkey'))
    or exists(select 1 from storage.objects where owner_id = p_id::text
      or (bucket_id in ('establecimientos-imagenes', 'promociones-imagenes')
        and name like p_id::text || '/%'));
$$;
revoke all on function cercly_account_private.tiene_dependencias(uuid)
  from public, anon, authenticated;

create or replace function public.guardar_preferencias_usuario(
  p_categorias_ids uuid[],
  p_radio_metros integer,
  p_priorizar_promociones boolean,
  p_revision_esperada bigint
) returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_revision bigint;
  v_insertadas integer;
  v_cantidad integer;
begin
  if v_usuario is null then
    raise exception 'Autenticación requerida' using errcode = '28000';
  end if;
  if p_radio_metros is not null and p_radio_metros not in (1000, 3000, 5000, 10000) then
    raise exception 'Radio no permitido' using errcode = '22023';
  end if;
  if p_priorizar_promociones is null or p_revision_esperada is null or p_revision_esperada < 0 then
    raise exception 'Preferencias inválidas' using errcode = '22023';
  end if;

  select count(*) into v_cantidad
  from (
    select distinct unnest(coalesce(p_categorias_ids, array[]::uuid[])) as id
  ) ids;
  if exists (
    select 1
    from unnest(coalesce(p_categorias_ids, array[]::uuid[])) as seleccion(id)
    left join public.categorias c on c.id = seleccion.id and c.activa
    where c.id is null
  ) then
    raise exception 'Una o más categorías no están disponibles' using errcode = '22023';
  end if;
  if cardinality(coalesce(p_categorias_ids, array[]::uuid[])) <> v_cantidad then
    raise exception 'Categorías duplicadas' using errcode = '22023';
  end if;

  insert into public.preferencias_usuario(usuario_id, radio_metros, priorizar_promociones)
  values (v_usuario, p_radio_metros, p_priorizar_promociones)
  on conflict (usuario_id) do nothing;
  get diagnostics v_insertadas = row_count;

  if v_insertadas = 1 then
    if p_revision_esperada <> 0 then
      raise exception 'Las preferencias cambiaron en otro dispositivo' using errcode = '40001';
    end if;
    v_revision := 1;
  else
    select revision into v_revision
    from public.preferencias_usuario
    where usuario_id = v_usuario
    for update;
    if v_revision is distinct from p_revision_esperada then
      raise exception 'Las preferencias cambiaron en otro dispositivo' using errcode = '40001';
    end if;
    v_revision := v_revision + 1;
    update public.preferencias_usuario
    set radio_metros = p_radio_metros,
        priorizar_promociones = p_priorizar_promociones,
        revision = v_revision,
        actualizado_en = now()
    where usuario_id = v_usuario;
  end if;

  delete from public.preferencias_usuario_categorias where usuario_id = v_usuario;
  insert into public.preferencias_usuario_categorias(usuario_id, categoria_id)
  select v_usuario, seleccion.id
  from unnest(coalesce(p_categorias_ids, array[]::uuid[])) as seleccion(id);
  return v_revision;
end;
$$;

revoke all on function public.guardar_preferencias_usuario(uuid[], integer, boolean, bigint) from public, anon;
grant execute on function public.guardar_preferencias_usuario(uuid[], integer, boolean, bigint) to authenticated;

commit;
