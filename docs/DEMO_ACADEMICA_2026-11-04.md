# Demostración académica — 4 de noviembre de 2026

Usar **Cercly STAGING 0.1.5/code7**, la misma APK validada en Honor LLY-LX3 (X8b). No usar la antigua variante `.demo`: esa variante de evaluación aislada no equivale al experimento conectado de geofencing.

## Explicación al docente (un minuto)

«Cercly avisa sobre promociones cercanas con consentimiento. Flutter presenta los establecimientos y las preferencias. En segundo plano registramos una zona en Google Play Services; cuando Android detecta una entrada, entrega un evento al receptor Kotlin aunque Flutter no esté visible. El receptor consulta la promoción, comprueba permisos, consentimiento, vigencia y límites de frecuencia, y publica una notificación. Al tocarla se abre la ficha pública.

Para reproducirlo en el aula usamos FakeTraveler como proveedor de ubicación de desarrollo. La ubicación es simulada, pero la transición ENTER la calcula Google Play Services: no estamos pulsando el botón que simula el receptor. El 3 de noviembre se comprobó este flujo con el Honor bloqueado, incluida la navegación. Sigue siendo un prototipo Staging, no una funcionalidad aprobada para publicación en Google Play.»

## Preparación previa

1. Mantener instalada la APK code7 y la sesión normal de Staging. No reinstalar, actualizar ni borrar datos antes de la exposición si no hace falta. Una actualización puede retirar geofences y exigir nuevo registro.
2. Conexión a Internet, ubicación del dispositivo activada y Play Services disponible. En Cercly → Configuración, comprobar notificaciones y canal, ubicación precisa, permiso «Permitir todo el tiempo», consentimiento de alertas y consentimiento experimental de segundo plano. Si falta permiso, usar el flujo visible: foreground primero, explicación y background después; no cambiarlo por ADB.
3. Comprobar el establecimiento **Cercly Test — Proximidad**, campus UPEC, y su promoción actual. El 3 de noviembre la ficha mostró vigencia hasta 12/11/2026; comprobarla otra vez mañana sin editar Supabase. Si caducó, detener la demostración automática.
4. FakeTraveler 2.3.2 ya está seleccionada como aplicación de ubicación simulada. Configurar inicialmente movimiento latitud/longitud 0/0, intervalo 10 s y repetición 0 (continua). Aplicar **0.88000, −77.73434**, aproximadamente 8.3 km al norte de UPEC.
5. En Cercly, consultar ubicación: debe indicar aproximadamente **8312 m**, fuera del radio de **5000 m**. Confirmar un EXIT nuevo en el diagnóstico real si la zona estaba activa. Si se perdió el registro, pulsar «Registrar zona UPEC» estando fuera, esperar aceptación nueva y documentar ese caso; no confundir una confirmación histórica con inventario actual.
6. Solo después, pulsar «Reiniciar cooldown de pruebas» y confirmar una vez. Exigir **UPEC libre, global libre y hoy 0/3**. Esperar a que termine cualquier evaluación y comprobar los valores: un mensaje de éxito sin contadores no basta. No desactivar y reactivar consentimientos como sustituto.

## Demostración automática con pantalla apagada (reservar 10–15 minutos)

En los ajustes de FakeTraveler introducir:

| Campo | Valor |
|---|---:|
| Inicio | 0.88000, −77.73434 |
| Número de muestras | 61 |
| Intervalo | 10 segundos |
| Movimiento latitud (microgrados, NO grados) | −1495 |
| Movimiento longitud | 0 |

Detener la emisión exterior anterior, aplicar el recorrido una sola vez y bloquear inmediatamente. Cercly debe permanecer en segundo plano. No volver a abrir Cercly para «ayudar» a que llegue el aviso.

El cruce calculado del radio ocurre alrededor de 3 min 20 s; el trayecto pasa por el centro UPEC a los 8 min 20 s y termina a los 10 min dentro de la zona. Android puede retrasar el evento. No se promete una notificación a un segundo exacto.

Éxito: ENTER nativo nuevo posterior al bloqueo, publicación de aviso nuevo y ficha UPEC al tocarlo. Con ADB se puede capturar el tag `CerclyGeofence` a nivel I; en este Honor fue necesario habilitar temporalmente `log.tag.CerclyGeofence=I` y restaurarlo al valor anterior al terminar. Las marcas de prueba de Logcat deben identificarse como ADB, nunca como ENTER. Sin ADB, mostrar después el diagnóstico real de Cercly y contrastar sus horas; no sustituye toda la evidencia técnica archivada.

Si llega la alerta, desbloquear y tocar **«Promoción cerca de ti» de Cercly STAGING**. Mostrar nombre, dirección UPEC y promoción. El aviso nativo usa ID4819; la alarma QA usa4822 y la simulación QA tiene su propio resultado. Mantener estos mecanismos diferenciados durante la explicación.

Si no llega, conservar el resultado: falta de ENTER, permiso, vigencia, red o cooldown son fallos diferentes. No repetir recorridos ni reiniciar contadores a ciegas. Presentar el informe del ensayo del 3 de noviembre como evidencia previa, sin afirmar que fue una entrega en vivo. Una alarma programada puede demostrar notificaciones, pero no demuestra geofencing.

## Al terminar

Detener FakeTraveler y cerrar su pantalla con Atrás. El ensayo mostró que agotar las 61 muestras puede dejar proveedores mock registrados: cerrar la conexión del servicio retiró GPS/network/fused. Verificar ausencia de proveedores mock y retorno a ubicación normal. Recuperar contador 0, intervalo 10 s y movimientos 0/0 sin volver a aplicar. Restaurar Logcat si se habilitó. No borrar datos ni cambiar permisos del Honor.

## Material para entregar

- [Arquitectura, límites y evidencia del ensayo](GEOFENCING_GO_HONOR_2026-11-03.md).
- [Identidad y comprobación de la APK](APK_DEMOSTRACION_2026-11-04.md).
- Evidencias originales conservadas localmente en `artifacts/honor-final-20261103-125424/`; no se publican registros privados, capturas del teléfono ni credenciales en GitHub.
