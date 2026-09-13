create or replace function public.reemplazar_horarios_establecimiento(
  p_establecimiento_id uuid,
  p_horarios jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if jsonb_typeof(p_horarios) <> 'array' then
    raise exception 'Los horarios deben enviarse como una lista';
  end if;

  delete from public.horarios_establecimiento
  where establecimiento_id = p_establecimiento_id;

  insert into public.horarios_establecimiento (
    establecimiento_id,
    dia_semana,
    apertura_minutos,
    cierre_minutos,
    cierra_al_dia_siguiente
  )
  select
    p_establecimiento_id,
    (horario->>'dia_semana')::smallint,
    (horario->>'apertura_minutos')::smallint,
    (horario->>'cierre_minutos')::smallint,
    coalesce(
      (horario->>'cierra_al_dia_siguiente')::boolean,
      false
    )
  from jsonb_array_elements(p_horarios) as horario;
end;
$$;

revoke all
on function public.reemplazar_horarios_establecimiento(uuid, jsonb)
from public;

grant execute
on function public.reemplazar_horarios_establecimiento(uuid, jsonb)
to authenticated;