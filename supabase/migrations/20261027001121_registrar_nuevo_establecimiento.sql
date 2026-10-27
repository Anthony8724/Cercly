-- Nuevo registro: reutiliza solicitudes_establecimientos y almacena el borrador
-- privado en datos_propuestos. La ficha pública solo se crea al aprobar.
alter type public.tipo_solicitud_establecimiento add value if not exists 'registro';
