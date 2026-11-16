-- Cercly Sky: habilitar verificacion MANUAL de pago de campañas destacadas.
-- Fase: STAGING. No ejecuta cobros ni procesa información bancaria.
-- ADVERTENCIA: una campaña 'aprobada' anterior que no tenga pago confirmado
-- dejara de ser visible publicamente tras aplicar esta migracion.
-- No elimina ni modifica datos de campañas existentes.

begin;

alter table public.promociones_destacadas
  add column pago_confirmado_en timestamptz;

comment on column public.promociones_destacadas.pago_confirmado_en is
  'Fecha de verificación manual de pago por un administrador. NULL = pago no verificado; no registra ni procesa transferencias.';

-- Se aplica a futuras inserciones y actualizaciones sin invalidar las
-- campañas antiguas aprobadas. Las antiguas sin pago quedan ocultas por RLS.
alter table public.promociones_destacadas
  add constraint promociones_destacadas_aprobacion_requiere_pago_check
  check (estado <> 'aprobada' or pago_confirmado_en is not null) not valid;

-- RLS protege la consulta publica incluso si el cliente omite filtros.
drop policy if exists "destacadas_publico_lectura"
  on public.promociones_destacadas;

create policy "destacadas_publico_lectura"
  on public.promociones_destacadas
  for select to anon, authenticated
  using (
    estado = 'aprobada'
    and pago_confirmado_en is not null
    and fecha_inicio <= now()
    and fecha_fin >= now()
    and exists (
      select 1
      from public.promociones p
      join public.establecimientos e on e.id = p.establecimiento_id
      where p.id = promociones_destacadas.promocion_id
        and p.activa = true
        and p.fecha_inicio <= now()
        and p.fecha_fin >= now()
        and e.estado = 'aprobado'
        and e.publicable = true
    )
  );

commit;
