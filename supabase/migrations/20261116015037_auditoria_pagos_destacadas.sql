-- Cercly Sky - Auditoria de confirmacion manual de pagos de patrocinios.
-- PREPARACION PARA STAGING V2. Revisar y guardar en una migracion CLI ANTES de aplicar.
-- Las referencias de pago son identificadores administrativos, no comprobantes de cobro.
-- No implementa cobros ni comprueba transferencias automaticamente.
-- Compatible con la columna pago_confirmado_en ya existente.
-- La tabla de auditoria no se expone a anon y no se conceden escrituras al cliente.

begin;

create table public.auditoria_pagos_destacadas (
  id uuid primary key default gen_random_uuid(),
  campana_id uuid not null
    references public.promociones_destacadas(id) on delete restrict,
  administrador_id uuid not null,
  referencia_pago text not null,
  confirmado_en timestamptz not null default now(),
  constraint auditoria_pagos_destacadas_campana_unica unique (campana_id),
  constraint auditoria_pagos_destacadas_referencia_valida check (
    char_length(btrim(referencia_pago)) between 4 and 100
    and referencia_pago = btrim(referencia_pago)
    and referencia_pago !~ '[[:cntrl:]]'
  )
);

comment on table public.auditoria_pagos_destacadas is
  'Auditoria de comprobaciones manuales de pago, no conciliacion bancaria ni cobros.';
comment on column public.auditoria_pagos_destacadas.referencia_pago is
  'Referencia administrativa del comprobante; NO guardar tarjetas, claves, cuentas completas ni datos sensibles.';

create index auditoria_pagos_destacadas_administrador_fecha_idx
  on public.auditoria_pagos_destacadas(administrador_id, confirmado_en desc);

alter table public.auditoria_pagos_destacadas enable row level security;

-- Minimizar privilegios en el registro: solo lectura para clientes
-- administradores (por RLS) y para el rol de servicio. Las escrituras se
-- realizan exclusivamente desde la funcion con propietario privilegiado.
revoke all on table public.auditoria_pagos_destacadas
  from public, anon, authenticated, service_role;
grant select on table public.auditoria_pagos_destacadas to authenticated;
grant select on table public.auditoria_pagos_destacadas to service_role;

create policy auditoria_pagos_destacadas_admin_lectura
  on public.auditoria_pagos_destacadas
  for select to authenticated
  using ((select public.es_administrador()));

-- Bloquear escrituras del cliente al campo de pago. Los metodos Flutter
-- existentes siguen pudiendo insertar campanas pendientes y cambiar estado.
revoke insert, update on table public.promociones_destacadas from authenticated;
grant insert (promocion_id, fecha_inicio, fecha_fin, estado)
  on table public.promociones_destacadas to authenticated;
grant update (estado)
  on table public.promociones_destacadas to authenticated;

-- Unica via de confirmar un pago: autorizacion server-side, fecha del servidor,
-- bloqueo de la fila, insercion de auditoria y actualizacion atomicas.
-- SECURITY DEFINER es necesario para escribir en auditoria sin permisos
-- de INSERT para clientes. Su alcance esta restringido por auth.uid/admin.
create function public.confirmar_pago_destacada(
  p_campana_id uuid,
  p_referencia text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_referencia text;
  v_confirmado_en timestamptz;
begin
  v_actor := auth.uid();
  if v_actor is null or not public.es_administrador() then
    raise exception 'Solo administradores pueden confirmar pagos'
      using errcode = '42501';
  end if;

  v_referencia := btrim(p_referencia);
  if v_referencia is null
      or char_length(v_referencia) not between 4 and 100
      or v_referencia ~ '[[:cntrl:]]' then
    raise exception 'Referencia invalida (4 a 100 caracteres, sin saltos de linea)'
      using errcode = '22023';
  end if;

  update public.promociones_destacadas
  set pago_confirmado_en = now()
  where id = p_campana_id
    and estado in ('pendiente', 'aprobada')
    and pago_confirmado_en is null
    and fecha_fin > now()
  returning pago_confirmado_en into v_confirmado_en;

  if not found then
    raise exception 'La campana no permite confirmar el pago; actualiza el listado'
      using errcode = 'P0001';
  end if;

  insert into public.auditoria_pagos_destacadas
    (campana_id, administrador_id, referencia_pago, confirmado_en)
  values (p_campana_id, v_actor, v_referencia, v_confirmado_en);

  return v_confirmado_en;
end;
$function$;

revoke all on function public.confirmar_pago_destacada(uuid, text)
  from public, anon, authenticated;
grant execute on function public.confirmar_pago_destacada(uuid, text)
  to authenticated;

commit;
