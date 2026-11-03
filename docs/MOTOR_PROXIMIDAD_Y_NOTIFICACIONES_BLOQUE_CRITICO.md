> Actualización 2026-11-03: este documento conserva resultados históricos. El estado vigente y el GO técnico en Honor están en [el informe final](GEOFENCING_GO_HONOR_2026-11-03.md); para la entrega usar [la guía del 4 de noviembre](DEMO_ACADEMICA_2026-11-04.md). Las menciones a Honor pendiente y APK code6 más abajo corresponden al ensayo anterior.

# Motor de proximidad y notificaciones — auditoría y alcance

Preparado el 1 de noviembre de 2026 para Cercly `0.1.4+5`.

## Hallazgos auditados

| Clasificación | Hallazgo | Decisión |
| --- | --- | --- |
| Defecto comprobado | La solicitud de notificaciones podía repetirse al activar alertas después de una denegación. | Se persiste localmente que Cercly ya mostró/resolvió la solicitud. El sistema se vuelve a consultar y sigue siendo la autoridad. |
| Defecto comprobado | El estado de ubicación y notificaciones no se mostraba de forma continua en la configuración. | Se añadieron filas de estado para permisos reales, precisión, disponibilidad de segundo plano y última comprobación; no se leen coordenadas para mostrarlas. |
| Defecto comprobado | El botón de Ajustes no siempre aparecía tras una denegación normal de ubicación. | Se muestra cuando falta cualquiera de los permisos requeridos. |
| Riesgo de diseño | La consulta del monitor usa un temporizador Dart de cinco minutos y deja de ejecutarse cuando la app pasa a segundo plano. | Se mantiene explícitamente como alternativa de primer plano; el temporizador no se considera un mecanismo de segundo plano. |
| Riesgo de diseño | La posición aproximada o con precisión mayor a 100 m no genera alertas. | Se informa como ubicación imprecisa; se conserva el umbral para evitar avisos incorrectos en radios pequeños. |
| Limitación de Android | Los permisos temporales pueden revocarse al salir de la app y los permisos persistentes pueden cambiar en Ajustes. | Cercly no guarda ni restaura permisos. Reconsulta Android al volver al primer plano y deriva a Ajustes cuando hace falta. |
| Funcionalidad pendiente | No hay GeofencingClient, BroadcastReceiver, PendingIntent de geofence, restauración de geofences ni worker de sincronización. | No se agrega a Production por la restricción de política descrita abajo. |

## Flujo y reglas actuales

- La bienvenida explica las finalidades y permite continuar sin aceptar; no solicita permisos.
- El consentimiento local de uso y el interruptor de alertas se guardan aparte de los permisos de Android.
- La app informa que su ubicación es de primer plano. El plugin Geolocator expone `whileInUse`/`always`, pero no expone por separado la marca Android «Solo esta vez»; si Android revoca ese permiso temporal, Cercly detecta la revocación en el siguiente inicio o regreso a primer plano. Production no solicita «Permitir todo el tiempo».
- Activar alertas es una acción explícita. Se comprueba ubicación en primer plano, precisión reciente y permiso de notificaciones antes de guardar la preferencia activa.
- El monitor vuelve a consultar el permiso del sistema, el canal de notificaciones y la ubicación. Se detiene cuando la app se pausa y vuelve a evaluar al regresar.
- Supabase entrega promociones activas y vigentes, unidas a establecimientos aprobados y publicables. La distancia y el radio efectivo se calculan localmente; se aplica el menor entre el radio elegido y el radio de la promoción.
- El control local aplica cooldown de dos horas, intervalo global de quince minutos, máximo de tres avisos en 24 horas y evita repetir mientras la promoción permanece dentro de la zona. La persistencia contiene identificadores y tiempos, no coordenadas ni recorridos.
- Las consultas de alertas no resuelven imágenes. No se ejecutaron migraciones ni escrituras en Supabase remoto.
- El canal `promociones_cercanas` usa importancia alta, sonido y vibración habilitados por defecto. Android permite a la persona cambiar el canal; Cercly no sobrescribe la configuración existente del canal.
- La notificación carga el ID del establecimiento en el payload. Al tocarla, se vuelve a consultar la ficha pública y se informa si ya no está disponible. La ficha pública no exige iniciar sesión.

## Segundo plano y publicación

La implementación no declara `ACCESS_BACKGROUND_LOCATION` ni registra geofences. Google Play exige que el acceso en segundo plano sea necesario para la función principal, significativo para las personas usuarias, divulgado en la app y en la ficha de tienda, y aprobado mediante la declaración de Play. Su guía cita las promociones dirigidas por ubicación como un beneficio de conveniencia mínimo frente a usos de mayor valor y dice que la ubicación en segundo plano no debe solicitarse solo para anuncios/ofertas. La aprobación para alertas comerciales no puede suponerse.

Android exige ubicación precisa y, al apuntar a API 29 o posterior, permiso de segundo plano para geofencing. El límite documentado es 100 geofences por app y usuario. Los eventos pueden demorarse en segundo plano; tras reinicio del dispositivo se requiere volver a registrar geofences. Este flujo queda sin implementar y apagado en Production hasta una revisión de elegibilidad, divulgación y aprobación de Play. No se pide desactivar optimizaciones generales del dispositivo.

Alternativa Production válida: consentimiento opcional, ubicación de primer plano y revisión periódica solo mientras Cercly está visible. En Honor/MagicOS, las restricciones de batería pueden afectar las actividades en segundo plano, pero no se afirma compatibilidad de segundo plano porque esa función no está presente.

Referencias oficiales:

- [Política de ubicación en segundo plano de Google Play](https://support.google.com/googleplay/android-developer/answer/9799150)
- [Requisito vigente de target API de Google Play](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Geofencing y requisitos de Android](https://developer.android.com/develop/sensors-and-location/location/geofencing)
- [Permisos de ubicación de Android](https://developer.android.com/develop/sensors-and-location/location/permissions)

## Validación y límites

Las pruebas de controlador cubren promociones activas/vigentes, radio, cooldown, máximo global, deduplicación e historial persistente. Las pruebas locales cubren consentimiento/preferencias y parsing del payload. La consulta al plugin `show()` demuestra que la llamada local fue aceptada por el plugin, no que Android haya mostrado la notificación al usuario.

El test suite que acompaña esta auditoría es automatizado y no sustituye una prueba de sistema. La entrega visual, sonido/vibración, toque con app visible, minimizada y proceso terminado, y el evento real de geofence requieren dispositivo/emulador con una build instalada. La compatibilidad Honor requiere dispositivo Honor conectado; no se infiere desde un Pixel.

No se almacenan ubicaciones ni historial de recorridos. El nuevo dato de “última comprobación” es una marca UTC local sin coordenadas. El historial de frecuencia guarda IDs de promociones y marcas de tiempo locales.

### Ejecución del 1 de noviembre de 2026

- `flutter analyze`: sin problemas.
- `flutter test`: 238 aprobadas; 9 omitidas por falta de configuración de Supabase en la ejecución general.
- Integración de lectura contra Production: 8 pruebas aprobadas para promociones y establecimientos, usando `config/supabase.local.json`; no hubo operaciones de escritura.
- Consulta agregada de solo lectura en Production: 1 promoción figura vigente, activa y unida a un establecimiento aprobado/publicable al momento de la auditoría. No se extrajeron títulos, IDs ni coordenadas.
- `git diff --check`: sin errores.
- Release APK: compilada y verificada con `apksigner`; la huella del certificado coincide con `0.1.3` y `zipalign -c -v 4` aprobó.
- Paquete y versión: `com.cercly.cercly`, `0.1.4`, versionCode `5`, targetSdk `36`.
- El targetSdk `36` satisface el requisito de Google Play vigente desde el 31 de agosto de 2026 para nuevas apps y actualizaciones móviles.
- Manifiesto fusionado: conserva ubicación foreground y `POST_NOTIFICATIONS`; no contiene `ACCESS_BACKGROUND_LOCATION`, receiver de geofence ni `RECEIVE_BOOT_COMPLETED`.
- El AVD Pixel 7 instalado (emulador 37.1.11, Android 37) terminó dos arranques con código 139, incluso fuera del sandbox. No quedó un dispositivo ADB conectado; no se verificaron entrega visual real, sonido/vibración, navegación por toque ni comportamiento Release instalado. No hay dispositivo Honor conectado.
- No se midió consumo de batería en dispositivo. Por diseño foreground, Cercly no inicia un stream continuo ni un servicio GPS; solicita una lectura de posición por evaluación y consulta como máximo cada cinco minutos mientras está visible.

Candidata generada: `artifacts/Cercly-v0.1.4-production-release.apk`, 62,292,438 bytes, SHA-256 `4c5cd6ff7bcae589e96d1d9d394721f68a4b91409f6d06b270b608dc6d938504`. No se publicó ni se sustituyó ninguna APK anterior.

La política de privacidad disponible en el repositorio permanece como borrador interno; sus datos de producción, responsables, proveedores y conservación no están verificados. La publicación requiere cerrar esa revisión y ejecutar pruebas Android de entrega y navegación. Para Android 17/API 37, volver a revisar antes del 27 de enero de 2027 las nuevas reglas de Play sobre acceso mínimo de ubicación.
