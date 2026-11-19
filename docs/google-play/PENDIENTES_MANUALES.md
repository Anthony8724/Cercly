# Pendientes indispensables

No se necesita repetir el merge #40. Esta lista agrupa lo que requiere acceso externo, decisión del titular o una validación aún no demostrada.

## Verificados

Merge, RIIOTE, regresión, manifiesto, firma local, alineación, artefactos candidatos, recursos de marca y propuesta web/documental. Los archivos +25 originales se conservan. No se modificó main ni se publicó una release pública.

## Pendientes de comprobar

| Acción | Evidencia necesaria | Quién / acceso |
|---|---|---|
| Obtener datos de Play Console | Tipo de cuenta, fecha de creación, permisos y app/package existente | Propietario o usuario con permisos legítimos |
| Verificar versión | Máximo versionCode en todos los tracks/App Bundle Explorer <26 | Console; si no, elegir superior y recompilar APK/AAB |
| Verificar firma | SHA-256 de upload certificate coincide con f0498657…866d5; distinguir app signing certificate | Console, Integridad de la aplicación |
| Play App Signing | Estado de inscripción y firmas de OAuth/FCM/deep links compatibles | Console/Firebase/Supabase |
| Cerrada 12/14 si aplica | Inscripción continua y resultado de solicitud de acceso a Producción | Console; no inferir por APK instalado |
| Validar eliminación | Fixture sintético autorizado y evidencia en Auth, Postgres, Storage, sesiones y canal externo | Staging primero; no borrar usuarios reales |
| Verificar URL pública | Política completa HTTP 200 sin redirección a portada, sin login; eliminación localizable | Después de aprobación y despliegue web separado |
| Verificar SDK y terceros en ejecución | Captura de tráfico/datos automáticos y restricciones de claves públicas | Dispositivo autorizado y consolas de proveedores |
| Probar APK 26 | Checklist PRUEBAS_Y_RIESGOS, Android 15/16, 16 KB cuando disponible | Dispositivo; AVD actual falla al arrancar |
| Capturas | 4–6 pantallas reales sin datos personales | APK 26 definitivo y datos autorizados |
| Roles y datos de negocio autenticados | Las 9 pruebas públicas de lectura ya aprobaron en Production; falta verificar áreas de negocio autenticadas con cuentas dedicadas | Staging o fixture autorizado |

## Decisiones del propietario

1. Resolver con evidencia la compatibilidad del envío de coordenadas personales con los términos de HeiGIT, o aprobar una alternativa mínima y su validación. No basta el aviso actual. Contactar al proveedor requiere una instrucción explícita para enviar el mensaje.
2. Aprobar retención por categoría, respaldos y atención de derechos; el borrador web de soporte sigue sin aprobar y no fija plazos para toda la app. Confirmar domicilio legal cuando corresponda.
3. Definir público/edades, países, modelo comercial, anuncios/promociones destacadas, términos de contenido aportado y posibles requisitos de pagos. Preparar IARC con datos reales, no asignar rating automáticamente.
4. Preparar cuentas de revisión de usuario y negocio con credenciales fuera de Git, sin bloqueo OTP innecesario; describir permisos o datos de demostración autorizados sin habilitar roles por metadatos editables.
5. Revisar y aprobar política, Data safety, declaraciones de ubicación y eliminación, ficha y recursos gráficos. No se han enviado como formularios definitivos.
6. Aprobar la integración/publicación web por separado: [PR #15](https://github.com/Anthony8724/cercly-web/pull/15). No fusionarlo a main ni desplegar Producción sin validar el conjunto.
7. Revisar el PR de release hacia develop. Si cambia código/configuración, volver a generar artefactos y hashes; la carpeta candidata actual no se actualiza silenciosamente.
8. Una vez cerrados todos los controles, autorizar carga a Console y, por separado, envío/rollout. No se realizó ninguna de esas acciones.

## Secuencia concreta de cierre

Resolver proveedor y retención → integrar/revisar web y comprobar URL pública → ensayo de eliminación con fixture → verificar Console/certificado/versionCode → QA y capturas con artefacto definitivo → aprobar declaraciones y ficha → carga autorizada a track correspondiente → revisar informe previo al lanzamiento y, si aplica, prueba cerrada → aprobación explícita de envío/Producción.

**NO-GO mientras persista cualquiera de los bloqueos obligatorios de ESTADO_PUBLICACION.md.**
