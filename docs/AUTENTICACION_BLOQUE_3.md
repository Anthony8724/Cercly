# Bloque 3 — Autenticación y control de acceso

Trabajo en `develop`. No se aplicaron migraciones remotas, no se cambiaron credenciales ni se enviaron SMS. `README.md.respaldo` se conserva fuera de este bloque.

## Decisiones y auditoría

- `resolverDestinoCuenta` utiliza exclusivamente `usuarios.rol`. `tipo_cuenta` es intención de registro, nunca autorización. Un rol desconocido obtiene navegación de usuario; un error de consulta bloquea el panel y ofrece reintento.
- El rol se vuelve a consultar al cambiar la identidad o el objeto de usuario; nunca se conserva el panel de otra identidad. RLS sigue siendo la autoridad sobre los datos, incluso si una sesión abierta conserva una pantalla después de un cambio administrativo de rol.
- El registro tradicional y la exploración pública se mantienen. «Mis solicitudes de negocios» es accesible desde «Mi cuenta» para iniciar el flujo de aprobación sin privilegios comerciales.
- `UsuarioModel.toSupabaseParaActualizar()` solo envía `nombre`. No se cambió el modelo. Se mantienen las autorizaciones administrativas y las membresías comerciales existentes.
- La migración base protegía únicamente la autopromoción a administrador y promovía a propietario al insertar un establecimiento pendiente. La nueva migración limita permisos de escritura del perfil a `nombre`, protege identidad/rol y difiere la promoción automática hasta la aprobación del establecimiento. Las solicitudes aprobadas siguen usando el RPC existente.
- La migración posterior `20260913010000_modelo_osm_postgis.sql` ya protege las modificaciones de colaboradores sobre estado, propietario, procedencia OSM, publicación y reclamo. Se conserva esa función completa, sin reemplazarla por la versión anterior.
- Los permisos RLS de establecimientos, promociones, horarios y almacenamiento dependen de propietario/membresía/autorización administrativa, no de metadatos. Los borradores pendientes conservan el flujo existente. El administrador se comprueba contra `usuarios` mediante `es_administrador()`.
- El trigger `crear_perfil_nuevo_usuario` crea perfiles para correo, OAuth y SMS con rol `usuario`. Admite `nombre`, `full_name`, `name` y un nombre genérico para teléfono sin email. No sobrescribe perfiles existentes ni sincroniza roles desde el cliente. No hay backfill masivo; un perfil antiguo ausente requiere reparación administrativa individual.
- Se conserva `supabase_flutter 2.17.2` y el flujo PKCE predeterminado. Se verificaron sus firmas contra el código instalado. `http 1.6.0`, ya presente transitivamente, se declara como dependencia de pruebas para simular transporte.
- Proveedores opcionales deshabilitados por defecto con controles visibles «No disponible». Una bandera habilita la UI, pero no configura el proveedor externo ni garantiza su funcionamiento.
- OTP: sintaxis E.164 de 8–15 dígitos, prefijo editable (ejemplo Ecuador), código SMS de 6 dígitos, espera de 60 segundos entre solicitudes y mensajes de límites. El temporizador usa una fecha límite; el servidor debe aplicar los límites reales, también si el usuario cierra y vuelve a abrir la pantalla. No se persisten ni se registran códigos; solo viven temporalmente en memoria para la verificación.
- Inicio OAuth solo abre el navegador. La navegación espera `signedIn` con sesión. Cancelar permite reintentar; errores se muestran sin detalles privados. `passwordRecovery` abre el formulario de nueva contraseña, también al retornar a la aplicación.
- Formatos de correo compartidos, controles de mostrar contraseña con etiqueta accesible, avisos con región viva y formularios desplazables. Se limita el formato Dart a archivos modificados porque el chequeo global detectó diferencias ajenas.

## Estado externo observado

Consulta de solo lectura a `/auth/v1/settings` el 17 de octubre de 2026 con `scripts/check_auth_settings.py`:

| Método | Configuración observada | Alcance validado |
| --- | --- | --- |
| Correo/contraseña | Habilitado | Flujos existentes conservados y probados con transporte/UI simulados; no se realizó login real |
| Google | Deshabilitado | Integración preparada, pendiente de configuración y prueba real |
| Microsoft/Azure | Deshabilitado | Integración preparada, pendiente de configuración y prueba real |
| Facebook | Deshabilitado | Integración preparada, pendiente de configuración y prueba real |
| Teléfono/SMS | Deshabilitado | Solicitud/verificación simuladas; pendiente de proveedor SMS y entrega real |

La lectura de settings no comprueba la validez de secretos, consentimiento, entrega de correo/SMS o redirecciones completas. Ningún proveedor nuevo se declara operativo.

## Activación externa pendiente

1. Revisar la migración `20261017233138_fortalecer_acceso_perfiles.sql` y ejecutar las pruebas SQL en una instancia local de Supabase antes de solicitar su aplicación remota. Es transaccional, repetible, no elimina usuarios ni altera roles existentes en lote. No se ejecutó aquí: no hay PostgreSQL/Docker disponibles. Ejecutar además las pruebas existentes de reclamación OSM y aprobación administrativa.
2. En Supabase Auth URL Configuration, conservar el Site URL real y autorizar exactamente `com.cercly.cercly://auth-callback/`, la URL raíz Web publicada (con barra final) y las URLs de desarrollo necesarias. Para local se preparó `http://localhost:3000/`; ejecutar Flutter Web con puerto fijo 3000. Si se publica bajo un subdirectorio, autorizar su URL y configurar el base href del build.
3. En los proveedores externos usar el callback de **Supabase**, `https://<project-ref>.supabase.co/auth/v1/callback`, no el deep link Android. Supabase redirige después a Cercly. Android entrega el enlace al SDK mediante `app_links`; el manejador predeterminado de Flutter está desactivado para evitar conflictos. Web utiliza la URL actual sin query ni fragmento.
4. Google: crear cliente OAuth Web, configurar consentimiento/audiencia y callback; colocar Client ID y secret exclusivamente en Supabase. No se limita el dominio a Gmail, por lo que admite otras cuentas Google. Validar cuentas de prueba y condiciones de publicación antes de habilitarlo para todos. [Guía oficial](https://supabase.com/docs/guides/auth/social-login/auth-google).
5. Microsoft: registrar aplicación en Entra con cuentas personales y organizaciones según el alcance deseado; elegir un tenant compatible (`common` para ambos, `consumers` si solo personales). Configurar callback, Client ID y valor del secret en Supabase. Cercly solicita `email`; revisar claims `email`/`xms_edov` y caducidad del secret. [Guía oficial](https://supabase.com/docs/guides/auth/social-login/auth-azure).
6. Facebook: crear aplicación con Facebook Login, registrar callback, App ID/secret en Supabase y configurar dominio, política de privacidad, eliminación de datos y disponibilidad de la app según los requisitos de Meta. Validar el acceso a email con cuentas admitidas. [Guía oficial](https://supabase.com/docs/guides/auth/social-login/auth-facebook).
7. SMS: habilitar Phone Auth y un proveedor soportado con credenciales solo en Supabase. Configurar remitente, países de destino, facturación, límites y plantilla/código de 6 dígitos; probar un único envío controlado y autorizado. El límite del cliente es UX, no protección contra abuso. Si se exige CAPTCHA, integrar su obtención antes de habilitar la bandera (este bloque no incluye widget CAPTCHA). [Guía oficial](https://supabase.com/docs/guides/auth/phone-login).
8. Correo/recuperación: comprobar SMTP, confirmación de correo y plantilla con enlace de confirmación que preserve `redirect_to`; verificar actualización de contraseña desde un enlace real en Android y Web.
9. Tras configurar cada método, agregar únicamente su bandera pública al archivo local ignorado y recompilar: `AUTH_GOOGLE_ENABLED`, `AUTH_MICROSOFT_ENABLED`, `AUTH_FACEBOOK_ENABLED`, `AUTH_PHONE_ENABLED`, con valor `true`. Las banderas no son secretos. No agregar client secrets, service-role ni tokens privados al JSON de Flutter.
10. Validar regreso OAuth en Android con app abierta/cerrada y en Chrome, cancelación, denegación de consentimiento, perfil `usuarios`, cierre/reapertura de sesión y rol aprobado. Validar también solicitudes/aprobaciones comerciales contra RLS en staging. No promover usuarios por su email, teléfono o metadatos.

## Validación reproducible

```bash
flutter pub get
flutter analyze
flutter test
flutter test --platform chrome test/auth_ui_test.dart test/auth_roles_test.dart test/auth_oauth_test.dart test/auth_phone_test.dart test/auth_password_test.dart test/auth_service_test.dart test/widget_test.dart
git diff --check
flutter build apk --debug --dart-define-from-file=config/supabase.local.json
flutter build web --dart-define-from-file=config/supabase.local.json
```

No ejecutar `dart format .` con escritura: hay formato pendiente ajeno al bloque. Formatear solo los archivos enumerados por el diff.

Las pruebas automatizadas cubren contratos HTTP de correo/OTP, selección de proveedor y scopes, disponibilidad, errores/carga/reintentos, roles, metadatos maliciosos, cambio de identidad, pantallas pequeñas y escritorio, recuperación y espera/reenvío SMS. El archivo SQL `supabase/tests/auth_access_test.sql` añade 11 aserciones de perfil, privilegios y RLS, dentro de una transacción con rollback; queda pendiente de ejecución en Supabase local.

Se revisó el [changelog TLS de Supabase](https://supabase.com/changelog/cbc-tls-ciphers-deprecated). No requiere cambiar las APIs de Auth utilizadas; no se certificó compatibilidad con sistemas operativos antiguos afectados por esa retirada.
