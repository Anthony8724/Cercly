# QA de RC2 en teléfono HONOR real

**PENDIENTE DE EJECUCIÓN.** adb devices no encontró dispositivos; la prueba histórica +25 no acredita RC2. No se borró, instaló ni modificó nada en un teléfono.

## Preparación segura

Usar teléfono autorizado, cable y depuración USB consentida. Registrar modelo, MagicOS/Android, versión instalada, estado de permisos y SHA del APK. No recopilar IMEI, correo personal ni coordenadas privadas en evidencias.

```sh
adb devices -l
adb -s SERIAL shell getprop ro.product.model
adb -s SERIAL shell getprop ro.build.version.release
adb -s SERIAL shell dumpsys package com.cercly.cercly
sha256sum /ruta/Cercly-Produccion-0.1.9+26-RC2.apk
```

Antes de instalar: comparar firma y sincronización de preferencias de la instalación existente. La nueva firma debe coincidir; no desinstalar una app con datos locales pendientes ni usar opciones de borrado para forzar instalación. No instalar con `-d` para ocultar un downgrade. Con autorización y compatibilidad comprobada: `adb -s SERIAL install -r /ruta/Cercly-Produccion-0.1.9+26-RC2.apk`. Si Console exige otro código, regenerar artefactos antes del ensayo.

Usar acceso invitado y datos públicos para lectura. Login/escrituras/eliminación solo con cuentas y fixtures designados de un entorno autorizado. No usar cuentas reales para verificar supresión. No habilitar flags de proximidad ni rutas simuladas. Separar APK Staging y Production por package/etiqueta y no intercambiar sus endpoints.

## Casos y criterios

| Caso | Acción | Resultado que debe observarse |
|---|---|---|
| Inicio | Instalar/abrir y reiniciar | Sin crash, identidad Cercly Sky y package/versión correctos |
| Ubicación denegada | Explorar sin permiso o cancelando aviso | Funciones limitadas explicadas; no permiso insistente ni bloqueo total accidental |
| Aproximada/precisa | Probar ambas con autorización | Resultados coherentes; no exigir precisa para abrir mapas externos |
| Cómo llegar sin GPS | Abrir detalle → botón | Aviso Google Maps; no diálogo de GPS ni ruta interna |
| Cancelar | Cancelar Maps | Permanece en Cercly, sin apertura ni petición de ruta |
| Confirmar | Abrir Maps | Destino correcto; el enlace de Cercly no incluye origen. Maps puede pedir su propio permiso |
| Fallo de handler/red | Maps no disponible o navegador offline | Mensaje/reintento; nunca fallback a HeiGIT ni línea simulada |
| Radar inicial | Abrir Mapa sin activarlo | Inactivo; no sondeo/aviso por apertura de pantalla |
| Radar voluntario | Activarlo con preferencias/permiso y después ocultar app | Comportamiento foreground validado, sin activar geofencing Production |
| Notificaciones | Denegar/revocar y reiniciar | No se activan por una preferencia de otra cuenta; push promocional sigue bloqueado |
| RIIOTE | Abrir Mi cuenta y pulsar enlace con cuenta QA | Footer visible sin overflow; abre riiote.org o informa fallo |
| Sesión | Login/OAuth/recuperación/cambio de cuenta QA | Deep link correcto, sin fuga de sesión/preferencias entre identidades |
| Datos públicos | Categorías, mapa, detalles y promociones vigentes | Cargas/errores claros y atribución visible, sin cubrirla con Radar |
| Eliminación | Fixture Staging después de corregir/validar backend | Solicitud simple completa; dependencias en revisión; sin tocar datos ajenos |
| Accesibilidad | Texto 200 %, TalkBack, teclado/back, barras | Controles legibles, foco/etiquetas y contenido no recortado |
| HONOR | Batería/segundo plano y retorno desde Maps | No prometer servicios bloqueados; recuperar UI/sesión sin crash |

La ausencia de un aviso visible no prueba ausencia de tráfico. Las pruebas unitarias y el escaneo AOT corroboran el bloqueo; confirmar ejecución con herramientas autorizadas en dispositivo/entorno de prueba sin desactivar TLS, exponer tokens ni registrar GPS real. El SDK Firebase puede realizar limpieza de estados previos: documentarla, no describirla como push activado.

Resultado por caso: APROBADO/PENDIENTE/FALLIDO, dispositivo/SO/build, pasos, evidencia saneada e incidencia. No completar filas como APROBADO por tener instrucciones.
