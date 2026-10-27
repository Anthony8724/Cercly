# Bloque 6: registro de establecimientos

## Auditoría y decisión de reutilización

- `public.establecimientos` ya almacenaba categoría, datos comerciales,
  coordenadas, horarios y estados `pendiente/aprobado/rechazado`.
- Ya existían `RegistroEstablecimientoScreen`, el selector FlutterMap con OSM,
  `EstablecimientoService.crear` y el panel administrativo.
- La operación anterior insertaba una fila de establecimiento y asignaba el
  propietario antes de la aprobación. Se conservó el formulario y el mapa, pero
  el alta ahora utiliza `solicitudes_establecimientos`, la misma tabla que
  reclamos y correcciones. No se creó una tabla paralela.
- `buscar_establecimientos_cercanos` alimenta Explorar y filtra a aprobados y
  publicables; las solicitudes no participan en esa consulta.
- `es_administrador`, las políticas RLS y la RPC
  `responder_solicitud_establecimiento` ya eran las bases del flujo de revisión.
  Se ampliaron para crear una ficha al aprobar `tipo = registro`.
- Se revisó la cadena de migraciones local y se amplió el harness SQL para
  aplicar y probar los dos archivos nuevos. No se conectó ni modificó Supabase
  remoto.

## Flujo implementado

1. **Mi cuenta → Mis negocios** ofrece registro nuevo, reclamo existente,
   solicitudes y establecimientos asociados.
2. El formulario permite nombre, categoría, descripción, dirección de
   referencia, teléfono comercial opcional, horarios opcionales y coordenadas.
3. La ubicación se puede tocar o navegar en el mapa, ajustar arrastrando el pin
   y confirmar. El GPS es opcional y funciona como referencia; no se exige estar
   físicamente en el negocio. No se añadió geocodificación ni búsqueda externa.
4. Antes de enviar se buscan fichas aprobadas dentro de 500 metros y se comparan
   nombres normalizados. Se puede reclamar una coincidencia OSM disponible o
   continuar si es otro negocio.
5. El servidor valida nombre, categoría, dirección y coordenadas y conserva la
   propuesta como solicitud pendiente. La ficha y sus horarios se crean solo
   dentro de la aprobación administrativa.
6. La aprobación conserva `revisado_por` y `revisado_en`, vincula la ficha a la
   solicitud, asigna propietario y cambia el rol `usuario` a `propietario`.
   El rechazo requiere motivo. Las respuestas pasan solo por la RPC protegida.

## Seguridad y compatibilidad

- RLS mantiene las solicitudes visibles solo para solicitante y administrador.
- Se retiró la política de inserción directa de fichas por propietarios; un
  usuario autenticado debe enviar una solicitud. La política administrativa de
  alta directa permanece para operaciones administrativas existentes.
- La política directa de actualización de solicitudes por administrador se
  retiró; la RPC autorizada verifica el rol en base de datos y deja auditoría.
- La ficha aprobada se crea con estado `aprobado`, `publicable = true` y fuente
  `cercly`. La búsqueda pública de mapa continúa sin leer solicitudes.
- No se aceptan fotografías en esta versión: el flujo seguro actual requiere una
  ficha y autorización de propietario. Las solicitudes pendientes no tienen
  acceso a ese almacenamiento.
- La navegación y la sesión existentes, incluido Cercly Sky, permanecen
  intactas. Mi cuenta expone la opción a todo usuario autenticado.

## Migraciones

- `20261027001121_registrar_nuevo_establecimiento.sql` añade el valor `registro`
  al enum.
- `20261027001217_configurar_solicitud_registro_establecimiento.sql` amplía la
  solicitud y la revisión, valida propuestas y restringe la creación directa.
- Deben desplegarse en ese orden en un entorno local/staging de revisión. No se
  aplicaron en remoto ni en producción.

## Evidencia y verificación

- Capturas: `artifacts/bloque6/formulario-registro.png` y
  `artifacts/bloque6/selector-ubicacion.png`. La captura del mapa omite los tiles
  externos para que sea reproducible en pruebas; la pantalla de producción
  utiliza los tiles OSM y atribución ya existentes.
- Verificaciones solicitadas: Flutter analyze, Flutter tests, suite SQL local y
  `git diff --check`.
- Estado de despliegue: **NO-GO para producción** hasta revisar y desplegar las
  migraciones en el entorno correspondiente y probar el flujo allí.
