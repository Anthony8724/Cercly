# Eliminación de cuentas: política local y preparación de staging

Estado: **local; producción NO-GO**. No se ha desplegado la migración, la Edge
Function ni la página. Usar solo identidades y negocios sintéticos.

## Política implementada

| Caso | Resultado |
|---|---|
| Usuario sin dependencias | Solicitud propia idempotente; comprobación reciente de sesión; Auth se borra mediante la función servidor; perfil y membresías caen por FK. El negocio compartido permanece. |
| Propietario sin establecimientos ni otras dependencias | Mismo flujo, con comprobación de solicitudes, Storage y claves foráneas. |
| Propietario con establecimiento | `revision`; un administrador distinto puede desactivarlo, o transferirlo a un miembro activo con rol de administrador del establecimiento y rol de propietario o administrador en Cercly. Desactivar conserva la propiedad y no habilita el borrado. Transferir conserva el negocio, fotos y promociones. |
| Administrador | `revision`; otro administrador con sesión reciente debe aprobar; la Edge Function revalida que no sea el último. Un trigger de Auth protege el último administrador también frente a borrados directos y concurrentes. |

Las acciones administrativas se ejecutan mediante
`public.revisar_eliminacion_cuenta(usuario_id, accion, establecimiento_id, destino_id)`;
la cola mínima se consulta mediante `public.listar_solicitudes_eliminacion()`
solo con sesión administrativa reciente. El resultado contiene UUID, estado y
fecha, sin correo ni nombre.
`accion` admite `transferir`, `desactivar` y `aprobar`. El actor debe tener rol
administrador en `public.usuarios`, sesión Auth de menos de cinco minutos y no
ser el titular. Los intentos sin autorización fallan; las acciones efectivas se
registran en `cercly_account_private.auditoria_eliminacion` con UUID y acción,
sin nombres, correos, mensajes ni motivos libres. La aprobación requiere que no
queden relaciones bloqueantes ni objetos Storage atribuibles. Los cambios de
propiedad, estado o visibilidad y el borrado directo de un establecimiento con
solicitud activa se bloquean fuera de la RPC auditada. Solo el titular
puede finalizar: debe volver a autenticarse y llamar a `eliminar-cuenta`.

La cola conserva `pendiente`, `revision` y `aprobada`. Una repetición no duplica
la fila ni revoca una aprobación. Antes de borrar Auth, el servidor vuelve a
comprobar estado, perfil, dependencias y número de administradores. Una FK nueva
hacia Auth o perfiles, de cualquier acción `ON DELETE`, bloquea conservadoramente
el borrado hasta incorporar su tratamiento. Si Auth falla, la solicitud permanece;
si falla la limpieza de la cola tras borrar Auth, se informa `registro_pendiente`
para reconciliación operativa. No se borran objetos Storage por SQL: la revisión
debe determinar cuáles son personales y retirarlos por la API Storage, sin
eliminar archivos referenciados por establecimientos compartidos.

Auth elimina los refresh tokens al borrar la identidad; los JWT existentes
pueden funcionar hasta su vencimiento. La aplicación y la página cierran la
sesión local después de una respuesta confirmada. Configurar la caducidad de
JWT y comprobar `session_id` en operaciones sensibles antes de habilitar el
flujo. La comprobación de sesión reciente usa `auth.sessions.created_at`, no
`last_sign_in_at`, que puede pertenecer a otra sesión.

## Staging independiente

Preparar un proyecto Supabase separado, sin enlaces ni claves del proyecto de
producción. Inventariar y aprobar previamente región, coste y administrador del
proyecto. No copiar respaldos ni filas reales; crear cuentas `@cercly.test` o
direcciones de prueba controladas para recibir OTP. El entorno local aislado
permite verificar SQL y recorridos HTTP de Auth, PostgREST, Storage, Edge
Functions y Mailpit; no sustituye la validación en un proyecto alojado.

No se encontró `supabase/.temp/project-ref` ni `~/.supabase/access-token` en
este entorno. Por tanto, no hay evidencia local de un proyecto enlazado ni se
pudo inventariar la cuenta Supabase para confirmar si existe un proyecto
alojado independiente. Esto no demuestra que no exista. No se creó ni modificó
ningún recurso remoto.

Configuración necesaria para crear staging, guardada en gestor de secretos del
entorno y nunca en Git:

- `SUPABASE_URL` y clave publicable de **staging** para Flutter y la página.
- `SUPABASE_SERVICE_ROLE_KEY` solo como secreto de la Edge Function.
- Proveedor SMTP de prueba y plantilla Auth que incluya `{{ .Token }}` para OTP.
- Google OAuth de pruebas: cliente OAuth, secreto, pantalla de consentimiento,
  orígenes permitidos y redirect de Supabase y de la página de staging.
- Cloudflare Turnstile de staging: site key pública en
  `web/account-deletion-config.js` de la compilación staging y secret key solo
  en Auth CAPTCHA. Activar además límites de envío OTP de Supabase.
- URL HTTPS pública estable de la página y allowlist exacta de redirect Auth.
  No usar una URL temporal en Play Console. Configurar TLS, política de caché
  para el HTML y una política CSP compatible con Supabase, jsDelivr y Turnstile.
- Buckets de imágenes y políticas Storage de staging, con archivos sintéticos.

Orden previsto tras autorización de staging: crear proyecto; configurar Auth,
PostgREST, Storage, OTP, CAPTCHA y OAuth; aplicar migraciones en orden hasta
`20261026033929_politica_eliminacion_revision.sql`; desplegar
`eliminar-cuenta` con JWT obligatorio; configurar URLs/clave pública de la página;
ejecutar los casos de abajo; registrar resultados y logs sin tokens ni datos
personales. No reutilizar la base local restaurada para staging remoto.

## Matriz de validación en staging

1. Usuario normal y propietario sin dependencias: OTP/Google o ingreso reciente,
   solicitud, eliminación Auth, perfil, membresías y sesión; negocio compartido
   intacto.
2. Propietario con negocio activo: `revision`; transferencia autorizada conserva
   establecimiento, fotos y promociones; aprobación y nueva autenticación
   completan la eliminación del titular.
3. Desactivación: establecimiento deja de publicarse y promociones quedan
   inactivas; solicitud sigue en revisión mientras conserve la propiedad.
4. Administrador: otro administrador aprueba; último administrador, autoaprobación
   y eliminación de cuenta ajena quedan bloqueados.
5. Duplicados, ausencia de sesión, sesión antigua, JWT revocado, destino de
   transferencia no miembro, archivos Storage y FK nueva bloqueante.
6. Fallo simulado en Auth, fallo de limpieza de cola y corte de red: comprobar
   estado persistente, reintento y reconciliación sin afirmar borrado ambiguo.
7. Página: correo inexistente con mensaje neutral, OTP válido/inválido,
   CAPTCHA, límite de envíos, Google OAuth, regreso HTTPS, confirmación y
   errores de red en navegador real.

## Decisiones pendientes antes de publicar

- Asesoría jurídica/institucional: base legal, alcance, tiempos de conservación
  y acceso a auditoría, solicitudes, mensajes, evidencias y registros de soporte.
- Producto/operaciones: canal de notificación y soporte para solicitudes en
  revisión, quién autoriza la transferencia, prueba de aceptación del nuevo
  propietario y procedimiento de sucesión administrativa.
- Seguridad: revisar la facultad existente de administradores para cambiar
  establecimientos por otros flujos; si toda transferencia debe quedar en esta
  auditoría, restringir esos flujos antes de producción.
- Operaciones: responsable y mecanismo de reconciliación de solicitudes cuyo
  Auth se eliminó pero cuya cola no se limpió; monitoreo sin datos sensibles.
- Validar en staging la integración real Auth/PostgREST/Edge/Storage/OAuth;
  las pruebas locales no sustituyen esa validación.

## Resultados de validación aislada · Bloques 7 y 8

Entorno: Podman 5.8.7, Supabase CLI 2.119.0 (versión reportada por la CLI), backup local del proyecto
`cercly-b6-podman-isolated`, con 19 migraciones. Se excluyeron el panel,
Logflare, Vector, Postgres Meta, imgproxy y Supavisor; Auth, Postgres,
PostgREST, Storage, Kong, Edge Runtime y Mailpit sí estuvieron disponibles.
El stack se detuvo después de las pruebas conservando los volúmenes.

| Caso probado con identidad/datos sintéticos | Resultado observado |
|---|---|
| OTP recibido por Mailpit y verificado | OTP válido `200`; inválido y expirado `403`; sesión del titular comprobada |
| Cuenta sin dependencias | Edge `200 eliminada`; Auth `404`; perfil, solicitud y objetos en cero; sesión anterior rechazada |
| Propietario, archivo y negocio con responsable administrador | Solicitud duplicada devolvió `revision` con una sola fila; Edge `202`; el no administrador recibió `403`; transferencia y aprobación por administrador permitieron `200 eliminada`; negocio conservado bajo el nuevo titular |
| Miembro de negocio compartido | Edge `200 eliminada`; Auth eliminado y membresía retirada; negocio y responsable restantes conservados |
| Solicitud comercial pendiente | Edge `202 revision`; Auth y solicitud comercial permanecieron |
| Borrado de archivo | El dueño recibió `200` y la fila Storage quedó en cero; GET posterior devolvió `400`. Antes, otro usuario recibió `200` al intentar borrarlo, pero la fila y el archivo siguieron presentes |
| ID ajeno en el cuerpo de Edge | `400`; Auth de la cuenta objetivo permaneció |
| Fallo parcial | Cubierto por prueba unitaria de `completeDeletion`, no por inyección de fallo en el servicio HTTP |

Resultado adicional: seis suites pgTAP pasaron (111 aserciones); ocho casos
unitarios de `deletion_flow` pasaron; la prueba web existente y lint pasaron.
Se eliminaron las cuentas y fixtures sintéticos; la consulta final dio cero
usuarios, negocios, solicitudes, auditorías y objetos de prueba residuales.
La prueba de propietario compartido sí incluyó Auth, OTP/Mailpit, Postgres,
PostgREST, Edge Function y Storage; el fallo parcial sigue siendo simulado.

La integración fue local, no alojada. El endpoint público actual de Vercel
respondió `404` para `/privacidad`, `/eliminar-cuenta` y
`/api/eliminar-cuenta/configuracion`; esas páginas no están disponibles en el
dominio público consultado. El código exige
`ACCOUNT_DELETION_ENABLED=true` para habilitar el portal, pero no se pudo
consultar la configuración de entorno de Vercel. Al desplegar las páginas en
el futuro, confirmar explícitamente que esa variable esté ausente o sea
`false` hasta completar staging. El enlace alternativo mailto está presente en
el código, pero el correo por sí solo no valida la identidad ni automatiza el
borrado.

La página no debe publicarse ni declararse en Play Console hasta completar
estas decisiones, verificar la configuración remota y ejecutar la matriz de
staging alojado.
