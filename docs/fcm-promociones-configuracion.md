# Configuración pendiente de FCM para promociones

Este cambio añade el cliente y el flujo de servidor, pero no contiene una
configuración Firebase de Cercly. La activación del usuario permanece
deshabilitada hasta completar estos pasos en los proyectos correctos.

## Firebase Console

1. Crear o seleccionar el proyecto Firebase oficial de Cercly y habilitar
   Firebase Cloud Messaging. No usar Firebase Authentication, Firestore ni
   Analytics.
2. Registrar una aplicación Android por cada `applicationId` que se vaya a
   probar o distribuir. Los identificadores salen de
   `android/app/build.gradle.kts`:
   - Producción: `com.cercly.cercly`.
   - Staging: `com.cercly.cercly.staging`.
   - Evaluación: `com.cercly.cercly.evaluation`.
   - Demo: `com.cercly.cercly.demo`.
   La build privada `productionCandidate` reutiliza el identificador de
   producción `com.cercly.cercly`; no requiere otra app Firebase.
3. Para cada app Android, descargar su `google-services.json` desde Firebase
   Console. Los cuatro identificadores son aplicaciones Android distintas,
   aunque se alojen en un mismo proyecto Firebase. No poner un archivo de una
   variante en otra.
4. Ejecutar FlutterFire CLI autenticado con la cuenta propietaria del proyecto
   y configurar Android para obtener las opciones públicas de cliente. La CLI
   genera `firebase_options.dart`; Firebase Console entrega el
   `google-services.json`. No son archivos intercambiables.
5. El repositorio aún no tiene selección de Firebase por variante, las opciones
   generadas ni el plugin de Google Services en Gradle. Por eso esta rama no
   puede inicializar una app Firebase real todavía. Después de registrar las
   apps, hay que preparar un cambio de configuración que seleccione el
   `FirebaseOptions`/archivo Android correcto según cada build y use las
   opciones en `Firebase.initializeApp`. No copiar un JSON de producción a
   Staging/Evaluación ni construir hasta validar esa correspondencia.
6. Confirmar que Firebase Cloud Messaging esté habilitado para el proyecto.
   Crear una identidad de servidor con el permiso mínimo necesario para enviar
   mensajes FCM HTTP v1.
7. Guardar el JSON privado de la cuenta de servicio como secreto de Supabase
   `FCM_SERVICE_ACCOUNT_JSON` en el entorno de pruebas elegido. No incluirlo en
   `.env`, archivos Flutter, `dart-define`, Gradle, logs o commits. La función
   usa además los secretos de plataforma de Supabase y requiere autenticación
   JWT de usuario.

No registrar todavía credenciales ni desplegar la función desde este PR. Los
identificadores Firebase y archivos generados se añaden solo después de que el
propietario configure y confirme el proyecto correcto.

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
