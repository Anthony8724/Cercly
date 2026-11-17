# Activación segura de FCM y geofencing

Estado: **no habilitar todavía**. El emisor FCM no está desplegado en Staging
y geofencing promocional solo está disponible en Staging. Las reservas FCM
del servidor y el ledger nativo son independientes: no existe deduplicación
entre canales ni garantía de retirada remota cuando el teléfono está offline.

## Requisitos de implementación

- Una única reserva en el servidor debe serializar por usuario y aplicar
  consentimiento específico, instalación autorizada, promoción vigente,
  frecuencia, descanso y períodos de enfriamiento a ambos canales. Debe
  comprobar la sesión autenticada y registrar el canal ganador sin devolver
  a la app identificadores FCM de otras instalaciones.
- El receptor nativo debe usar una sesión válida sin registrar tokens en logs,
  volver a comprobar la cuenta y el consentimiento antes de notificar y fallar
  cerrado si no puede confirmar la reserva. La API de geocercas no es un
  servicio GPS continuo y Android puede demorar o no entregar transiciones.
- El cierre de sesión debe desactivar la entrega local, intentar revocar la
  asociación y asegurar que otra cuenta no reutilice la instalación anterior.
  Un dispositivo sin red no puede confirmar revocación remota. El servidor
  debe limitar la validez de asociaciones y verificar sesión/consentimiento
  antes de enviar; incluso con TTL corto puede existir una ventana residual de
  mensajes ya aceptados por el proveedor.
- FCM debe permanecer desactivado por defecto hasta demostrar recepción,
  apertura y limpieza en un dispositivo real. No habilitar simultáneamente
  ambos canales mientras no usen la misma reserva.

## Preparar Staging sin compartir credenciales

1. En el proyecto Firebase correspondiente, confirmar las aplicaciones y que
   Cloud Messaging API esté habilitada. Usar una identidad de servidor dedicada
   al entorno de prueba. El permiso de envío es
   `cloudmessaging.messages.create`; preferir un rol personalizado limitado
   si la política de la organización lo permite. No usar roles de propietario.
   [Permisos FCM de Google Cloud](https://docs.cloud.google.com/iam/docs/roles-permissions/firebasecloudmessaging).
2. La Edge Function actual utiliza el secreto `FCM_SERVICE_ACCOUNT_JSON` en
   Supabase. Un administrador debe configurarlo directamente mediante el gestor
   de secretos de **Staging**, fuera del repositorio y del chat. No ponerlo en
   Flutter, `dart-define`, la APK, logs ni variables públicas.
3. Antes de desplegar, revisar la función, autenticar al usuario, probar las
   reglas SQL y la deduplicación, confirmar que las migraciones de Staging son
   compatibles y preparar retirada/recuperación. El emisor debe permanecer
   inactivo hasta completar esas comprobaciones.
4. Después, verificar consentimiento y entrega real con una cuenta y un
   teléfono autorizados. Medir app abierta, fondo, pantalla bloqueada, cambio
   de cuenta, revocación, mensajes pendientes y carreras entre canales. No
   registrar el FID, tokens, credenciales ni coordenadas precisas en evidencia.

La configuración y migraciones de Producción son una operación independiente
que exige autorización específica sobre el plan final. Esta guía no autoriza
un despliegue ni afirma que se haya realizado.
