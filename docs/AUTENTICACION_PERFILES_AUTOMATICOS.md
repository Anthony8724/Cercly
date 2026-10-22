# Cercly: autenticación y perfiles automáticos

Fecha: 21 de octubre de 2026, America/Guayaquil. Rama de revisión: `fix/auth-perfiles-automaticos`, creada desde `develop`. Implementación local revisada para un commit autorizado posteriormente por el usuario; sin push.

**Resultado:** implementación y pruebas locales completas. La recuperación automática de perfiles ausentes en producción depende del despliegue autorizado de las migraciones. No se modificó producción, su configuración OAuth ni el respaldo local. No se crearon usuarios reales o de prueba en producción.

## 1. Estado inicial comprobado

Se revisaron estructura, instrucciones de contribución, servicios y pantallas de autenticación, modelo de usuario, navegación por rol, manifiesto Android, configuración pública, migraciones, RLS, pruebas y documentación previa. No se encontraron archivos `AGENTS.md` aplicables. El único archivo inicialmente sin seguimiento era `README.md.respaldo`; se conservó intacto.

Una consulta remota de catálogos y conteos, dentro de `BEGIN READ ONLY`, confirmó **12 cuentas, 12 perfiles y cero cuentas sin perfil**. El trigger `crear_perfil_despues_del_registro` estaba habilitado como `AFTER INSERT` en `auth.users`. Su función de producción fija el rol `usuario`, usa `nombre` o el prefijo del correo y tiene `search_path` vacío.

El acceso Google en Pixel 7 fue comprobado previamente por el usuario. En esta tarea se inspeccionó el código y se probaron contratos simulados; no se repitió el consentimiento Google con una cuenta real. Se conservaron PKCE, navegador externo, deep link `com.cercly.cercly://auth-callback/`, banderas y configuración OAuth.

Las dos migraciones de seguridad de octubre seguían pendientes según el contexto y la definición remota observada. Sus contenidos no cambiaron. La información actual **no demuestra la causa histórica del perfil ausente**: no se atribuye el incidente a Google ni al trigger sin evidencia.

## 2. Problemas detectados

- `AuthGate` utilizaba `.single()` y convertía ausencia, red y permisos en el mismo mensaje de error; no había recuperación automática.
- Un rol nulo/desconocido podía tratarse como usuario básico en la navegación. Ahora la carga de perfil exige uno de los tres roles válidos y bloquea los perfiles inconsistentes.
- Las cargas carecían de un límite explícito en la interfaz.
- El bloqueo de Google terminaba al abrir el navegador, permitiendo otro intento mientras el primero seguía pendiente.
- El stream del SDK conserva el último evento o error. Resuscribirse sin renovar la sesión podía repetir el mismo fallo.
- Errores del cierre de sesión podían quedar sin capturar. El SDK elimina primero la sesión local; un fallo de red posterior no acredita revocación remota.
- El trigger de producción no tiene el tratamiento de nombres Google ni la tolerancia a conflictos de la primera migración pendiente. Esta última ya preparaba parte de la solución, pero no recuperaba perfiles antiguos ausentes.
- La función remota de protección de roles solo contemplaba la autopromoción a administrador; el endurecimiento adicional permanece en las migraciones pendientes. Esta tarea no elimina esa limitación de producción sin desplegarlas.

## 3. Archivos modificados o nuevos

| Archivo | Cambio |
|---|---|
| `lib/features/auth/services/profile_service.dart` | Nuevo servicio: consulta propia bajo RLS, recuperación y validación estricta |
| `lib/features/auth/services/auth_service.dart` | Mensajes tipados, tiempos de espera y renovación explícita de sesión |
| `lib/features/auth/screens/auth_gate.dart` | Suscripción estable, estados de sesión/perfil, errores, reintentos, aislamiento de identidad |
| `lib/features/auth/screens/auth_recovery_host.dart` | Aviso de sesión vencida y limpieza de avisos |
| `lib/features/auth/screens/login_screen.dart` | Bloqueo OAuth mientras está pendiente, cancelación, vencimiento y navegación única |
| `lib/features/auth/screens/register_screen.dart` | Clasificación de fallos de registro |
| `lib/features/auth/screens/mi_cuenta_screen.dart` | Captura de errores al cerrar sesión |
| `lib/features/administracion/screens/panel_administrador_screen.dart` | Captura de errores al cerrar sesión |
| `lib/features/establecimientos/screens/panel_establecimiento_screen.dart` | Captura de errores al cerrar sesión |
| `pubspec.yaml`, `pubspec.lock` | `http 1.6.0` pasa de dependencia de pruebas a directa para clasificar errores de transporte; sin actualización de versiones |
| `supabase/migrations/20261022033531_recuperar_perfil_autenticado.sql` | Nueva migración local generada mediante Supabase CLI; nombre en UTC |
| `supabase/tests/profile_recovery_test.sql` | 24 aserciones nuevas de trigger, recuperación y autorización |
| `scripts/test_supabase_security_local.py` | Ocho recuperaciones concurrentes y opción de PostgreSQL 17.6 |
| `test/profile_service_test.dart` | Contrato HTTP simulado, perfiles, identidad, persistencia, vencimiento, logout y renovación |
| `test/auth_roles_test.dart` | Roles inválidos, cargas lentas, errores de sesión y respuestas tardías |
| `test/auth_oauth_test.dart` | Cancelación, denegación, duplicados, callback, vencimiento y sesión expirada |
| `test/auth_password_test.dart` | El fallo de conectividad usa una excepción real de transporte |
| `docs/AUTENTICACION_PERFILES_AUTOMATICOS.md`, `docs/README.md` | Informe e índice |

## 4. Flujo implementado

1. Google abre el navegador con la configuración existente. Abrirlo no equivale a autenticarse.
2. El SDK recibe y valida la sesión. Solo un evento `signedIn` con sesión completa la navegación OAuth; eventos repetidos no causan múltiples salidas.
3. `AuthGate` carga exclusivamente el perfil de la identidad actual.
4. Si existe, usa su rol válido y no invoca ninguna escritura.
5. Si la consulta devuelve ausencia, invoca una vez `recuperar_mi_perfil()` sin parámetros.
6. La función crea, si hace falta, el perfil básico para `auth.uid()`. Una clave primaria y `ON CONFLICT (id) DO NOTHING` evitan duplicados y preservan perfiles concurrentes.
7. La respuesta vuelve a pasar por RLS y la app comprueba identidad y rol antes de mostrar cuenta, negocio o administración.

El registro por correo y las altas OAuth comparten el trigger transaccional. Si falla la creación, se revierte también el alta Auth; no se oculta el error dejando una cuenta nueva sin perfil. El nombre descriptivo admite `nombre`, `full_name`, `name`, correo y un valor genérico. Se recorta a 80 caracteres y nunca se extrae autorización de metadatos.

## 5. Seguridad y límites de la recuperación

La inserción privilegiada está en un esquema privado no expuesto por la configuración del proyecto. El helper con parámetros no es ejecutable por `anon` ni `authenticated`. La función de recuperación privilegiada no recibe identidad, nombre ni rol: obtiene `auth.uid()`, comprueba que exista en Auth y solo permite insertar el perfil básico.

La RPC pública usa `SECURITY INVOKER`; su lectura final respeta RLS y filtra la identidad propia, incluso para administradores. No se añadieron políticas permisivas de INSERT/UPDATE. La nueva migración rechaza ejecutarse si detecta los permisos de perfil sin endurecer. Las funciones tienen `search_path` vacío y permisos explícitos.

La elevación `SECURITY DEFINER` se limita al trigger y a la recuperación interna necesaria para insertar sin conceder INSERT al cliente. Se sigue el patrón de separación de datos Auth/perfil y funciones de base de datos descrito por [Supabase](https://supabase.com/docs/guides/auth/managing-user-data) y su [guía de funciones](https://supabase.com/docs/guides/database/functions).

No se usan claves `service_role` en Flutter. Los mensajes nuevos de log del backend contienen solo operación y SQLSTATE; no incluyen SQLERRM, correo, identidad ni metadatos. La app tampoco muestra detalles crudos de excepciones.

Si falta el perfil de una persona que antes tenía privilegios, se recupera como `usuario`: restaurar privilegios exige una revisión administrativa. Si existe un perfil inconsistente, no se sobrescribe ni se corrige el rol automáticamente.

## 6. Estados y experiencia de usuario

| Situación | Comportamiento |
|---|---|
| Sesión inicial sin respuesta | Mensaje de comprobación; límite de 15 segundos |
| Perfil cargando | Mensaje específico; límite total de 15 segundos y 7 por solicitud de datos |
| Perfil válido | Destino según rol obtenido del backend |
| Perfil ausente | Una recuperación automática por carga, sin bucles |
| Recuperación no desplegada o fallida | Mensaje claro, reintento manual y cierre de sesión |
| Perfil inconsistente | Acceso bloqueado con indicación de revisión |
| Red lenta o fallida | Mensaje de conexión; no se interpreta como ausencia de perfil |
| Error del stream de sesión | Reintento explícito que renueva el token; sesión inexistente vuelve a acceso público |
| Google pendiente | Otros métodos bloqueados; cancelación manual y límite de 2 minutos |
| Apertura de navegador sin respuesta | Límite de 15 segundos |
| Correo/contraseña o registro sin respuesta | Límite de 30 segundos |
| Logout | Eliminación local gestionada por SDK; captura de error y límite de 15 segundos |

Cancelar el intento libera la interfaz; no puede cerrar ni revocar el consentimiento en un navegador externo. Si después llega una sesión válida del SDK, la aplicación la acepta. No se muestra una cancelación como fallo de credenciales.

Los reintentos automáticos de PostgREST se deshabilitan solo en las solicitudes de perfil. Un resultado tardío de otra identidad no abre su panel. RLS sigue siendo la autoridad aunque un rol administrativo cambie durante una sesión abierta.

## 7. Pruebas ejecutadas

| Verificación | Resultado |
|---|---|
| `flutter pub get` | Correcto; versiones existentes conservadas |
| `flutter analyze --no-pub` | Sin incidencias |
| `flutter test --reporter expanded` | **140 correctas, 8 omitidas**, sin fallos |
| `flutter build apk --debug` | APK generado; comprobación de compilación sin configuración ni instalación en emulador |
| SQL en Supabase PostgreSQL 17.11 | **194/194** aserciones, nueve suites |
| SQL en Supabase PostgreSQL 17.6 | **194/194** aserciones, nueve suites |
| Ocho transacciones de recuperación simultáneas, en ambas versiones | **8/8**; un único perfil `usuario` |
| Reaplicación de migraciones pendientes y nueva, dos veces | Perfiles sintéticos existentes idénticos antes y después |
| `git diff --check` | Correcto |

Las suites SQL también cubren las funcionalidades existentes de solicitudes, aprobación, colaboradores, establecimientos, promociones, almacenamiento, OSM y PostGIS. Usan contenedores nuevos sin red, imágenes locales fijadas, fixtures sintéticos y rollback. No usan `cercly-restore-supabase`, `cercly_verificacion` ni el dump existente.

Evidencias temporales de esta ejecución:

- Flutter: `/tmp/cercly-auth-final-tests.log`.
- SQL PostgreSQL 17.11: `/tmp/cercly-security-results-g_3q1nx7/`.
- SQL PostgreSQL 17.6: `/tmp/cercly-security-results-p67hg3ph/`.

Reproducción local:

```bash
flutter pub get
flutter analyze
flutter test
python3 scripts/test_supabase_security_local.py
python3 scripts/test_supabase_security_local.py --postgres-17-6
flutter build apk --debug
git diff --check
```

Las imágenes deben existir localmente; el script usa `--pull=never`. No acepta una URL remota. Solo detiene el contenedor que crea en esa ejecución.

## 8. Aspectos no verificados

- Consentimiento real de Google, retorno Android con aplicación abierta/cerrada y persistencia tras matar/reabrir el proceso con esta versión. La persistencia se comprobó mediante serialización/restauración del SDK con transporte simulado, no mediante almacenamiento real del dispositivo.
- SMTP, entrega de confirmaciones, SMS y proveedores Microsoft/Facebook.
- GoTrue y PostgREST completos mediante HTTP en staging: los contratos Dart están simulados y la integración SQL usa roles/JWT claims locales de prueba, no JWT firmados por GoTrue.
- Ocho pruebas HTTP existentes de establecimientos/promociones se omiten sin endpoint configurado. No se conectaron a producción para convertirlas artificialmente en pruebas locales.
- Causa histórica del perfil faltante y momento en que desapareció.
- Revocación remota de sesiones sin conectividad. Borrar la sesión local no invalida por sí solo un JWT ya emitido.
- Revalidación del contenido/restauración del respaldo: se respeta el respaldo probado indicado por el usuario sin abrirlo ni alterarlo.

## 9. Operaciones pendientes de autorización y producción

No hay despliegue remoto autorizado. Revisar primero el cambio local y preparar un ensayo con Auth/PostgREST reales en staging y cuentas sintéticas. Después, solicitar autorización explícita para aplicar, en este orden:

1. `20261017233138_fortalecer_acceso_perfiles.sql`.
2. `20261018000337_validar_seguridad_acceso.sql`.
3. `20261022033531_recuperar_perfil_autenticado.sql`.

Las dos primeras conservan sus SHA-256 originales:

```text
0e196d9b71f6c4e2414341ae3b66cd9dee85c9a56000556c2e5844fd3ecb3442
833a9719ff2cc4aa8c09defc2676aa6fda59172247219df0eb17ea9926e912dc
```

Antes del despliegue: revisar respaldo restaurable y su vigencia, confirmar catálogo/permisos actuales y probar cuentas nuevas/existentes, recuperación, roles, cancelación y reapertura en staging. Mantener el esquema privado fuera de los esquemas expuestos de la Data API. No alterar el callback Google funcional.

Después del despliegue autorizado: comprobar trigger habilitado, permisos de la RPC, ausencia de huérfanos y conservación de perfiles/roles; revisar errores de creación/recuperación sin extraer datos personales. Distribuir la app tras el ensayo. Si se distribuye antes, los perfiles existentes siguen consultándose y los ausentes reciben un mensaje recuperable hasta que la RPC esté disponible.

No hacer backfill masivo ni revertir controles de seguridad para corregir una incidencia. Ante una regresión, detener la distribución, conservar datos y preparar una corrección revisada. El commit local de esta fase fue autorizado posteriormente por el usuario; el push y el despliegue remoto siguen fuera del alcance.

Los informes antiguos describen el estado de sus fechas. La disponibilidad Google y el respaldo probado comunicados por el usuario actualizan ese contexto; las limitaciones de HTTP/staging siguen pendientes.

## 10. Microsoft, Facebook y teléfono

- **Microsoft:** registrar y configurar la aplicación Entra y su audiencia/tenant, conservar el scope `email` ya solicitado por Cercly, custodiar el secret en Supabase y probar retorno y perfiles con cuentas permitidas. [Guía oficial](https://supabase.com/docs/guides/auth/social-login/auth-azure).
- **Facebook:** configurar app, callback y permisos `public_profile`/`email`; comprobar acceso con usuarios de prueba y los requisitos para publicación antes de habilitarlo al público. [Guía oficial](https://supabase.com/docs/guides/auth/social-login/auth-facebook).
- **Teléfono:** configurar proveedor SMS, límites y CAPTCHA cuando corresponda; probar OTP, vencimiento y reenvío con autorización para cualquier envío de pago. La protección real debe estar en el servidor. [Guía oficial](https://supabase.com/docs/guides/auth/phone-login).

Los tres métodos reutilizan el trigger y la recuperación del perfil; ninguno debe conceder roles desde metadatos. Habilitar cada bandera únicamente después de validar su backend. Se revisó el changelog de Supabase: la retirada anunciada de cifrados TLS antiguos no requiere modificar este flujo; queda fuera de esta prueba la compatibilidad con dispositivos obsoletos. [Aviso oficial](https://supabase.com/changelog/cbc-tls-ciphers-deprecated).
