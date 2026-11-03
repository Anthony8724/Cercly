> Actualización 2026-11-03: este documento conserva resultados históricos. El estado vigente y el GO técnico en Honor están en [el informe final](GEOFENCING_GO_HONOR_2026-11-03.md); para la entrega usar [la guía del 4 de noviembre](DEMO_ACADEMICA_2026-11-04.md). Las menciones a Honor pendiente y APK code6 más abajo corresponden al ensayo anterior.

# QA de geofencing Android Studio — 2026-11-01

## Veredicto

**NO-GO:** no se obtuvo evidencia del flujo geográfico automático. Ningún Android guest llegó a estar operativo y ADB no pudo ejecutar comandos dentro del sistema. No se instaló la APK ni se configuraron permisos, sesión o geofence. Este resultado describe un bloqueo del entorno de emulación, no un fallo demostrado de Cercly.

## Host y emulador

- Fedora Linux `7.2.5-200.fc44.x86_64`; AMD Radeon RX 6600/6600 XT.
- Android Studio Quail 4 (`2026.1.4 Patch 1`), Android Emulator `37.1.11.0`, ADB `37.0.1-15733141`.
- CPU anuncia `svm`; los módulos `kvm` y `kvm_amd` aparecen cargados, pero `/dev/kvm` no existe. `emulator-check accel` devuelve código 8. `/dev/dri` tampoco existe.
- El AVD instalado era `Pixel_7`, Android `37.2`, `google_apis_playstore_ps16k`, x86_64, Play Store habilitado. No había otra imagen de sistema instalada.
- Pixel_7 con `-accel off -no-snapshot -gpu swiftshader_indirect -feature -Vulkan -no-window` terminó con código 139. `coredumpctl` confirmó `SIGSEGV` en `qemu-system-x86_64-headless` (PID 54914; core de 407 MB). El backtrace disponible solo mostró la dirección no simbolizada `#0 ... n/a`; cargaba bibliotecas X11/GLES, por lo que el punto exacto del fallo no quedó determinado.
- Para probar otra configuración sin alterar Pixel_7, se creó en `/tmp/cercly-avds` un AVD temporal desde esa misma imagen, con pantalla 720×1600 y userdata limitado. Se intentó sin snapshots, sin aceleración hardware y con `swiftshader` y `software` (Lavapipe/ANGLE). ADB lo vio brevemente como `offline`; los procesos QEMU volvieron a terminar con código 139 (PIDs 57264 y 58437). La imagen elevó RAM invitada a 4 GB. No se borró Pixel_7 ni se descargaron imágenes.
- El primer intento del AVD temporal necesitó más espacio del disponible en `/tmp`; se redujo solo el tamaño del userdata temporal y el siguiente intento sí alcanzó a iniciar QEMU antes del SIGSEGV.
- ADB fuera del sandbox pudo crear el servidor y observar temporalmente `emulator-5554`/`emulator-5556` como `offline`; los sockets de ADB dentro del sandbox fallaron con `Operation not permitted`. Al final, `adb devices -l` no mostró dispositivos.
- Logs locales: `/tmp/cercly-geofencing-avd.log`, `/tmp/cercly-geofencing-avd-software.log`, `/tmp/adb.1000.log`; los coredumps quedan bajo `/var/lib/systemd/coredump/` según `coredumpctl`.

## Supabase Staging

Se hizo una consulta SQL de solo lectura al proyecto `dlajxviqhkdcqnmczhvr`, filtrada por los dos UUID especificados. La fila devuelta indicó:

- `Cercly Test — Proximidad`, estado aprobado y `publicable=true`.
- Promoción `Promoción de prueba Cercly`, `activa=true`, radio 5000 m.
- Vigencia: 2026-10-29 07:20:37 UTC a 2026-11-12 07:25:37 UTC; seguía vigente durante esta comprobación.
- Coordenadas públicas del establecimiento: `0.80525, -77.73434`.

No se modificaron datos, permisos ni configuración remota.

## Evidencias funcionales

| Evidencia requerida | Estado |
|---|---|
| AVD Android operativo y `sys.boot_completed=1` | **NO VERIFICADA**; AVDs terminaron en SIGSEGV. |
| APK Staging instalada | **NO VERIFICADA**; no hubo Android guest arrancado. |
| Google Play Services disponible en runtime | **NO VERIFICADA**; la imagen local tiene tag Play Store, pero no arrancó. |
| Permisos Android y consentimiento Cercly | **NO VERIFICADOS**; no se consultaron ni alteraron permisos. |
| Geofence aceptada por Google Play Services | **NO VERIFICADA**. |
| Ubicación exterior/interior y evento ENTER real | **NO VERIFICADOS**; no se usó el panel de simulación ni receiver QA. |
| Evento EXIT real | **NO VERIFICADO**. |
| Notificación automática de ENTER, pantalla bloqueada y navegación | **NO VERIFICADAS**. |
| Pruebas negativas de cooldown/permisos/vigencia | **NO EJECUTADAS** en dispositivo. |
| Capturas de pantalla de eventos/notificación | **NO DISPONIBLES**. |

No se usó la cuenta indicada, no se introdujeron credenciales, no se instaló la APK ni se hizo login.

## APK y calidad del código

La APK que habría correspondido instalar es la candidata existente `artifacts/Cercly-v0.1.5-staging-geofencing-experimental.apk` (paquete `com.cercly.cercly.staging`, versionCode 6, SHA-256 `e55c049b5c342f59e9c16b2c40174143b695e3d289a5054a00df79a48f5d2d6b`). No se reconstruyó otra APK porque no hubo cambio de código.

Se reejecutó calidad sobre el mismo código y artefacto: `flutter analyze` sin issues; `flutter test` con 257 aprobadas y 9 omitidas por no configurar Supabase en pruebas de integración; `git diff --check`, correcto. Las pruebas focales Staging anteriores registraron 15 aprobadas. Esta investigación no modificó código de la aplicación.

## Qué hace falta para reanudar

El bloqueo observable es que el entorno tiene `kvm_amd` cargado pero no expone `/dev/kvm`, carece de `/dev/dri` y los QEMU de esta imagen acaban en SIGSEGV con backtrace sin símbolos. No se cambió configuración del host para intentar crear dispositivos del kernel. Reanudar en Android Studio ejecutado en un host donde el AVD tenga acceso real a KVM, o con un dispositivo Honor autorizado por ADB. Luego ejecutar el protocolo de exterior → interior → salida y recopilar `logcat`, panel QA y captura de notificación. Una alarma programada o una simulación QA no sustituye esa evidencia.
