# Migración desde la APK pública firmada con Debug

La APK pública `Cercly-v0.1.0-universidad-final.apk` está firmada con el
certificado Android Debug (SHA-256 `684dbc25032a38eb64f479f23a35d6a5c2a8a18b3dbe05a326a597c80065119b`).
La candidata `Cercly-v0.1.1-production-release.apk` está firmada con el
certificado de distribución Cercly Upload (SHA-256
`f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5`).
Como los certificados no coinciden, Android no permite instalar la candidata
encima de la versión pública actual.

## Procedimiento cuando se autorice la distribución

1. No anunciar ni ofrecer la APK candidata hasta desplegar y verificar primero
   la migración de permisos de preferencias en Staging y Production.
2. Pedir a cada usuario que abra la versión actual con conexión, inicie sesión
   en su cuenta normal y espere a que termine la sincronización de preferencias.
   No continuar si hay cambios locales pendientes de sincronizar.
3. Explicar que las preferencias y demás registros sincronizados con la cuenta
   se recuperan al iniciar sesión después de la instalación, sujetos a que la
   sincronización haya finalizado. La sesión guardada en el dispositivo deberá
   iniciarse de nuevo.
4. Para instalar, el usuario debe desinstalar la versión anterior e instalar
   la APK Release nueva. La desinstalación borra los datos locales de esa
   instalación. No se puede conservar desde la aplicación el historial local
   de alertas/cooldown ni otros datos que no se hayan sincronizado.
5. Iniciar sesión con la misma cuenta, comprobar preferencias, volver a
   conceder permisos Android y activar de nuevo las alertas según el
   consentimiento del usuario.

Este proceso requiere instrucciones visibles antes de distribuir la APK; no es
una actualización silenciosa y el soporte debe ayudar a recuperar el acceso a
la cuenta si el usuario no recuerda sus credenciales.

## Estado de esta candidata

Esta guía no autoriza el despliegue remoto ni la publicación. La candidata
permanece sin distribuir mientras esté pendiente el despliegue y la verificación
de la migración SQL de preferencias, y las confirmaciones legales de privacidad.
