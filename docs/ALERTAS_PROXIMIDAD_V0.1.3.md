# Cercly v0.1.3 — privacidad y alcance de proximidad

## Comportamiento incluido

- La ubicación para explorar se pide al usar por primera vez una función que la
  necesita. Cercly conserva el consentimiento de uso por separado del permiso
  de Android y obtiene una posición nueva al volver a primer plano cuando
  Android aún concede el permiso.
- Las alertas son opcionales y solo funcionan con Cercly visible. El monitor
  consulta cada cinco minutos mientras está en primer plano; no mantiene GPS
  continuo ni programa trabajo en segundo plano.
- En la consulta de alertas, Cercly descarga promociones vigentes y calcula la
  distancia en el dispositivo. No envía las coordenadas al servicio de
  promociones para esa evaluación.
- El dispositivo conserva identificadores de promociones y marcas de tiempo
  para aplicar cooldown y límites de frecuencia. No conserva rutas ni
  coordenadas en ese historial.
- La aplicación solicita ubicación solo en primer plano y notificaciones solo
  cuando la persona activa las alertas. No declara
  `ACCESS_BACKGROUND_LOCATION`.

## Antes de considerar geofencing

Geofencing requeriría una explicación y consentimiento separados, solicitud
posterior al permiso en primer plano y, según la versión de Android, el flujo
oficial de permiso «Permitir todo el tiempo». Android puede retrasar los
eventos en segundo plano y los fabricantes pueden imponer límites de batería;
no se debe prometer inmediatez o ejecución continua. Cercly tendría que
registrar y actualizar geofences finitos sin almacenar recorridos, validar
promociones en el momento de la alerta y eliminar geofences al revocar el
consentimiento.

Antes de solicitar `ACCESS_BACKGROUND_LOCATION` para distribución por Google
Play, producto y privacidad deben confirmar que esta función es esencial y
aporta un beneficio significativo, preparar la divulgación visible y completar
la declaración de Play. Las alertas promocionales no deben suponerse elegibles
sin esa revisión.

Referencias oficiales consultadas:

- [Permisos de ubicación en segundo plano para Android](https://developer.android.com/develop/sensors-and-location/location/permissions/background)
- [Geofencing en Android](https://developer.android.com/develop/sensors-and-location/location/geofencing)
- [Política de ubicación en segundo plano de Google Play](https://support.google.com/googleplay/android-developer/answer/9799150)
