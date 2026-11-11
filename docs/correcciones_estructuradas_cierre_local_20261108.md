# Correcciones estructuradas — cierre local del 8 de noviembre de 2026

Rama: `fix/promociones-solicitudes-sky`, retomada desde `28dac2b` sin descartar
archivos. Implementación reutilizada, sin migraciones remotas, nuevos APK,
push, merge ni cambios de la web.

## Comportamiento completado

1. Propietario o colaborador activo selecciona una ficha autorizada, elige
   campos y propone valores anteriores/nuevos. El motivo del solicitante es
   opcional; para los demás tipos de solicitud se conserva su validación.
2. La validación de presentación admite únicamente nombre, dirección,
   categoría, descripción, teléfono público, latitud y longitud. Rechaza
   estructura incorrecta, campos restringidos, valores iguales, coordenadas
   no finitas/fuera de rango y categoría con formato inválido. PostgreSQL
   vuelve a comprobar permisos, valores actuales, categoría activa y límites.
3. El administrador ve ficha, solicitante, fecha, motivo, estado, valor al
   solicitar, valor actual y propuesta. La revisión es de solo lectura: el
   único campo editable es la justificación del revisor. Una ficha obsoleta
   bloquea la confirmación en UI y en servidor.
4. Aprobar llama únicamente a
   `aplicar_correccion_establecimiento(p_solicitud_id,p_motivo)`. El cliente
   no envía campos ni nuevos valores durante la aprobación.
5. La transacción bloquea solicitud y establecimiento; comprueba que siga
   pendiente, pública/aprobada y que el solicitante conserve su condición de
   propietario o colaborador activo. La membresía se bloquea FOR SHARE para
   que una revocación concurrente no se intercale con la aplicación.
6. Se aplican los valores almacenados y se comprueba que el resultado real
   coincide. Si un trigger impide el cambio, una propuesta es obsoleta, se
   perdió autorización o falla el cierre, se revierte la transacción entera.
7. La auditoría conserva campos antes/después, solicitante, revisor, motivo
   y fechas. RLS permite leer al solicitante y al administrador; ningún cliente
   escribe directamente el historial. Una solicitud cerrada no puede reabrirse
   ni reescribirse mediante las rutas probadas.
8. La UI confirma la auditoría después de la RPC. Solo entonces muestra
   «Corrección aplicada». Si no puede confirmarla, informa incertidumbre y
   permite recargar; no inventa éxito ni reintenta una aprobación automáticamente.

## Compatibilidad con solicitudes antiguas

Las solicitudes de texto y las de la APK privada manual 0.1.7+10 conservan su
revisión manual. Nunca se extraen valores de una descripción libre. Aprobar
una revisión manual registra únicamente esa decisión; no actualiza la ficha
ni crea una aplicación auditada ficticia.

Los estados se presentan como pendiente, rechazada, revisada manualmente o
corrección aplicada. Una solicitud estructurada aprobada sin auditoría válida
se muestra como «Sin aplicación acreditada», con aviso visual de advertencia.
La tabla de auditoría es una dependencia de este cliente nuevo: este código
no debe distribuirse contra Production antes de desplegar y validar su SQL.

## Errores encontrados y corregidos al retomar

- Refresco duplicado del listado tras aplicar: se realiza una sola consulta
  de refresco, aparte de la consulta individual que confirma la auditoría.
- El render del diálogo usaba la fuente de prueba Ahem porque los estilos
  personalizados no heredaban una familia tipográfica explícita. El diálogo
  reutiliza ahora los estilos de texto de ThemeData/Sky, sin modificar
  `lib/sky` ni su lógica horaria.
- El test del aviso sin auditoría buscaba una solicitud cerrada en el filtro
  Pendientes. Ahora selecciona Aprobadas y verifica la etiqueta y el icono de
  advertencia. No se ha desactivado ninguna prueba.
- El manifiesto local de preflight conservaba el hash anterior de la migración
  pendiente. Se actualizó únicamente ese hash; las 24 entradas históricas y
  la segunda migración permanecen intactas.

## Validaciones

- Flutter analyze: sin incidencias.
- Suite Flutter completa: **300 aprobadas, 11 omitidas** por las condiciones
  existentes de integración/capturas. No se configuró Supabase remoto.
- Regresiones administrativas y de estado: **9 aprobadas**.
- Pruebas visuales de formulario/selector/revisión: **8 aprobadas**, en los
  cuatro ambientes, también a 320 px con texto ampliado y teclado.
- SQL focal: correcciones **67/67**, casos adicionales **22/22**, registro
  **12/12**, reclamo **17/17**.
- Concurrencia real en PostgreSQL local: doble aprobación de una solicitud y
  dos propuestas del mismo negocio; en cada escenario hubo **una aplicación,
  una auditoría y un rechazo**.
- Seguridad SQL: **447 aserciones en 19 suites**, todas aprobadas, con
  `--legacy-acl-drift --diagnose-auth`. Se verificaron privilegios heredados,
  RLS, autorización, inmutabilidad, rechazo, rollback y conservación de datos.
- Git diff --check y sintaxis de los scripts Python: correctos.

Las pruebas SQL utilizan contenedores nuevos `network=none`, imagen local
fijada y datos sintéticos. No se descifró el respaldo real ni se probó HTTP
contra Supabase. Las pruebas Flutter incluyen reloj local, retorno a primer
plano y cuatro paletas; los archivos de temas y geofencing no cambiaron.

Capturas reales de widgets, no del Honor:
`artifacts/correcciones-estructuradas-20261108/` (12 PNG). Se inspeccionaron
visualmente revisión día/noche y formulario amanecer. Fuente usada para el
render local: Noto Sans registrada como Roboto; no se añadió un asset/dependencia
a la aplicación. No se afirma validación física del nuevo flujo.

Logs de esta ejecución: `/tmp/cercly-resume-{analyze,flutter,correcciones,security,admin,visual}-20261108.log`
y `/tmp/cercly-resume-dialog-visual-20261108.log`.

## Archivos del cambio funcional

- Modelo nuevo: `models/propuesta_correccion.dart`.
- `services/solicitud_establecimiento_service.dart`.
- Pantallas: `nueva_solicitud_screen.dart`, `solicitudes_administrador_screen.dart`,
  `mis_solicitudes_screen.dart`.
- Widgets: `proponer_correccion.dart`, `revisar_correccion_dialog.dart`.
  Todos pertenecen a `lib/features/solicitudes_establecimientos/`.
- `scripts/test_correcciones_local.py`, `scripts/correcciones_concurrencia_local.py`.
- Primera migración pendiente y su hash en
  `docs/staging_migration_manifest_20261107.json`.
- `supabase/tests/correcciones_aplicadas_test.sql` y
  `supabase/tests/correcciones_casos_adicionales_test.sql`.
- Tests: `correcciones_estado_test.dart`, `correcciones_flujo_administrador_test.dart`,
  `correcciones_visuales_test.dart`, `revisar_correccion_dialog_test.dart`,
  `selector_establecimiento_test.dart`.

## SQL necesario y preparación de STAGING

Siguen siendo exactamente dos migraciones, en este orden:

1. `20261106034310_aplicar_correcciones_estructuradas.sql`.
2. `20261107121537_cerrar_actualizacion_administrativa_directa.sql`.

La segunda conserva el cierre del bypass de edición administrativa directa,
la moderación legítima de estado y sus privilegios limitados. No se añadió
una tercera migración ni se alteraron archivos históricos. La primera sigue
sin desplegar: por eso sus ajustes se revisan dentro del archivo pendiente.

Preparación local reproducible, sin enlaces ni operaciones remotas:

```sh
python3 scripts/preparar_preflight_staging.py --dest /tmp/cercly-staging-preflight-NUEVO
```

El destino debe ser nuevo. El script verifica hashes, 24 entradas históricas
reconciliadas y dos pendientes, y copia únicamente configuración local,
migraciones y manifiesto. La reconciliación remota corresponde a la auditoría
anterior; no se volvió a consultar STAGING. El checkout principal continúa
enlazado a Production y no debe utilizarse con operaciones --linked.

Después de resolver recuperación y obtener autorización remota: reconfirmar
STAGING `dlajxviqhkdcqnmczhvr`, historial/propietarios/permisos y respaldo;
revisar el plan de las dos migraciones; ejecutar solo el despliegue autorizado.
Probar con cuentas sintéticas de propietario, colaborador, administrador y
tercero: presentación, revocación, duplicados, revisión manual, aplicación
exacta, rechazo, concurrencia, RLS del historial y caché PostgREST. La relación
embebida de auditoría debe comprobarse también por HTTP en ese entorno.

## Recuperación, privacidad y veredicto

**GO para el cierre local del código. NO-GO para desplegar o ejecutar pruebas
de escritura en STAGING todavía. NO-GO para actualizar Production.**

El respaldo cifrado original permanece intacto. Ya se demostraron ACL y
membresías en un ensayo local, pero falta ensayar la recuperación real de los
siete propietarios y completar controles posteriores. También faltan evidencias
de propietario/ACL/configuración originales de base y propietarios de
extensiones; no se consideran equivalentes por inferencia.

La retención de 24 meses es provisional y no está aprobada legalmente. No hay
borrado automático. La FK del historial conserva solicitudes y puede bloquear
el borrado de cuenta/ficha: hace falta acordar minimización, anonimización y
tratamiento autorizado antes de activar la eliminación en esos casos.

Ante un incidente posterior al despliegue no borrar auditoría ni revertir datos
en bloque. Contener la RPC, conservar evidencia y usar una nueva corrección
compensatoria auditada. Un error antes del commit de la transacción revierte
negocio, auditoría y estado conjuntamente.

Próximo paso exacto: autorizar y completar el ensayo local de recuperación
pendiente con el respaldo existente. Solo después evaluar autorización de
validación controlada de STAGING. Tras validar y autorizar Production, preparar
una futura candidata con versionCode **11 o superior**; la APK 0.1.7+10 y la rama
`release/production-compatible-0.1.7` no se modifican en este trabajo.
