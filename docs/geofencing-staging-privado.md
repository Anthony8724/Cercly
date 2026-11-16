# Geofencing promocional privado de Staging

Esta implementación solo se habilita en builds `CERCLY_STAGING=true` y consulta el proyecto `dlajxviqhkdcqnmczhvr`. No habilita geofencing promocional en Production ni cambia el manifiesto de Production.

La pantalla de diagnóstico y los receptores QA de coordenadas fijas ya no se exponen en el flujo Staging de la demo. Al iniciar, la app solicita a Google Play Services retirar una eventual geocerca fija de builds QA anteriores; el código de simulación permanece fuera del flujo de demostración real.

## Activación

1. Iniciar sesión en la cuenta de prueba de Staging y activar las alertas promocionales normales.
2. En Configuración, leer y aceptar la divulgación específica de esta prueba.
3. Conceder ubicación precisa y notificaciones. En Android 11 o posterior, abrir los ajustes de permisos de Cercly, elegir **Ubicación → Permitir todo el tiempo** y volver a la app.
4. Pulsar **Actualizar zonas cercanas** con Internet y Servicios de Google Play activos. Se obtiene una posición visible y se registran hasta 20 promociones públicas elegibles, como máximo a 5 km; el radio de cada zona queda limitado por la promoción y la preferencia del usuario (1.500 m predeterminado).
5. Confirmar que el estado de registro muestre `accepted_by_gms`. Esto confirma aceptación de la API, no una futura entrega.

La app no mantiene un servicio GPS continuo. En cada transición, el receptor nativo captura por separado la hora de entrega al receptor y la hora/edad del punto que Google Play Services adjuntó al evento. La API no expone una hora exacta de detección. Como Android puede retrasar una transición varios minutos, ese punto solo se admite como evidencia hasta 10 minutos, con precisión y distancia conservadoras; no autoriza por sí mismo una alerta. Tras consultar Staging, el receptor solicita una ubicación puntual actual y exige que tenga como máximo 120 segundos de antigüedad, precisión suficiente y que siga dentro del radio efectivo. Si no obtiene esa confirmación, la cuenta cambió, no hay red o la promoción/datos ya no son elegibles, falla cerrado y no notifica. La navegación vuelve a consultar la promoción y solo abre el establecimiento si sigue vigente y activa.

El receptor usa `goAsync()` en un executor y mantiene las operaciones acotadas: consulta HTTP con límites de conexión/lectura y tope de 3 s, y una solicitud puntual de ubicación con espera máxima de 2,5 s. Esto deja margen frente al límite general de aproximadamente 10 s de `BroadcastReceiver`; no se usa el receptor para trabajo prolongado ni para ubicación periódica. La plataforma puede retrasar o no entregar eventos por ahorro de batería, ubicación de red/Wi‑Fi, falta de conectividad, permisos revocados o detención forzada. La ubicación actual se consulta una vez por transición; no es un servicio persistente.

## Retirada y cuentas

Desactivar las alertas o el consentimiento solicita la retirada de todas las geocercas. Al cerrar sesión o cambiar de usuario, se retiran zonas y se elimina el ledger local anterior; la nueva cuenta debe dar consentimiento nuevamente. Si Android revoca un permiso, los eventos se rechazan y la reconciliación al volver a abrir Cercly retira las zonas. El receptor de reinicio vuelve a registrar zonas aún vigentes solo si los permisos y el consentimiento persistidos siguen habilitados.

## Frecuencia y deduplicación

El ledger nativo de este dispositivo aplica una notificación por promoción/usuario, cuatro horas por establecimiento, quince minutos globales, 3/6/10 por ventana móvil de 24 horas y horario de descanso local. Las notificaciones locales foreground usan la misma reserva nativa en esta variante Staging. La reserva de FCM en Supabase es transaccional, pero el envío de FCM y una notificación local no son una transacción distribuida. La Edge Function de envío aún no está desplegada y el receptor nativo no llama un RPC privilegiado; por eso la deduplicación entre dispositivos/canales no queda garantizada por este build. No habilitar envío FCM real simultáneo hasta coordinar una reserva server-side única.

## Construcción

Usar únicamente URL de Staging y una clave `sb_publishable_...` de Staging por `--dart-define`; no usar service-role, claves secretas ni credenciales privadas. El Gradle valida el project URL y la variante `com.cercly.cercly.staging`. El APK de esta prueba es privado y no debe publicarse.

## Datos para una demostración física

El conjunto actual de Staging no contiene ahora una promoción elegible. No reutilizar ni editar registros de prueba vencidos. Crear datos nuevos desde las pantallas autorizadas de la app:

1. Una cuenta propietaria autorizada registra el establecimiento real en **Registrar establecimiento**: nombre comercial verdadero, categoría, dirección verificable, descripción y punto GPS del acceso/local (latitud y longitud tomadas del mapa o del sitio, no estimadas). No registrar un negocio ajeno sin autorización.
2. Una cuenta administradora abre el **Panel administrativo**, revisa la solicitud, la aprueba y marca **Publicar**. La fila debe quedar `estado=aprobado` y `publicable=true`.
3. La cuenta propietaria/miembro con permiso abre **Panel del establecimiento → Mis negocios → Promociones → Nueva promoción**. Crea un título y texto de prueba autorizado, `activa=true`, inicio igual o anterior a la prueba, fin posterior a la prueba, y radio de 1.500 m. No usar vigencias pasadas.
4. Verificar desde Cercly STAGING con una cuenta normal que el detalle/listado público presenta el establecimiento y la promoción; luego actualizar las zonas desde la ubicación física. Confirmar que aparece el estado `accepted_by_gms` y una zona no vencida.

La política de Staging no permite modificar estas filas con SQL administrativo para preparar la demo. Después de la creación mediante UI, se debe volver a comprobar en modo lectura: vigencia, estado/publicación, geometría, radio y visibilidad RLS antes de empezar la prueba de pantalla bloqueada.

## Límites Android y Play

Geofencing usa ubicación en segundo plano y depende de Google Play Services, proveedor de ubicación, Wi-Fi y optimización de batería. Android no garantiza una hora exacta: la alerta puede demorarse varios minutos. En un teléfono real, enviar Cercly al fondo y bloquear la pantalla no equivale a **Forzar detención** desde Ajustes; una app forzada puede dejar de recibir eventos hasta abrirla de nuevo. Tras reiniciar se intenta registrar de nuevo; si los permisos o servicios no están disponibles, la recuperación falla cerrada.

Esta prueba es privada de Staging, no una declaración de elegibilidad para Google Play. Google Play exige que ubicación en segundo plano sea parte central y beneficiosa de la app y prohíbe solicitarla exclusivamente para publicidad. El caso de alertas promocionales requiere revisión de política antes de cualquier release.

Referencias oficiales: [Android: geofencing, latencia y restauración](https://developer.android.com/develop/sensors-and-location/location/geofencing), [GeofencingEvent: ubicación que provocó la transición](https://developers.google.com/android/reference/com/google/android/gms/location/GeofencingEvent), [BroadcastReceiver: límite y `goAsync`](https://developer.android.com/reference/android/content/BroadcastReceiver), [Google Play: política de ubicación en segundo plano](https://support.google.com/googleplay/android-developer/answer/9799150) y [permisos y APIs de ubicación](https://support.google.com/googleplay/android-developer/answer/16558241).

## Prueba física requerida

Con una promoción vigente de prueba en Staging y un establecimiento real/coordinado: activar la función, registrar zonas, verificar estado, dejar el teléfono con Cercly en segundo plano y bloquearlo, entrar físicamente al radio permitido, esperar la ventana de entrega Android y registrar hora/ubicación/resultado. Confirmar notificación, sonido/vibración según ajustes del canal, abrir el destino, repetición/deduplicación, revocación y comportamiento offline. No usar coordenadas QA ni forzar entrada desde ADB como evidencia de detección física.
