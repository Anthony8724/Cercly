-- Cercly Sky - Fase 3A: campañas destacadas (solo preparación).
-- Aplicar primero únicamente en Supabase STAGING tras revisión.
-- Esta migración NO crea cobros ni permite autopatrocinio.

begin;

create table public.promociones_destacadas (
  id uuid primary key default gen_random_uuid(),
  promocion_id uuid not null
    references public.promociones(id) on delete cascade,
  fecha_inicio timestamptz not null,
  fecha_fin timestamptz not null,
  estado varchar(16) not null default 'pendiente',
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint promociones_destacadas_fecha_valida_check
    check (fecha_fin > fecha_inicio),
  constraint promociones_destacadas_estado_check
    check (estado in ('pendiente', 'aprobada', 'rechazada', 'cancelada')),
  constraint promociones_destacadas_periodo_unico
    unique (promocion_id, fecha_inicio, fecha_fin)
);

comment on table public.promociones_destacadas is
  'Campañas para mostrar promociones patrocinadas en Explorar; la aprobación está reservada a administradores.';

create index promociones_destacadas_publicas_idx
  on public.promociones_destacadas (fecha_inicio, fecha_fin)
  where estado = 'aprobada';

create index promociones_destacadas_promocion_idx
  on public.promociones_destacadas (promocion_id);

create trigger promociones_destacadas_actualizar_fecha
  before update on public.promociones_destacadas
  for each row
  execute function public.actualizar_fecha_modificacion();

-- Dos capas: permisos SQL (GRANT) y políticas por fila (RLS).
alter table public.promociones_destacadas enable row level security;

revoke all on table public.promociones_destacadas
  from public, anon, authenticated;

grant select on table public.promociones_destacadas
  to anon, authenticated;

grant insert, update, delete on table public.promociones_destacadas
  to authenticated;

grant all on table public.promociones_destacadas
  to service_role;

-- El público solo puede consultar campañas aprobadas y temporalmente
-- vigentes, cuyo negocio y promoción también son públicos y vigentes.
create policy "destacadas_publico_lectura"
  on public.promociones_destacadas
  for select to anon, authenticated
  using (
    estado = 'aprobada'
    and fecha_inicio <= now()
    and fecha_fin >= now()
    and exists (
      select 1
      from public.promociones as p
      join public.establecimientos as e
        on e.id = p.establecimiento_id
      where p.id = promociones_destacadas.promocion_id
        and p.activa = true
        and p.fecha_inicio <= now()
        and p.fecha_fin >= now()
        and e.estado = 'aprobado'
        and e.publicable = true
    )
  );

-- Las campañas pendientes/rechazadas no son visibles públicamente.
-- Solo los administradores pueden ver todas las campañas.
create policy "destacadas_admin_lectura"
  on public.promociones_destacadas
  for select to authenticated
  using ((select public.es_administrador()));

-- Únicamente administradores pueden crear, aprobar, cancelar o eliminar.
-- Los comerciantes NO pueden marcar sus promociones como patrocinadas.
create policy "destacadas_admin_insertar"
  on public.promociones_destacadas
  for insert to authenticated
  with check ((select public.es_administrador()));

create policy "destacadas_admin_actualizar"
  on public.promociones_destacadas
  for update to authenticated
  using ((select public.es_administrador()))
  with check ((select public.es_administrador()));

create policy "destacadas_admin_eliminar"
  on public.promociones_destacadas
  for delete to authenticated
  using ((select public.es_administrador()));

commit;
