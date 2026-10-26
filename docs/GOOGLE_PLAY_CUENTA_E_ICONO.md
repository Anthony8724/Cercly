# Google Play 1 — icono y eliminación de cuentas

Fecha: 25 de octubre de 2026. Rama local `fix/auth-perfiles-automaticos`.
**Implementación local preparada para revisión. Sin despliegue. Producción: NO-GO.**

| Componente | Estado local | Estado en producción |
|---|---|---|
| Icono Android y splash | Recursos generados y APK debug instalado en emulador | No publicado; falta aprobación visual del logo maestro |
| Pantallas de eliminación | Ruta, confirmación y estados implementados y probados con dobles | No operativas hasta desplegar migraciones y Edge Function |
| Solicitud y borrado de Auth | Migración y Edge Function preparadas; pruebas SQL y de lógica aislada | No desplegados; no se ha efectuado ningún borrado real |
| Solicitud web externa | Página y flujo OTP preparados en archivos locales | Sin URL ni configuración pública; no funcional ni declarado en Play Console |

Ninguna prueba local constituye autorización de despliegue. Las tres migraciones
de autenticación anteriores y esta cuarta continúan pendientes de aplicación.

## Icono Android

La fuente visual es `_LogoCerclyPainter` en
`lib/features/explorar/widgets/cabecera_explorar.dart`: el pin blanco, la órbita
celeste y el círculo azul que aparecen en la cabecera de Explorar. El recurso
`assets/branding/cercly_launcher.svg` transcribe sus coordenadas normalizadas
sin cambiar proporciones. El fondo azul oscuro se toma de la paleta de cabecera.
El símbolo ocupa aproximadamente el 60 % central del lienzo cuadrado y conserva
margen para la máscara del icono adaptativo.

El repositorio actual no tenía un archivo de logo fuente de alta resolución.
Los iconos web/iOS existentes todavía muestran el emblema predeterminado de
Flutter. En Git histórico hay un PNG llamado logo oficial que no se decodifica y
un WebP de 180×58 px con transparencia, insuficiente para launcher. Por ello se
usó el logo vectorial ya dibujado en la aplicación; no se extrajo de capturas ni
se amplió el WebP. Si el responsable de marca entrega un SVG/PNG maestro distinto,
debe comparar y aprobarlo antes de publicar.

Android usa `mipmap-anydpi-v26/ic_launcher.xml` con fondo y primer plano
vectorial; los cinco PNG legacy se rasterizaron a 48, 72, 96, 144 y 192 px desde
el SVG a 1024 px. Ambos `launch_background.xml` muestran el mismo símbolo.
La compilación debug y el launcher de Pixel 7 confirmaron que se ve centrado,
sin recorte ni deformación. La captura local está en
`/tmp/cercly-play1-launcher.png`. Este control no valida todos los launchers
ni sustituye aprobación de marca.

## Eliminación en la aplicación

Ruta: **Mi cuenta / panel → Configuración → Cuenta → Eliminar mi cuenta**.
La pantalla explica pérdida de acceso y revisión de datos compartidos. Un diálogo
exige confirmación explícita; cancelar no llama al backend. Muestra carga,
estado de revisión, fallo de red y fallo parcial. Tras respuesta `eliminada`,
la app limpia el historial local de avisos, cancela las notificaciones y cierra
la sesión. Tras `revision`
informa que la identidad sigue activa. Un fallo de conexión nunca se muestra
como borrado confirmado.

La nueva migración, después de las tres de Auth pendientes, crea una cola mínima
en un esquema no expuesto. `solicitar_eliminacion_cuenta()` no acepta un ID: usa
`auth.uid()`, confirma que el usuario aún existe y, con la migración de política
posterior, comprueba la creación de la sesión en `auth.sessions` (máximo cinco
minutos). Un reingreso con email/contraseña u OAuth debe crear una sesión nueva;
esto requiere validación real en staging. La petición
repetida conserva una sola fila. Solo la Edge Function `eliminar-cuenta` tiene
credencial de servidor; valida el token mediante Auth y llama a
`auth.admin.deleteUser(id, false)` exclusivamente con el ID verificado.
La clave privilegiada no está en Flutter ni en la página pública.

La eliminación automática se limita a cuentas sin establecimiento propio,
solicitud enviada ni objeto Storage atribuible. Las membresías de colaboradores
se eliminan por FK al borrar el perfil, conservando el negocio compartido.
`verificado_por` y `revisado_por` se ponen en NULL por FK; el perfil cae por
cascada al borrar Auth. Se comprueban objetos Storage en todos los buckets por
`owner_id` y las rutas de los dos buckets de imágenes de Cercly. Si una relación
aparece entre la comprobación y `deleteUser`, el borrado puede fallar y la cola
queda pendiente para reintento. La función no cambia roles ajenos ni transfiere
negocios. La RPC `finalizar_eliminacion_cuenta()` solo puede usarla `service_role`
después de borrar Auth; limpia la fila mínima de la cola.

Un corte tras borrar Auth puede dejar la fila de cola pendiente. En ese caso la
identidad ya no existe, el cliente cierra sesión si recibió `eliminada`, y un
operador debe reconciliar la cola con Auth. Si el cliente perdió la respuesta,
no se afirma éxito. Los JWT ya emitidos siguen válidos hasta expirar según el
modelo de Supabase; antes del despliegue hay que revisar vencimiento y controles
de operaciones sensibles. La eliminación del perfil por sí sola nunca cuenta
como eliminación de la identidad.

## Solicitud fuera de la aplicación

`web/eliminar-cuenta.html` prepara un camino público: correo → código de un solo
uso o Google OAuth → sesión Auth verificada → misma función de eliminación. El formulario no
recibe IDs de cuenta. `web/account-deletion-config.js` está intencionalmente
vacío: **la página todavía no es un recurso público funcional ni debe
registrarse en Play Console**. Antes de publicarla se necesitan dominio/URL,
clave publicable, plantilla Auth con código OTP, verificación del flujo para
cuentas Google y CAPTCHA Turnstile activado en Auth. No se ha definido correo de soporte;
no se inventó uno. La URL final debe cargarse sin error, permitir solicitar
eliminación sin reinstalar la app y declararse en Data safety de Play Console.

## Decisiones de producto y retención pendientes

La política aprobada y el plan de staging se detallan en
`docs/GOOGLE_PLAY_ELIMINACION_STAGING.md`; esa guía prevalece sobre las notas
de diseño anteriores de este documento.

| Datos o caso | Tratamiento local preparado | Decisión pendiente antes de GO |
|---|---|---|
| Propietario de cualquier negocio | Revisión, sin borrar negocio, promociones ni fotos | Transferencia consentida, desactivación o gestión administrativa; responsable y plazo |
| Administrador | Revisión, sin alterar otros roles | Sucesión de funciones y doble control |
| Solicitudes, mensajes y evidencias | Revisión, no se borran automáticamente | Qué conservar, anonimizar o eliminar y por cuánto tiempo |
| Storage aportado por usuario a negocio compartido | Revisión, no se eliminan imágenes compartidas | Transferir, sustituir o eliminar; comprobar objetos huérfanos |
| Cola en revisión | UUID y fechas en esquema privado, sin correo | Plazo de atención, retención y purga de casos no completados |
| Logs, backups, analítica y notificaciones del dispositivo | Se limpia historial local y se cancelan avisos; no se purgan copias del servidor | Inventario, base legal, período y texto público de retención |
| Cuenta eliminada | Auth, perfil y membresías desaparecen; fila de cola se limpia | Confirmar JWT expiración y verificación de sesión en operaciones sensibles |

Google Play exige una ruta visible dentro de la app y un recurso web funcional,
así como la eliminación de datos asociados o una explicación clara de cualquier
retención legítima. Referencia:
[Play Console — account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
Supabase documenta que Storage puede bloquear el borrado Auth y que un JWT
existente no se invalida retroactivamente:
[Supabase User Management](https://supabase.com/docs/guides/auth/managing-user-data).

## Verificaciones y bloqueos

Los casos SQL usan solo identidades sintéticas en un contenedor local aislado.
La suite nueva incluye 22 aserciones sobre permisos, identidad propia,
idempotencia, revisión y cascadas de Auth, perfil y membresía.
Las pruebas Flutter usan servicios simulados. La función Edge tiene pruebas de
orden y fallo parcial con dobles, pero todavía no se ejecutó con GoTrue,
PostgREST, Storage ni OTP reales. No se aplicó la migración remotamente.
Resultados locales: SQL **238/238 por versión** en PostgreSQL 17.6 y 17.11,
incluidos 22/22 de eliminación; cuatro migraciones reaplicadas y rollback bajo
contención aprobado. Flutter **153 aprobadas, ocho omitidas** porque requieren
endpoint HTTP; `flutter analyze` sin incidencias. El flujo Edge aislado pasó
5/5 pruebas. El APK debug final compiló y se instaló en Pixel 7:
SHA-256 `93a7b851aa5d57b0a8adf79bd77bdbf574d309f5db2a0fd5e6d24029f7416e69`.
No se probaron borrados reales ni Google OAuth en este bloque.
Las tres migraciones previas siguen pendientes y son requisito de esta cuarta.
Se mantiene **NO-GO** para producción y Google Play hasta decidir retención,
resolver la restauración de ACL, desplegar y probar en staging con cuentas
sintéticas, publicar/verificar el enlace externo y autorizar por separado.
