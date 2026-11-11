# Camino compatible para actualizar Cercly Production — 7 de noviembre de 2026

## Estado comprobado

- Rama actual: `fix/promociones-solicitudes-sky`, HEAD `28dac2b`.
- Develop local y remoto: `44f703b8c88bd3a1405f3d63cd875607d5e6360f`.
  Se consultó el ref remoto mediante git ls-remote, sin fetch, merge ni push.
- Tres commits locales sobre develop: `0dce3df`, `b10a889`, `28dac2b`.
  El diff comprende 31 archivos: interfaz/servicio de solicitudes,
  promociones, pruebas, dos migraciones pendientes y documentación.
- Antes de este informe había 18 archivos locales sin seguimiento, todos del
  diagnóstico/recuperación. Se conservaron. No había cambios de archivos
  ya versionados. No se hizo commit.
- No hay diferencias contra develop en Android, lib/sky, autenticación,
  notificaciones/geofencing, configuración Supabase, pubspec o lockfile.

## Versiones y firma

La web real `https://cercly-web.vercel.app` devolvió HTTP 200 y sigue enlazando
`/descargas/Cercly-v0.1.1-production-release.apk`. Ese enlace también devolvió
200 en HEAD, con 62.128.530 bytes. GitHub no lista releases para el repositorio
móvil; esta identificación de publicación corresponde a la web institucional.

| Artefacto local | Versión | Bytes |
| --- | --- | --- |
| APK pública conservada | 0.1.1+2 | 62.128.530 |
| Candidata privada anterior | 0.1.6+8 | 62.407.846 |
| Última candidata privada | 0.1.6+9 | 62.407.798 |

Última APK:
`artifacts/Cercly-v0.1.6-code9-production-private-sky-geofencing.apk`.
SHA-256: `c807909896763de17f570c40b11b36c9c7dc228e838983b86e885b8fd8b82993`.

Las tres APK verifican firma válida y paquete `com.cercly.cercly`. Comparten
certificado SHA-256
`f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5`.
El certificado exportado en memoria del keystore local coincide con ellas;
no se imprimieron contraseñas, alias ni material de clave privada.

En los AOT/Dex examinados solo aparece el host Supabase Production
`aimubazregckmjchnszf.supabase.co`. La configuración local usa ese host y una
clave publicable, sin campos de secretos de servidor; configuración y
propiedades de firma están ignoradas por Git. La code9 declara los receivers
Production, ubicación background y ningún receiver QA comprobado ni paquete
STAGING. La comprobación completa previa de referencias QA permanece en
`artifacts/production-private-code9-verification.json`.

Se inspeccionaron las 14 APK Production existentes en artifacts y releases:
el versionCode máximo encontrado es 9. Se propone **0.1.7+10**, todavía sin
aplicarlo. Atención: pubspec conserva `0.1.5+7`; las candidatas usaron overrides
de compilación. No debe compilarse una actualización dejando ese code7.

## Matriz de compatibilidad

| Área | Esquema actual: camino compatible | Dependencia o validación pendiente |
| --- | --- | --- |
| Inicio y Explorar | Servicios y tarjetas Sky existentes | Recorrido físico y regresión del APK final |
| Promociones | Nuevo resolver público por ID, incluso fuera de primera página; carga, errores y deduplicación | No requiere migraciones; probar toque real en la candidata |
| Búsqueda de negocios | Consultas paginadas de 20, nombre/dirección, ID inicial y asociaciones existentes | Puede incorporarse para registro/reclamo/acceso; correcciones requieren separar el nuevo contrato |
| Solicitudes existentes | Registro, reclamo y acceso usan tablas/RPC existentes | Pruebas reales autorizadas por rol; no crear solicitudes en esta tarea |
| Correcciones estructuradas | La consulta y el INSERT usan campos ya existentes | **No habilitar el flujo completo**: falta aplicar_correccion_establecimiento, validación de propuestas y auditoría |
| Autenticación | Sin cambios respecto a develop/candidata | Login real, Google/callback, sesión conservada tras actualizar; integraciones no ejecutadas |
| Geolocalización y mapas | Sin dependencias nuevas de estas migraciones | Permisos, posición, mapa y precisión en Honor |
| Alertas foreground | Implementación existente conservada | Permisos/preferencias y entrega real en Production |
| Geofencing nativo Production | Adaptación ya incluida en code9, usa promociones reales y esquema existente | GO físico solo acreditado en STAGING; probar Production, bloqueo previo, ENTER, ID4819, cooldown y navegación |
| Administración existente | Lectura, respuestas de registro/reclamo/acceso y cambio de estado usan contratos existentes | No confundir moderación con aplicación de correcciones; el bypass administrativo del servidor no lo corrige un APK |
| Nueva seguridad administrativa | No requiere editar el geofencing | Depende de las dos migraciones; nueva RPC moderar_estado_establecimiento aún no está conectada al cliente |
| Diseño horario Sky | Hora local y retorno a foreground; cuatro ambientes y modo manual, sin SQL | Prueba visual/horaria en dispositivo; código intacto |

Esta matriz usa el SQL versionado y la auditoría de metadatos Production ya
documentada el 5 de noviembre. No se consultaron bases remotas en esta tarea:
no equivale a una reconfirmación actual de todas sus funciones/políticas.

## Bloqueo preciso de las correcciones

El cliente actual de esta rama envía `datos_propuestos.cambios` con valores
anteriores/nuevos. El validador anterior acepta un JSON no vacío: eso no
acredita el nuevo control de autorización, campos o concurrencia.

Al aprobar, el cliente llama `aplicar_correccion_establecimiento`, creada por
`20261106034310_aplicar_correcciones_estructuradas.sql`. Si falta, informa
PGRST202 sin falso éxito. Sin embargo, ofrecer el envío y una aprobación que
se sabe indisponible no constituye un flujo publicable terminado.

La RPC antigua `responder_solicitud_establecimiento` no aplica los cambios
del negocio al aprobar una corrección. No debe utilizarse como fallback para
anunciar que la corrección fue aplicada.

`20261107121537_cerrar_actualizacion_administrativa_directa.sql` restringe
el bypass de actualización administrativa, añade protecciones y la nueva RPC
de moderación. El cliente sigue enviando `.update({'estado': ...})`. La
migración conserva ese contrato limitado, pero aprobar una ficha no la
publica automáticamente. El flujo de publicación/republicación debe revisarse
al habilitar la nueva RPC. Los cambios de backend no están desplegados y no
pueden sustituirse por ocultar un botón en Flutter.

## Camino recomendado sin desplegar SQL

Es técnicamente posible preparar una APK compatible. No es necesario terminar
la restauración para las mejoras que solo usan los contratos existentes.
No es posible ofrecer correcciones estructuradas aplicadas y auditadas sin
el backend nuevo.

1. Preparar, después de revisar este plan, una rama separada de compatibilidad
   desde develop. Conservar íntegra la rama actual y los archivos locales de
   recuperación; no integrar sus tres commits en bloque.
2. Incorporar la corrección de navegación de promociones y las mejoras del
   selector que usan el esquema existente. Mantener tarjetas, geofencing,
   cooldown, autenticación y Sky sin alteraciones.
3. Acordar el modo compatible de correcciones antes de implementarlo: conservar
   el reporte manual existente y comunicar que la aplicación automática está
   pendiente; impedir que un nuevo flujo prometa una aprobación aplicada o
   auditada sin RPC. Desactivar/limitar una operación existente requiere
   aprobación explícita del propietario; no se cambió nada en esta tarea.
   No basta capturar PGRST202 después de pulsar Aprobar.
4. Añadir pruebas específicas del modo compatible: RPC ausente, reporte manual,
   aprobación sin falso éxito y preservación de registro/reclamo/acceso.
5. Fijar 0.1.7+10 y volver a ejecutar análisis, pruebas y verificaciones Android
   sobre ese código seleccionado. Los resultados de la rama actual no
   certifican una rama de compatibilidad todavía inexistente.
6. Solo con autorización de compilación, crear una candidata Release privada
   con paquete y firma originales y configuración Production. Para conservar
   geofencing debe mantener CERCLY_PRIVATE_PROXIMITY=true; la variante pública
   por defecto usa el código Android foreground y no lo incluye. No cambiar
   esta selección accidentalmente ni presentarla como autorización pública.
7. Autorizar la instalación y actualizar in-place en el Honor: nunca
   desinstalar, borrar almacenamiento ni bajar versionCode. Verificar antes
   paquete, certificado y versión realmente instalados. La identidad coincide
   con los APK conservados; no se inspeccionó la instalación actual del Honor.
8. Probar sesión/preferencias, permisos y consentimiento, mapas, promociones,
   solicitudes disponibles, administración y los cuatro ambientes. Después
   comprobar una transición GMS Production con promoción real vigente.
   La promoción documentada durante la code8 vencía el 5 de noviembre: no
   puede asumirse vigente ahora ni usarse UPEC/STAGING como sustituto.
9. Revisar privacidad/distribución y autorizar publicación por separado.
   Conservar la v0.1.1 pública y code9 privada, publicar en una nueva ruta y
   comprobar hash, firma y descarga antes de cambiar el botón público.

Una actualización compatible permite conservar los datos locales. No se
promete riesgo cero: debe ensayarse la actualización real y no regenerar la
clave de firma. Tampoco es un rollback seguro reinstalar un APK con menor
versionCode; una corrección posterior debe llevar un código superior.

## Pruebas de esta revisión

- Flutter analyze: sin incidencias.
- Flutter test: **286 aprobadas, 11 omitidas**; sin configuración remota.
- Suite focal con CERCLY_PRIVATE_PROXIMITY=true: **11 aprobadas**.
- Git diff --check: correcto.
- Manifiesto, versiones, firma de tres APK y certificado del keystore:
  comprobados sin compilar ni instalar.
- El primer lanzamiento de flutter test fue bloqueado por caché del SDK de
  solo lectura; se repitió con el acceso autorizado y terminó correctamente.
- Logs locales: `/tmp/cercly-mobile-readiness-flutter-test.log` y
  `/tmp/cercly-mobile-readiness-private-proximity-test.log`.

No se generó ninguna APK, no se desactivó funcionalidad, no hubo merge/push ni
conexiones a Supabase. Las correcciones de restauración permanecen intactas.

## Veredictos

- **APK móvil: GO para preparar una candidata compatible privada**, con el
  alcance y las pruebas anteriores; **NO-GO para publicación pública hoy** o
  para publicar esta rama completa como si las correcciones funcionasen.
- **Migraciones: NO-GO**. Falta completar la recuperación real (la corrección
  de siete propietarios tiene 30 pruebas sintéticas aprobadas, pero no se ha
  ensayado con el respaldo real), resolver los metadatos de propiedad
  faltantes, revisar las dependencias de eliminación/historial y autorizar
  después la validación remota controlada de STAGING. Production continúa
  fuera del alcance de cambios.
