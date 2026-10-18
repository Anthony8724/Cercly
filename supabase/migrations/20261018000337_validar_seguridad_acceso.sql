-- Bloque 4. Complementa fortalecer_acceso_perfiles sin modificar datos ni roles.
-- Conservar SELECT sobre miembros: otras políticas lo consultan como subconsulta.
begin;
set local lock_timeout = '5s';

revoke truncate, references, trigger on table
  public.usuarios, public.establecimientos, public.solicitudes_establecimientos,
  public.miembros_establecimiento, public.promociones
from public, anon, authenticated;

-- Una política restrictiva se combina con AND con las permisivas existentes.
-- Evita que una futura política permisiva reabra esta vía de falsificación.
-- Los administradores conservan su flujo explícito de verificación.
drop policy if exists "alta sin verificacion autoconcedida"
  on public.establecimientos;
create policy "alta sin verificacion autoconcedida"
  on public.establecimientos as restrictive for insert to authenticated
  with check (
    public.es_administrador()
    or (verificado_en is null and verificado_por is null)
  );

-- Función de trigger, no RPC de cliente. El trigger sigue ejecutándose.
revoke execute on function public.sincronizar_categoria_principal()
  from public, anon, authenticated;
commit;
