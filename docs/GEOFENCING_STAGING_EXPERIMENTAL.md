> Actualización 2026-11-03: este documento conserva resultados históricos. El estado vigente y el GO técnico en Honor están en [el informe final](GEOFENCING_GO_HONOR_2026-11-03.md); para la entrega usar [la guía del 4 de noviembre](DEMO_ACADEMICA_2026-11-04.md). Las menciones a Honor pendiente y APK code6 más abajo corresponden al ensayo anterior.

# Experimento de geofencing Android en Staging

Estado: prototipo interno Staging v0.1.5+6. La prueba nativa programada está implementada, pero no se validó en runtime porque no hay Honor conectado y el único AVD disponible falla al arrancar. No es candidato de distribución pública.

## Alcance y protección de Production

- El experimento solo se habilita con `CERCLY_STAGING=true`, URL exacta de Supabase Staging y clave `sb_publishable_`.
- Usa exclusivamente la promoción ficticia existente `f14a1f14-14b0-4b14-8a14-140000000002` y el establecimiento `f14a1f14-14b0-4b14-8a14-140000000001`.
- No agrega ni modifica registros en Supabase. Se consultó la promoción por ID y se verifican sus fechas, `activa`, el estado aprobado/publicable del negocio y ambos IDs durante cada evento.
- Solo el manifiesto de Staging declara `ACCESS_BACKGROUND_LOCATION`, recepción de reinicio y los receivers experimentales, incluido el receiver QA de alarma, todos `exported=false`. El manifiesto Release de Production no contiene esos componentes ni ese permiso.
- El segundo plano requiere consentimiento específico, alertas cercanas activadas, ubicación precisa, permiso Android de ubicación todo el tiempo, notificaciones y Google Play Services. Está apagado por defecto. El botón de retirada elimina la zona.
- Se registra una zona a la vez. Su radio efectivo es el menor entre el radio de la promoción y la preferencia del usuario; el vencimiento no supera siete días ni la fecha final de la promoción. No se activa GPS continuo ni se guarda ubicación del dispositivo o historial de recorridos.

## Diseño implementado

`GeofencingClient` envía transiciones de entrada y salida a un `BroadcastReceiver` explícito con `PendingIntent` mutable donde Android lo exige. Solo la entrada puede generar notificación. El receiver comprueba consentimiento y permisos, consulta el endpoint público de Staging con timeout de 2.5 segundos y descarta el evento ante desconexión, respuesta no válida, promoción vencida o negocio no publicado. La notificación usa el canal existente `promociones_cercanas`, el icono Cercly y un `PendingIntent` que entrega el ID al `MainActivity`; Flutter vuelve a cargar la ficha pública antes de abrirla.

La opción «Programar prueba con pantalla bloqueada» consulta el permiso y estado del canal reales y crea una alarma `AlarmManager.setAndAllowWhileIdle` a aproximadamente 30 segundos con un `PendingIntent` explícito e inmutable a un receiver Staging privado. No usa Timer Dart ni solicita permiso de alarmas exactas. Android puede retrasarla por ahorro de energía/Doze; no se garantiza el instante, la entrega tras force-stop ni supervivencia a un reinicio. La programación impide duplicados y tiene cancelación explícita. Su notificación se marca `[PRUEBA PANTALLA BLOQUEADA]`, lleva el ID del establecimiento fijo de QA y usa una identidad de notificación y PendingIntent independientes del aviso comercial. Sus fechas y resultado técnico están en claves locales separadas, sin coordenadas.

El consentimiento y datos mínimos para reconstruir la zona (coordenadas públicas del establecimiento, radio y expiración) viven en preferencias privadas del experimento. El limitador nativo comparte su reserva entre eventos nativos y alertas foreground mientras el usuario optó por el experimento: 2 h por promoción, 15 min globales y hasta 3 notificaciones en 24 h. Flutter mantiene sus controles/historial foreground ya existentes. No se guardan coordenadas del usuario.

El receiver de reinicio y el de actualización de paquete intentan restaurar el único geofence si aún hay consentimiento, permisos y vigencia. La expiración la aplica además Play Services. La actualización de promociones en este prototipo es manual desde Configuración; no hay sondeo continuo ni WorkManager. Errores de GMS, permisos revocados o validación de red omiten la alerta. La detención forzada del usuario impide garantizar la entrega o la restauración hasta que vuelva a abrir Cercly.

## Comprobaciones ejecutadas

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Correcto: sin issues. |
| `flutter test` | 257 aprobadas; 9 omitidas por no configurar Supabase en las pruebas de integración. Suite focal con `CERCLY_STAGING=true`: 15 aprobadas, incluyendo programación/cancelación, rechazo de permisos, duplicados, exclusión de Production y panel QA. |
| `git diff --check` | Correcto. |
| Compilación APK Release Staging | Correcta. Paquete `com.cercly.cercly.staging`, versionName `0.1.5`, versionCode `6`. |
| Manifiesto APK Staging | Incluye `ACCESS_BACKGROUND_LOCATION`, `RECEIVE_BOOT_COMPLETED`, geofence, boot, receiver QA y `ScreenLockQaReceiver` no exportados. |
| Firma APK nueva/anterior | Ambas verificadas por `apksigner` con el certificado Cercly Upload y el mismo SHA-256 de certificado `f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5`. |
| URL configurada en APK | Build Staging validado por Gradle contra el host exacto `dlajxviqhkdcqnmczhvr.supabase.co`; solo clave publicable. No se ejecutaron cambios remotos. |
| Manifiesto Production | No se generó APK ni se tocó el artefacto Production. El manifiesto fuente Production no incluye receivers QA ni `ACCESS_BACKGROUND_LOCATION`. |
| Pixel 7 AVD | No arrancó. Con `-gpu off` y con `-gpu swiftshader_indirect -feature -Vulkan`, el proceso terminó con código 139. ADB no llegó a detectar un dispositivo. El inventario local solo mostró ese AVD y la imagen ya instalada Android 37.2; no se descargaron componentes. |
| Alarma inexacta programada/cancelada y bloqueo de permiso | Cubierto por pruebas automatizadas del wrapper/casos nativos reportados; no ejecutado en dispositivo. |
| Entrega real de alarma con pantalla bloqueada y toque/navegación | Pendiente: no hay dispositivo/AVD disponible para ejecución. |
| Evento geofence real, entrada/salida y notificación | Pendiente: no hay emulador conectado, por lo que no hay evidencia de ejecución. |
| Minimizada, pantalla bloqueada, proceso terminado por Android, reinicio, revocación | Pendientes por la misma limitación. No se probó ni se promete funcionamiento tras force-stop. |
| Honor/MagicOS | Pendiente; `adb devices -l` no mostró dispositivo conectado/autorizado. |
| Batería | No medida. Por diseño se registra una región en Play Services y no hay polling GPS; esto no sustituye medición en dispositivo. |

La app no estaba instalada en el AVD durante estas pruebas. En consecuencia, la compilación del APK no acredita el registro de zona, una transición real, entrega de notificación ni navegación.

## APK interna

APK vigente de este experimento: `artifacts/Cercly-v0.1.5-staging-geofencing-experimental.apk`, Release firmada, paquete `com.cercly.cercly.staging`, versionCode 6, tamaño 62,522,606 bytes. SHA-256: `e55c049b5c342f59e9c16b2c40174143b695e3d289a5054a00df79a48f5d2d6b`. `aapt` confirmó el package ID Staging y `apksigner verify` validó el mismo certificado Cercly Upload que la APK Staging anterior. Es artefacto interno no publicado; no se generó una APK Production. La APK Release no está validada en dispositivo y no debe distribuirse públicamente.

## Herramientas QA de proximidad

El panel Staging permite consultar permisos, consentimiento, última confirmación local de registro GMS, cooldown individual/global, contador 24 h y resultados. La API pública `GeofencingClient` permite agregar/quitar zonas pero no consultar un inventario actual de zonas; por ello el panel dice que el registro fue confirmado por el callback exitoso de Play Services y no promete que siga activo tras revocaciones, reinicios o detenciones. Los permisos actuales se vuelven a consultar al mostrar el panel.

«Simular entrada en zona» consulta el repositorio público configurado en Staging desde el punto ficticio UPEC y vuelve a validar IDs, publicación, vigencia, radio, consentimiento, permiso foreground de ubicación, permiso de notificaciones, cooldown y límite diario usando el mismo `ControlNotificacionesPromocion`. No lee la posición del teléfono, no pide permisos, no requiere permiso background porque ejecuta la simulación visible, y genera un aviso con marca `[PRUEBA SIMULADA]`. El payload sigue apuntando al ID público para probar navegación.

«Probar receiver QA interno» envía un intent explícito a `GeofenceQaReceiver`, declarado solo en el manifiesto Staging con `exported=false`. Ese receiver solo registra el instante de esa señal. No llama al receiver real ni produce un evento de Play Services. El panel separa señal interna QA, simulación, alarma programada y transición Android real; también presenta los últimos eventos enter/exit, error nativo y resultado de notificación tras entrada real.

«Programar prueba con pantalla bloqueada» genera una sola alarma QA, independiente del cooldown comercial; «Cancelar prueba programada» la retira sin alterar cooldown, historial comercial, permisos ni Supabase. El permiso de notificaciones debe estar concedido y el canal activo. Al tocarla, `MainActivity` recibe el ID fijo UPEC en el mismo extra que las notificaciones comerciales y Flutter resuelve la ficha pública. El envío del payload está cubierto por la ruta de navegación existente; el toque real de esta notificación queda pendiente de dispositivo.

«Reiniciar cooldown de pruebas» requiere confirmación, borra el historial local Staging de alertas y únicamente las claves `cooldown_*` de preferencias privadas nativas. No toca el consentimiento, permisos, registro, promociones ni Supabase. Para repetir una simulación exitosa debe usarse primero este botón porque el motor conserva sus límites reales.

Las pruebas automatizadas actuales cubren ejecución simulada con `CERCLY_STAGING=true`, caducidad, permisos/consentimiento, cooldown y reinicio local, marcador QA, programación/cancelación, duplicados, estado del permiso, exclusión del canal en Production y el ID de establecimiento de navegación. El AVD Pixel 7 continúa sin arrancar (código 139); no se descargaron imágenes ni componentes adicionales. No se instalaron componentes grandes. Para una futura prueba en emulador compatible, registrar UPEC con consentimiento en la app, bloquear pantalla y llevar ubicación del emulador primero a un punto fuera del radio y luego al centro mediante controles Location del emulador; esperar varios minutos, confirmar `lastAndroidEnterAt`, y repetir centro→fuera para `lastAndroidExitAt`. Las herramientas de ubicación del emulador no equivalen a una entrada física ni están disponibles universalmente en Honor. En el Honor se requiere desplazamiento físico atravesando el límite de la zona; después revisar esos dos campos en el panel, sin forzar ubicaciones por ADB.

Para probar el aviso programado en Honor: instala el APK Staging, concede notificaciones en Android, abre el panel, pulsa «Programar prueba con pantalla bloqueada», bloquea la pantalla y espera al menos un minuto. La alarma apunta a ~30 s, pero Doze/MagicOS pueden demorarse más. Desbloquea y toca la alerta para verificar la ficha UPEC. Si se fuerza la detención de Cercly, no se garantiza la alarma. El resultado «delivered_to_notification_manager» significa que la app la publicó en el gestor Android; la visibilidad/sonido siguen sujetos al canal, pantalla de bloqueo y fabricante.

## Políticas y decisión de publicación

La política vigente de Google Play exige que ubicación de segundo plano sea necesaria para la funcionalidad principal, aporte beneficio significativo, tenga divulgación visible, consentimiento y declaración/revisión en Play Console. La documentación de Play clasifica ofertas/anuncios, conveniencia y personalización como beneficios mínimos y advierte que funciones que pueden operar con ubicación foreground tienen mayor riesgo de no ser aprobadas. Por eso este prototipo de promociones no debe habilitar el permiso en Production ni presentarse como conforme/aprobado sin decisión de Play Console y revisión de privacidad: [política de ubicación en segundo plano](https://support.google.com/googleplay/android-developer/answer/9799150).

Android documenta un máximo de 100 geofences por aplicación/usuario, expiración nativa y eventos de background que pueden retrasarse varios minutos; Android 11+ lleva al usuario a Ajustes para “Permitir todo el tiempo” después de pedir ubicación foreground por separado: [Geofencing](https://developer.android.com/develop/sensors-and-location/location/geofencing), [permiso de segundo plano](https://developer.android.com/develop/sensors-and-location/location/permissions/background). `setAndAllowWhileIdle()` es inexacta y se recomienda para operaciones que deben ejecutarse durante Doze; las alarmas exactas se reservan a funciones que requieren hora precisa y tienen permisos especiales: [Alarmas Android](https://developer.android.com/develop/background-work/services/alarms).

**GO** para distribuir internamente esta APK de Staging y realizar pruebas manuales. **NO-GO** para habilitar ubicación background en Production, Play Store o afirmar fiabilidad hasta probar en Honor y AVD funcional los escenarios pendientes, medir batería/red, terminar revisión de privacidad/divulgaciones y obtener evaluación de elegibilidad de Google Play. Una notificación programada QA no valida el geofencing. La alternativa publicable más segura sigue siendo evaluar alertas mientras Cercly está visible, sin declarar `ACCESS_BACKGROUND_LOCATION`.
