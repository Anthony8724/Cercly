# Candidata privada Production para la entrega del 4 de noviembre

Esta candidata incorpora zonas de promociones reales de Production al mecanismo nativo de geofencing. Su integración local tiene pruebas automatizadas; **su comportamiento físico aún debe validarse en el Honor con autorización del propietario**. El GO técnico del 3 de noviembre corresponde a STAGING y no certifica esta adaptación.

## Separación de variantes

| Variante | Identidad / backend | Segundo plano | Herramientas QA |
|---|---|---|---|
| Production habitual | Cercly / `com.cercly.cercly` / Production | No se compila | No se compilan |
| Candidata privada | Cercly / `com.cercly.cercly` / Production | Se compila con `CERCLY_PRIVATE_PROXIMITY=true`; consentimiento apagado inicialmente | No se compilan |
| STAGING | Cercly STAGING / `com.cercly.cercly.staging` / Staging | Experimento UPEC validado | Sí, exclusivas de STAGING |

La bandera privada es incompatible con STAGING, evaluación y demo offline. Gradle exige el host Production y una clave publicable; rechaza variables de credenciales de servidor. No se cambian Flutter, Gradle, NDK ni Play Services. JUnit se añade solo como dependencia de pruebas locales.

Los archivos originales `MainActivity.kt` y `GeofenceExperiment.kt` se trasladaron de `src/main/kotlin` a `src/staging/kotlin`, sin cambios en su contenido. La candidata utiliza `src/productionCandidate`; Production habitual utiliza `src/production`. Los manifiestos también se seleccionan por variante. El workflow de develop continúa generando únicamente Debug STAGING.

## Arquitectura de la candidata

1. La sección de configuración solicita consentimiento independiente, después de las alertas de primer plano, ubicación precisa y notificaciones. El acceso «todo el tiempo» se concede separadamente en Ajustes Android. No se solicitan permisos durante el arranque ni se activa automáticamente a usuarios existentes.
2. `ProductionGeofencingService` reutiliza `PromocionPublicaService.listarVigentes`: activa, dentro de vigencia, establecimiento aprobado y publicable. Con una posición puntual elige las 20 promociones más cercanas dentro de 25 km. No almacena esa posición. Deduplica por UUID y limita cada radio al mínimo entre la preferencia, el radio comercial y 5 km; descarta radios inferiores a 100 m.
3. El canal `cercly/production_proximity` entrega geometrías de negocios públicos a Kotlin. La persistencia contiene estas zonas, consentimiento, timestamps técnicos y límites de notificación; no contiene recorridos.
4. `GeofencingClient` registra ENTER y EXIT con `INITIAL_TRIGGER_ENTER`, mediante un `PendingIntent` explícito y mutable para que Google Play Services adjunte el evento. Los receptores son internos (`exported=false`). La aceptación solo se informa tras el callback exitoso; un fallo de retirada impide un nuevo registro y queda identificado. Los callbacks comprueban cambios de consentimiento durante la operación.
5. ENTER registra su timestamp antes del cooldown. EXIT registra salida y no notifica. El receptor usa `goAsync`, una consulta pública HTTPS por lote y límites de tiempo/tamaño. No usa Timer Dart, servicio GPS permanente, Firebase ni alarmas QA.
6. Antes de notificar vuelve a leer Production con clave publicable, respetando RLS: UUID y negocio coincidentes, publicación, aprobación, estado, inicio, fin, geometría y radio. Una promoción retirada, caducada, con ubicación cambiada o sin respuesta verificable se omite. No se reutiliza una respuesta comercial guardada para autorizar la notificación.
7. La posición entregada por GMS debe tener precisión conocida de hasta 200 m (y como máximo la mitad del radio), antigüedad de hasta cinco minutos y quedar dentro del radio incluyendo su margen de precisión. Una ubicación incierta se rechaza.
8. El historial anterior de notificaciones Flutter se importa una vez sin borrarlo. El motor nativo y las notificaciones foreground reservan en el mismo registro: dos horas por promoción, 15 minutos globales, tres avisos por 24 horas móviles. Se conserva la reserva si falla la entrega, para evitar reintentos que generen spam. No existe reset en la candidata.
9. La notificación usa el canal existente y respeta sus preferencias, ID nativo 4819 y `PendingIntent` de apertura inmutable. El UUID del negocio llega al flujo público existente, tanto en arranque frío como con la aplicación abierta. Si el negocio no está disponible, se informa al usuario.
10. Desactivar segundo plano o las alertas generales revoca el consentimiento local y solicita la retirada de zonas. Si Android revoca permisos, se omiten eventos y se retiran registros al comprobarlo. Una actualización o reinicio solicita restauración de las zonas aún vigentes, con consentimiento y permisos; no garantiza que Android ejecute el receptor.

## Actualización de zonas y límites conocidos

- Las zonas caducan como máximo en siete días o al final de la promoción. Android elimina geofences expiradas.
- La selección se actualiza al volver a primer plano, limitada a una vez cada 15 minutos por proceso, o mediante «Actualizar zonas cercanas». No hay sincronización periódica en segundo plano: promociones nuevas y cambios de ciudad requieren volver a abrir Cercly. La consulta pública reutilizada conserva el límite de filas del backend; antes de expansión masiva necesita paginación/selección geográfica en servidor.
- GMS no permite listar las geofences activas. El panel distingue zonas guardadas de aceptación histórica y no asegura que sigan registradas.
- `INITIAL_TRIGGER_ENTER` puede producir entrada estando ya dentro al registrar. Para demostrar una transición exterior→interior, registrar estando fuera.
- No se garantiza entrega tras Forzar detención, sin conexión, sin Play Services o bajo restricciones Android/MagicOS. No se pide desactivar protecciones generales.
- No se ha medido consumo de batería de esta adaptación. El diseño usa geofencing y posiciones puntuales, sin seguimiento permanente.
- No se han ejecutado aún pruebas físicas de esta candidata, restauración tras reinicio ni revocación en Honor. Las pruebas unitarias de política y navegación no sustituyen esas comprobaciones.
- Los errores se guardan como resultados técnicos locales. No hay Logcat de coordenadas, claves o credenciales ni endpoints QA en Production.

## Compilación reproducible

Desde una configuración local ignorada por Git que contenga solo `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` de Production, y la firma local existente:

```sh
flutter build apk --release --dart-define-from-file=config/supabase.local.json \
  --dart-define=CERCLY_PRIVATE_PROXIMITY=true --build-name=0.1.6 --build-number=8
```

La bandera no está habilitada en pubspec ni en CI. El APK debe identificarse externamente como **candidata privada**, sin sustituir el APK público. La aplicación conserva nombre Cercly y no muestra el indicador STAGING.

## Demostración propuesta en Honor, después de autorizar la instalación

1. Actualizar Production mediante instalación compatible, sin desinstalar ni limpiar datos. STAGING permanece instalada por separado como respaldo validado.
2. Abrir Cercly → Configuración → alertas cercanas. Revisar ubicación precisa, notificaciones y radio preferido. Si existe cooldown real, respetarlo; la candidata no ofrece reinicio.
3. En «Alertas de promociones en segundo plano», leer y aceptar la divulgación. Conceder «Permitir todo el tiempo» mediante Ajustes y volver.
4. Comprobar que sigue vigente una promoción real. En la consulta pública realizada durante esta preparación había una promoción de **PlasmaGames**, aprobada y publicada, con radio 5000 m y fin `2026-11-05T16:33:03Z` (11:33 del 5 de noviembre en Ecuador). Su título es «hora de juego a 69ctvs solo hoy»; la elegibilidad se rige por las fechas almacenadas, no por el texto del título. No se alteró este dato remoto. El estado puede cambiar después de la consulta. Las coordenadas públicas consultadas del negocio son `0.8033016, -77.7287413`; no son las coordenadas ficticias UPEC.
5. Para una prueba controlada, usar únicamente el mecanismo de ubicación de desarrollo autorizado. Una posición exterior de referencia es `0.88000, -77.73434`, a más de 8 km del negocio. Estar fuera del radio del negocio, pulsar «Actualizar zonas cercanas» y esperar aceptación nueva. No utilizar UPEC como identificador fijo: las zonas pertenecen a promociones reales y el radio efectivo depende de las preferencias.
6. Preparar un recorrido que cruce la zona después de bloquear el teléfono. Capturar por separado estado previo de bloqueo, ENTER nativo nuevo, resultado `native_notification_posted`, registro Android de ID 4819 y apertura del negocio. La configuración muestra timestamps técnicos sin coordenadas personales. No abrir Cercly antes de preservar la evidencia de segundo plano.
7. Tocar la notificación y verificar la ficha pública. Detener la ubicación simulada y restaurar el estado normal al terminar. No presentar una alerta foreground ni un aviso histórico como entrega nativa nueva.

## Publicación pública

**NO-GO para publicación pública.** La distribución privada no equivale a aprobación de Google Play. Las políticas restringen la ubicación de segundo plano y prohíben solicitarla con la única finalidad de publicidad o analítica. Hay que resolver la admisibilidad del beneficio, divulgaciones, política de privacidad publicada, formulario y revisión antes de distribuir ampliamente.

Fuentes oficiales consultadas:
- [Android: geofencing, límites y retrasos](https://developer.android.com/develop/sensors-and-location/location/geofencing).
- [Google Play: ubicación en segundo plano](https://support.google.com/googleplay/android-developer/answer/9799150).
- [Android: fuentes Kotlin por variante con AGP](https://developer.android.com/build/migrate-to-built-in-kotlin).

Las evidencias físicas previas siguen en `artifacts/honor-final-20261103-125424/`; el APK STAGING validado no se reemplaza. Resultados de esta candidata: `artifacts/production-private-20261103/`. Firma, tamaño, SHA-256 y conclusión de compilación se consignan en el informe de ese directorio.
