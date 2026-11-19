-- Cercly: cuota de solicitudes de rutas compartida entre instancias.
-- Datos mínimos: UUID y contador, nunca coordenadas ni credenciales.
-- La API pública sólo ve una función que afecta a auth.uid().

create schema if not exists cercly_rutas_privado;
revoke all on schema cercly_rutas_privado from public, anon, authenticated;

create table cercly_rutas_privado.rutas_limites_usuarios (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  ventana_inicio timestamptz not null,
  solicitudes integer not null check (solicitudes between 1 and 10)
);

alter table cercly_rutas_privado.rutas_limites_usuarios enable row level security;
revoke all on table cercly_rutas_privado.rutas_limites_usuarios from public, anon, authenticated;

-- Ventana fija de 60 segundos por usuario, máximo 10 solicitudes.
-- El INSERT ... ON CONFLICT asegura exclusión mutua por fila incluso con
-- solicitudes concurrentes desde múltiples instancias Edge Function.
create function public.consumir_cuota_rutas()
returns boolean
language plpgsql
security definer
set search_path = ''
as $func$
declare
  v_usuario uuid := auth.uid();
  v_ahora timestamptz := pg_catalog.clock_timestamp();
  v_permitido boolean := false;
begin
  if v_usuario is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  insert into cercly_rutas_privado.rutas_limites_usuarios as cuota
    (usuario_id, ventana_inicio, solicitudes)
  values (v_usuario, v_ahora, 1)
  on conflict (usuario_id) do update
    set ventana_inicio = case
          when excluded.ventana_inicio - cuota.ventana_inicio >= interval '60 seconds'
            then excluded.ventana_inicio
          else cuota.ventana_inicio
        end,
        solicitudes = case
          when excluded.ventana_inicio - cuota.ventana_inicio >= interval '60 seconds'
            then 1
          else cuota.solicitudes + 1
        end
    where excluded.ventana_inicio - cuota.ventana_inicio >= interval '60 seconds'
       or cuota.solicitudes < 10
  returning true into v_permitido;

  return coalesce(v_permitido, false);
end;
$func$;

-- Revocar el EXECUTE implícito de Postgres a PUBLIC es obligatorio.
-- Solo un JWT de usuario autenticado podrá consumir su PROPIA cuota.
revoke all on function public.consumir_cuota_rutas() from public, anon, authenticated;
grant execute on function public.consumir_cuota_rutas() to authenticated;
