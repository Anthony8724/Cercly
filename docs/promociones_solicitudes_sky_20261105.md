# Promociones y solicitudes — revisión inicial del 5 de noviembre de 2026

**Documento histórico:** la corrección de negocio ahora utiliza propuestas
estructuradas y la migración versionada `20261106034310_aplicar_correcciones_estructuradas.sql`.
Consulte el informe de correcciones estructuradas para el estado actual.


Rama: `fix/promociones-solicitudes-sky`, creada desde `develop` en
`44f703b8c88bd3a1405f3d63cd875607d5e6360f`.
Sin commits, publicación, builds APK ni migraciones remotas en esta tarea.

## Diagnóstico comprobado

1. **Promociones:** el carrusel asignaba `onTap: null` cuando el negocio no
   estaba en la página de Explorar. Las promociones se consultan separadamente;
   esa ausencia no significa que el negocio no sea público. Ahora cada toque
   resuelve el ID con `EstablecimientoPublicoService.obtenerPorId`, que exige
   `estado=aprobado` y `publicable=true`, bajo RLS. Se reutiliza el callback
   existente que abre la ficha. Se revalida incluso una ficha ya cargada para
   evitar abrir datos retirados desde la carga anterior. Una apertura en curso
   bloquea los demás toques: no duplica consultas ni navegación. Se muestra
   progreso, indisponibilidad o error recuperable, sin usar datos viejos como
   alternativa ante un fallo.
2. **Selección:** la consulta anterior no tenía límite y construía un desplegable
   con todos los resultados. La selección inicial dependía de esa lista y la
   dirección usaba `firstWhere` sin alternativa si faltaba el ID. Ahora el ID
   inicial se consulta directamente y, si ya no es elegible, se informa sin
   sustituirlo por otro negocio. Un único negocio asociado se preselecciona
   cuando no hay un ID inicial. Con varios, el usuario elige.
3. **Correcciones:** la aplicación envía texto libre en
   `datos_propuestos.descripcion_solicitud`. El administrador llamaba a
   `responder_solicitud_establecimiento`; su rama `when 'correccion' then null`
   solo registraba estado, motivo y revisor. No aplicaba nombre, dirección,
   categoría, ubicación ni información básica. Tampoco guardaba antes/después.

El punto 3 se confirmó en el SQL versionado **y mediante SELECT de metadatos en
Production**, sin consultar filas de usuarios ni modificarlas. La definición
remota coincide con esa rama; `aplicar_correccion_establecimiento` no existe.
Los únicos triggers de solicitudes son actualización de fecha y validación;
ninguno aplica la propuesta al negocio. No se ejecutaron RPC de escritura en
Production ni en Staging.

## Selección y UX

- Hoja de búsqueda con nombre y dirección, adaptada a `SkyPalette`.
- Negocios asociados primero, reutilizando `listarEstablecimientosDelUsuario`.
  Esta prioridad se aplica a **correcciones**. Reclamar conserva su filtro de
  OSM sin propietario; acceso conserva el de negocios administrados. La
  asociación no convierte un negocio en reclamable ni concede permisos.
- Búsqueda con debounce de 300 ms, páginas de 20 y orden explícito por nombre
  e ID. Los resultados de una búsqueda antigua se descartan; la paginación
  evita repetir IDs. El botón «Cargar más» queda inactivo durante la consulta.
- Filtros de aprobado/publicable en todas las consultas del selector.
- Desde Mis negocios: acción visible «Solicitar corrección», con ID inicial y
  tipo bloqueado. Registro nuevo conserva su pantalla independiente.
- Los resultados vacíos permiten otra búsqueda. Los errores permiten reintentar.
- Consultar o seleccionar una opción no crea solicitudes, membresías ni roles.

La paginación usa rangos inclusivos de Supabase ([documentación Dart](https://supabase.com/docs/reference/dart/range)).
El volumen transferido está acotado; no se midió el coste del plan de consulta
remoto. Para catálogos mucho mayores quedan por evaluar `pg_trgm` para búsquedas
por fragmentos y paginación por cursor. No se crearon índices remotos. Cambios
concurrentes del catálogo pueden desplazar páginas OFFSET; se deduplican los
resultados mostrados y una nueva búsqueda reinicia la paginación.

## Solución de correcciones preparada, todavía NO desplegada

`supabase/migrations/20261106034310_aplicar_correcciones_estructuradas.sql` sustituye a la **propuesta
local revisable**, fuera de `supabase/migrations`; no se ejecuta por los flujos
normales de migración del repositorio.

El solicitante explica el cambio en lenguaje natural. El administrador revisa
la propuesta y los valores actuales; el diálogo permite concretar nombre,
dirección, categoría activa, descripción, teléfono público y coordenadas.
No se infieren datos de texto libre ni se aplica automáticamente lo que envía
un usuario.

La nueva RPC propuesta:

1. Comprueba identidad y rol administrativo en servidor.
2. Acepta solo los siete campos indicados; rechaza cambios de propietario,
   publicación, estado, roles o membresías.
3. Valida tipos, longitudes, categoría activa y límites de ambas coordenadas.
4. Bloquea solicitud y negocio, en ese orden, y exige solicitud de corrección
   pendiente y ficha pública aprobada.
5. Compara los datos actuales con los revisados para impedir sobrescrituras
   obsoletas. Rechaza una aprobación sin cambios.
6. Actualiza la ficha; PostgreSQL recalcula su columna geográfica generada.
7. Guarda antes/después, fecha, revisor y justificación en
   `correcciones_aplicadas`; RLS limita lectura al solicitante y administradores,
   sin escritura directa desde clientes.
8. Cierra la solicitud con la RPC existente dentro de la misma transacción.
   Un error revierte negocio, auditoría y estado.

Un trigger propuesto impide a clientes antiguos aprobar correcciones sin una
aplicación auditada. Los rechazos y los flujos de registro/reclamo permanecen
independientes. Las solicitudes ya aprobadas históricamente **no se reinterpretan
como cambios aplicados** ni se corrigen de manera retroactiva.

La interfaz nueva nunca vuelve a la RPC antigua si falta la nueva función.
Ante `PGRST202` informa que la aplicación de correcciones no está habilitada y
mantiene pendiente la solicitud. Por tanto, **esta parte requiere despliegue SQL
autorizado antes de poder usarse en Production**. El envío de solicitudes y su
rechazo no dependen del nuevo SQL.

### Pendientes antes de habilitarla

La [auditoría técnica y de seguridad](auditoria_sql_correcciones_20261105.md)
emite **NO-GO para desplegar la propuesta tal como está**.


- Revisar y autorizar la propuesta, generar la migración por el flujo del
  proyecto y validar el despliegue en un entorno autorizado.
- Verificar grants/RLS y caché de esquema PostgREST después del despliegue.
- Revisar retención y eliminación administrativa del nuevo historial: la FK
  conserva la solicitud y no permite eliminarla mientras tenga auditoría. No
  se ha alterado la política de eliminación de cuentas. La trazabilidad guarda
  datos comerciales y UUID del revisor; su retención debe quedar documentada.
- Realizar una prueba de interfaz con cuentas de propietario y administrador
  autorizadas. Aquí se probaron widgets, contratos HTTP simulados y PostgreSQL
  local; no se enviaron solicitudes reales ni se aprobaron cambios remotos.
- El historial antes/después queda disponible bajo RLS; no se añadió una nueva
  pantalla general de historial. Las pantallas existentes conservan estado,
  respuesta y fecha de la solicitud.

## Validación y evidencias

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: **284 aprobadas, 11 omitidas**.
- `git diff --check`: correcto.
- `python3 scripts/test_correcciones_local.py`: **66 comprobaciones SQL**:
  37 de correcciones, 12 de registro y 17 de reclamo.
- SQL ejecutado en PostgreSQL Supabase aislado en contenedor nuevo **sin red**,
  con imagen local ya instalada; todas las migraciones del repositorio y un
  bootstrap mínimo de Auth/Storage. El contenedor se detuvo al terminar. Esto
  no equivale a una prueba HTTP contra Production.
- Cobertura: promoción fuera de la página, deduplicación de apertura,
  ficha retirada/error, filtros públicos, selección por ID/asociación, ausencia
  de negocios, nombres repetidos, páginas y respuestas fuera de orden,
  navegación desde Mis negocios, valores revisados, rechazo, prohibición de
  autoaprobación, lectura restringida de auditoría y rollback completo.
- Pantallas renderizadas en los cuatro temas: amanecer, día, atardecer y noche.
  Pruebas a 412×915 y 320×800, texto ampliado 1.4 y teclado de 260 px. Capturas
  con fuente Roboto real en `artifacts/solicitudes-sky-20261105/`.
  Son renders de widgets con fixtures locales; **no capturas del Honor ni
  prueba física de esta versión**.

Comando reproducible de captura (usar la ruta local de Roboto del SDK):

```bash
CERCLY_UI_CAPTURES=artifacts/solicitudes-sky-20261105 \
CERCLY_UI_FONT=/ruta/al/SDK/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf \
flutter test --no-pub test/solicitudes_sky_visual_test.dart
```

## Archivos de implementación

- `lib/features/explorar/widgets/promociones_explorar.dart`
- `lib/features/establecimientos/screens/mis_negocios_screen.dart`
- `lib/features/solicitudes_establecimientos/screens/nueva_solicitud_screen.dart`
- `lib/features/solicitudes_establecimientos/screens/solicitudes_administrador_screen.dart`
- `lib/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart`
- `lib/features/solicitudes_establecimientos/widgets/selector_establecimiento.dart`
- `lib/features/solicitudes_establecimientos/widgets/revisar_correccion_dialog.dart`
- Propuesta SQL, pruebas y arnés local indicados arriba.

## Alcance preservado

Sin cambios en Android/Kotlin, geofencing, consentimiento, permisos, historial
de notificaciones/cooldown, recepción nativa, navegación desde notificaciones,
autenticación o configuración de backend. No se alteraron promociones reales.
No se generó, instaló ni publicó APK. Las candidatas anteriores se conservan.
