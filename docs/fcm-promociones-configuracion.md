# Configuración Android de FCM para promociones

El cliente solo habilita push cuando coinciden `CERCLY_STAGING=true`,
`CERCLY_FCM_STAGING_ENABLED=true` y la URL exacta del proyecto Staging.
La compilación pública queda desactivada aunque conserve una preferencia
anterior. Al iniciar sesión se intenta apagar la preferencia y retirar una
instalación previa; si falla la retirada se conserva un marcador de reintento.
Las alertas locales y el radar conservan su propia configuración.

El proyecto `cercly-sky` ya tiene registradas las apps Android de Producción y
Staging. La configuración cliente se encuentra en
`android/app/google-services.json`; el plugin Google Services selecciona dentro
del archivo el cliente que coincide con el `applicationId` efectivo de cada
compilación.

El JSON descargado se inspeccionó antes de copiarlo: contiene las apps
`com.cercly.cercly` y `com.cercly.cercly.staging`, y no contiene claves privadas
ni campos de cuenta de servicio. Firebase documenta este archivo como
configuración cliente con identificadores no secretos. No incluye credenciales
de envío.

## Variantes Android

- Producción y `productionCandidate` usan `com.cercly.cercly`.
- Staging aplica el sufijo `.staging` y usa `com.cercly.cercly.staging`.
- Evaluación y Demo no están registradas en Firebase. Gradle deja el plugin
  Google Services desactivado para esos builds, por lo que siguen sin depender
de configuración Firebase.
- El archivo contiene ambos clientes registrados. El plugin selecciona el
  bloque por el `applicationId`; así Staging no recibe el App ID de Producción.

Se usa configuración Android nativa por variante. No se generó un
`firebase_options.dart` único porque fijaría un solo App ID Android, mientras
que los builds actuales comparten el mismo módulo y cambian el `applicationId`
mediante `dart-define`. El `Firebase.initializeApp()` existente usa los recursos
Android generados por Google Services para el paquete de cada build. La
inicialización FlutterFire sigue siendo la capa de SDK; la selección del App ID
la resuelve Gradle con el JSON.

El JSON cliente es parte de la configuración Android del proyecto. Antes de
publicar, confirmar que las restricciones de API key en Google Cloud sean
compatibles con FCM y con ambos paquetes. No subir JSON de cuenta de servicio,
claves privadas ni secretos de Supabase.

## Firebase Console y servidor

1. El proyecto configurado es `cercly-sky`; FCM debe estar habilitado. No se
   utilizan Firebase Authentication, Firestore ni Analytics.
2. Las apps de Producción (`com.cercly.cercly`) y Staging
   (`com.cercly.cercly.staging`) están registradas. Evaluación y Demo quedan
   fuera de Firebase hasta que se decida registrarlas.
3. Para envío HTTP v1, crear una identidad de servidor con permisos mínimos y
   guardar su JSON únicamente como secreto `FCM_SERVICE_ACCOUNT_JSON` en un
   entorno Supabase no productivo. No guardarlo en `.env` del repositorio,
   Flutter, `dart-define`, Gradle, logs ni commits.
4. La migración y Edge Function de este PR aún no se despliegan. La prueba de
   envío real requiere desplegarlas en staging y configurar allí el secreto;
   no se debe usar Supabase Producción para esta validación.

## Política implementada

- El consentimiento push incluye el uso de ubicación reciente para proximidad
  y es independiente del interruptor de notificaciones locales.
- Android desactiva el auto-registro FCM en el manifiesto. Tras aceptar, la app
  habilita el registro y guarda el Firebase Installation ID (FID) recomendado
  por Firebase; al desactivar o cerrar sesión, lo desregistra y retira su
  asociación de Supabase. Los callbacks de FID se escuchan con `onRegistered`
  antes de llamar `register()`; el emisor HTTP v1 usa `message.fid`, no el
  campo heredado `message.token`.
- Una ubicación se evalúa solo ante una posición nueva con Radar activo y Mapa
  visible: máximo 120 segundos de antigüedad, precisión máxima de 100 m y sin
  permiso de ubicación en segundo plano.
- PostGIS exige `distancia + precisión <= min(1.500 m, radio de usuario, radio
  de campaña)`. Se prioriza el negocio más cercano.
- El mensaje FCM expira en dos minutos; al abrirlo, la aplicación consulta de
  nuevo la promoción y no navega si ya no está vigente/publicable.
- Preferencias servidor: 3/6/10 alertas en ventana móvil de 24 h (6 por
  defecto), 4 h por negocio, 15 min entre alertas y horario de descanso según
  el offset local enviado en cada evaluación.
- La reserva SQL bloquea por usuario y registra promoción/evento antes de
  llamar a FCM. También deduplica entre instalaciones. Una reserva fallida
  conserva el cupo y la deduplicación para evitar duplicados ambiguos si FCM
  aceptó el mensaje pero se perdió la respuesta. Esto puede reducir entregas
  ante fallos transitorios y debe observarse antes de producción.
- Las notificaciones locales se omiten en una evaluación cuando push está
  activado, evitando que ambos canales publiquen el mismo ciclo. El historial
  local previo no se importa al servidor; por tanto el límite compartido entre
  dispositivos cubre reservas push y no reconstruye alertas locales anteriores.

## Alcance aún no habilitado

La migración y Edge Function son locales. No se aplicaron a Supabase. No se ha
probado entrega FCM real, modo bloqueado ni comportamiento en un dispositivo.
La compilación tampoco tiene configuración Firebase real: falta registrar las
apps en Console y completar la selección de opciones por variante antes de
probar FCM en Android.
La geocerca nativa privada conserva sus límites previos y debe alinearse con
esta política antes de considerar cualquier habilitación pública.

## Documentación oficial consultada

- [Configuración Firebase para Flutter](https://firebase.google.com/docs/flutter/setup)
- [FCM para Flutter, FID y registro manual](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Formato HTTP v1 y destino `message.fid`](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
- [Caducidad máxima de mensajes](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan)
- [Recepción, segundo plano y apertura desde una notificación](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
