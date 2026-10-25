# Cercly — auditoría final de autenticación

Fecha: 25 de octubre de 2026, America/Guayaquil.

**Revisión para commit local:** el usuario autorizó guardar los cambios en
`fix/auth-perfiles-automaticos`, manteniendo NO-GO. La sección 10 registra esta
verificación; las menciones anteriores a «sin commit» describen las fases previas.

**Continuación vigente:** causa de la RPC aislada en permisos de la restauración;
preflight reforzado sin GRANT sobre Auth; **216/216 SQL por versión**, 30 pruebas
Flutter afectadas y cuatro smoke Android aprobados con GPU `host`. Google real y
la restauración completa siguen pendientes: **NO-GO**. La sección 9 documenta esta
continuación; las secciones 1–8 conservan las evidencias de la primera fase.

**Resultado: correcciones locales verificadas; cierre completo y producción NO-GO.**
La copia restaurada conserva datos, pero no reproduce los propietarios y permisos
de la plataforma que necesita la aplicación. No se ejecutaron operaciones contra
producción, consultas remotas del proyecto, push, integración ni commit nuevo.
El procedimiento de despliegue está en [DESPLIEGUE_AUTENTICACION.md](DESPLIEGUE_AUTENTICACION.md).

## 1. Git y alcance

- Rama comprobada: `fix/auth-perfiles-automaticos`.
- HEAD inicial: `987e05f fix(auth): automatizar perfiles y fortalecer la recuperación de sesión`.
- El trabajo anterior sí estaba guardado. Le preceden `f00be35` y `0dd874b`.
- Único archivo ajeno inicial: `README.md.respaldo`, conservado y fuera del cambio propuesto.
- No se encontraron instrucciones `AGENTS.md` aplicables.
- Se revisaron los tres SQL reales, sus dependencias, servicio de perfiles,
  autenticación, manifiesto Android, pruebas y documentación histórica.
- Las migraciones se editan porque siguen pendientes según el contexto y el
  ledger de la restauración. Antes de desplegar debe verificarse de nuevo el
  ledger remoto. Si alguna versión ya fue aplicada, no sustituir su contenido:
  preparar una migración correctiva nueva mediante CLI.

## 2. Auditoría y correcciones

| Hallazgo | Evidencia y corrección | Alcance del riesgo |
|---|---|---|
| `PUBLIC` no estaba incluido en el REVOKE de usuarios | Con un grant previo a PUBLIC, la prueba de ausencia de SELECT anónimo falla con HEAD. La primera migración ahora revoca también PUBLIC | Defecto ante deriva de permisos; no se acreditó una fuga de filas ni que exista ese grant en producción. RLS sigue siendo otra barrera |
| `MAINTAIN` residual en PostgreSQL 17 | La prueba de permisos falla con las migraciones originales. La segunda lo revoca en las cinco tablas que ya protege | Exceso de privilegios de mantenimiento; no equivale a haber explotado la Data API |
| Comprobación incompleta de prerrequisitos de recuperación | La tercera ahora comprueba INSERT de columna, UPDATE de identidad/rol/fecha, lectura anónima, RLS y presencia de la política restrictiva de la segunda | Rechaza ejecución anticipada y permisos reintroducidos; la comprobación de nombre/tipo de política no sustituye comparar su expresión en preflight |
| Esperas DDL sin límite uniforme | Las tres fijan `lock_timeout=5s` y `statement_timeout=60s` por transacción | Aborto controlado frente a contención; el ejecutor debe detenerse al primer error |

En PostgreSQL 17, REVOKE de tabla también revoca los privilegios correspondientes
de columnas. El problema confirmado era PUBLIC, no una supervivencia general de
grants de columna tras REVOKE ALL. El arnés inyecta ambos tipos de grants y verifica
los permisos efectivos, sin depender de esa suposición.
[Referencia PostgreSQL 17](https://www.postgresql.org/docs/17/sql-revoke.html).

Las funciones privilegiadas usan referencias cualificadas y `search_path` vacío.
Los helpers parametrizados no son ejecutables por clientes. La RPC pública es
SECURITY INVOKER, sin parámetros, y devuelve solo la identidad de `auth.uid()`;
su SELECT final pasa por RLS. El helper privado verifica que esa identidad exista
en Auth y solo inserta `usuario`. No usa metadatos para autorizar ni ejecuta UPDATE
o DELETE. `ON CONFLICT DO NOTHING` preserva el perfil que ya exista.

El trigger admite nombres descriptivos Google, limita su longitud y no copia
roles del cliente. Un error de perfil revierte también el alta Auth. Los errores
de creación/recuperación no incluyen datos personales en el mensaje al cliente.
Las pruebas preservan administradores y propietarios, impiden autopromoción,
robo de propiedad, autoaprobación y verificación falsificada. Los propietarios y
colaboradores autorizados mantienen sus operaciones; desactivar membresías retira
acceso. La autorización depende de datos del servidor, no del panel Flutter.

No se cambia el callback Google, PKCE, credenciales ni código Flutter.
La recuperación de un perfil ausente no restaura privilegios históricos: crea
`usuario`; cualquier restitución de privilegios requiere revisión administrativa.

## 3. Resultado por migración

| Orden y archivo | PostgreSQL 17.6/17.11 reconstruido | Copia restaurada 17.6 |
|---|---|---|
| 1. `20261017233138_fortalecer_acceso_perfiles.sql` | Dos aplicaciones correctas; rollback por contención correcto | Dos aplicaciones correctas con propietario `supabase_admin` |
| 2. `20261018000337_validar_seguridad_acceso.sql` | Dos aplicaciones correctas; rollback por contención correcto | Dos aplicaciones correctas con propietario `supabase_admin` |
| 3. `20261022033531_recuperar_perfil_autenticado.sql` | Dos aplicaciones correctas; rollback por contención correcto; recuperación concurrente correcta | DDL aplicado dos veces; RPC falla por USAGE ausente sobre `auth` |

El orden es obligatorio. Las dependencias de septiembre deben existir previamente.
Cada archivo confirma su propia transacción: **el conjunto no es atómico**.
Se compararon huellas de todas las filas de tablas de `auth` y `public` antes y
después de las dos pasadas, incluyendo roles, propiedad y membresías. No hubo
cambios. Las pruebas negativas verifican rechazo antes de la primera migración,
antes de la segunda y ante INSERT de columna reintroducido antes de la tercera.

## 4. Respaldo restaurado: bloqueo reproducido

Se inició `cercly-restore-supabase`, originalmente detenido. Su red es `none`, sin
puertos publicados ni volúmenes montados. La base `cercly_verificacion` contiene
PostgreSQL 17.6, 12 usuarios, 12 perfiles y las diez versiones de septiembre.
Se exportó desde ese contenedor local con `pg_dump -Fc` y se restauró en una base
vacía de un contenedor nuevo, conservando los propietarios y ACL disponibles.
No se usaron cuentas reales para pruebas destructivas: las altas, borrados de
perfiles y cambios de roles de prueba usan exclusivamente UUID y correos sintéticos.

Problemas comprobados en la fuente restaurada:

1. `auth.users`, `public.usuarios`, `public.establecimientos` y funciones revisadas
   pertenecen a `supabase_admin`. Ejecutar como `postgres` falla con `must be owner
   of table usuarios`. Crear fixtures Auth como `postgres` también fue rechazado.
2. `anon` y `authenticated` carecen de USAGE sobre `auth`, `extensions` y `storage`.
   Tampoco tienen SELECT/INSERT en las tablas públicas inspeccionadas antes de las
   migraciones. No se infiere que producción tenga estos mismos permisos.
3. Ejecutando DDL como el propietario real de la copia, las tres migraciones
   concluyen. La recuperación bajo `authenticated` falla con SQLSTATE `42501`,
   `permission denied for schema auth`, al evaluar `auth.uid()` en la RPC pública.

No se corrigieron estos permisos mediante grants amplios ni se cambiaron los
propietarios del respaldo. Esa modificación habría cambiado la base del ensayo.
La comparación original/copia y la conservación de la fuente después del fallo
fueron satisfactorias. El arnés termina con error; no presenta el ensayo completo
como aprobado. Las suites posteriores a la prueba de concurrencia no se ejecutaron
en esa copia. Se desconoce si la omisión se originó en el dump inicial o en su
restauración anterior: se necesita revisar el artefacto y procedimiento originales.

La prueba acredita recuperabilidad de los datos disponibles, no recuperación
completa de seguridad, Storage binario, configuración OAuth ni producción actual.
Al terminar, el contenedor fuente se devolvió a su estado detenido original.

## 5. Pruebas ejecutadas en esta auditoría

| Verificación | Resultado |
|---|---|
| `flutter pub get` | Correcto; lockfile sin cambios |
| `flutter analyze` | Sin incidencias |
| `flutter test --reporter expanded` | 140 aprobadas, 8 omitidas, cero fallos |
| `flutter build apk --debug` | Correcto; APK sin configuración de backend |
| SQL reconstruido, PostgreSQL 17.6 | 210/210 en diez suites |
| SQL reconstruido, PostgreSQL 17.11 | 210/210 en diez suites |
| Recuperaciones concurrentes por versión | 8/8; un único perfil básico |
| Reaplicación y huellas Auth/public por versión | Correctas |
| Contención DDL por versión | Tres abortos 55P03 esperados; permisos/funciones/políticas/triggers sin cambios parciales |
| Regresión contra SQL original de HEAD | La suite nueva detectó dos fallos: SELECT heredado de PUBLIC y MAINTAIN |
| Copia de la base restaurada | Datos y DDL preservados; flujo de recuperación bloqueado por ACL ausentes |

Desglose SQL por versión: auth 11, permisos finales 16, cercanía 19, importación OSM
17, modelo/PostGIS 18, recuperación 24, promoción OSM 28, reclamo OSM 17, taxonomía
3 y seguridad 57. Las suites revierten sus fixtures; también se comprobó la huella
de datos antes/después de las suites. Los fixtures de instalación/concurrencia
solo existen en el contenedor desechable que el arnés crea y detiene.

Los ocho tests Flutter omitidos requieren un endpoint HTTP para establecimientos
y promociones. El contrato OAuth, cancelación, errores, callback y aislamiento
de identidad se prueban con transporte simulado. GoTrue/PostgREST completos y
JWT firmados no fueron ejercitados en esta auditoría.

Un primer control de rollback comparaba campos estadísticos de `pg_class` y falló
en 17.11. Se corrigió el arnés para comparar propiedades de seguridad estables;
la repetición definitiva aprobó en ambas versiones. No se atribuye ese fallo
a un cambio de datos ni se ocultan los ensayos incompletos anteriores.

## 6. Android

No había dispositivos conectados inicialmente. Se intentó arrancar Pixel 7 con
`-read-only -no-snapshot`, primero SwiftShader y después GPU/Vulkan desactivados.
Ambas ejecuciones terminaron con segmentation fault, código 139, antes de disponer
de ADB. No se instaló el APK ni se alteró una sesión del usuario.

Google real funcionaba previamente según el usuario. **No se volvió a probar**
consentimiento, retorno al dispositivo ni persistencia real en esta auditoría.
La compilación y los mocks no equivalen a esa validación.

## 7. Evidencias y reproducción

Evidencias temporales, fuera de Git:

- `/tmp/cercly-final-analyze.log`, `/tmp/cercly-final-flutter-tests.log`.
- `/tmp/cercly-final-android-build.log`, `/tmp/cercly-final-emulator.log`, `/tmp/cercly-final-emulator-off.log`.
- PostgreSQL 17.6: `/tmp/cercly-security-results-qbb_s7pb/`.
- PostgreSQL 17.11: `/tmp/cercly-security-results-1kmw2v3q/`.
- Copia fiel: `/tmp/cercly-security-results-wnck82q4/`.
- Regresión anterior: `/tmp/cercly-security-results-lur7ujrh/`.

Los dumps de las copias están en directorios temporales modo 700, archivos modo
600; contienen datos sensibles, no deben adjuntarse al informe ni incorporarse
al repositorio. No sustituyen una copia operativa cifrada con retención definida.

```bash
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
python3 scripts/test_supabase_security_local.py --legacy-acl-drift --lock-contention
python3 scripts/test_supabase_security_local.py --postgres-17-6 --legacy-acl-drift --lock-contention
# Requiere fuente local encendida. Actualmente reproduce el bloqueo documentado:
python3 scripts/test_supabase_security_local.py --restored-verification --postgres-17-6
git diff --check
```

## 8. Riesgos, cierre y siguiente acción

**NO-GO** hasta acreditar restauración de propietarios/ACL, completar el ensayo
HTTP en staging, validar Android/Google real, comprobar el estado remoto fresco
y recibir autorización explícita. La versión 17.6 probada demuestra compatibilidad
del SQL, no que sea la versión de motor recomendada para operar; revisar aparte
el aviso oficial sobre [17.11 y extensiones](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes).
Los grants amplios por defecto y privilegios de otras tablas quedan como seguimiento
de seguridad fuera de estas tres migraciones; no se declara saneada toda la base.

Próxima acción: revisar el respaldo/procedimiento original y construir otra
restauración que conserve propietarios y permisos, sin modificar la copia actual.
Después repetir este arnés y los casos de Auth/PostgREST en staging con cuentas
sintéticas. Revalidar Google cuando Pixel 7 pueda arrancar.

Archivos de este cambio: tres migraciones, arnés SQL, nueva suite de permisos,
este informe, procedimiento de despliegue, índice documental y avisos de vigencia
en los dos informes anteriores. No se modificaron archivos Dart ni credenciales.

```text
supabase/migrations/20261017233138_fortalecer_acceso_perfiles.sql
supabase/migrations/20261018000337_validar_seguridad_acceso.sql
supabase/migrations/20261022033531_recuperar_perfil_autenticado.sql
scripts/test_supabase_security_local.py
supabase/tests/auth_final_permissions_test.sql
docs/AUDITORIA_FINAL_AUTENTICACION.md
docs/DESPLIEGUE_AUTENTICACION.md
docs/AUTENTICACION_PERFILES_AUTOMATICOS.md
docs/PLAN_DESPLIEGUE_SEGURIDAD_SUPABASE.md
docs/README.md
```

La revisión final de estos diez archivos no detectó claves privadas, credenciales
PostgreSQL embebidas, claves secretas Supabase/AWS, JWT service_role ni archivos de
respaldo. `git diff --check`, compilación sintáctica del arnés, enlaces documentales
y correspondencia de los tres SHA-256 del procedimiento resultaron correctos.
Esta revisión del cambio no certifica todo el historial del repositorio.

Commit propuesto para cuando se resuelva el bloqueo y se autorice:
`fix(auth): auditar permisos y preparar despliegue seguro de perfiles`.
No se creó commit ni se solicitará dar por cerrado un bloque cuya restauración
completa sigue fallando. Los cambios permanecen locales y revisables.

## 9. Continuación: diagnóstico de RPC y Pixel 7

### 9.1 Comparación causal del fallo SQL

Se compararon catálogos de la fuente `cercly_verificacion`, otra copia fiel y una
base reconstruida en la misma imagen PostgreSQL 17.6. La nueva consulta
`scripts/sql/auth_catalog_audit.sql` exporta solo metadatos, sin cuentas ni secretos.
Normaliza `search_path` al serializar políticas: inicialmente `uid()` y `auth.uid()`
parecían distintos por la configuración de sesión, pero apuntan a la misma función.

| Elemento | Reconstruido | Restaurado / fuente |
|---|---|---|
| Roles relevantes y membresías globales | Coinciden | Coinciden también entre fuente y copia |
| `anon` / `authenticated` | Sin SUPERUSER/BYPASSRLS | Igual |
| USAGE sobre `auth` para authenticated | Sí | No; `nspacl` nulo |
| EXECUTE efectivo de `auth.uid()` | Sí | Sí, por permiso PUBLIC predeterminado |
| SELECT cliente sobre `auth.users` | No | No |
| Owner de `auth.users` | `supabase_auth_admin` | `supabase_admin` |
| Owner de perfiles/funciones de aplicación | `postgres` | `supabase_admin` |
| ACL de establecimientos/miembros antes de migrar | Grants de la baseline | Nulas; sin acceso cliente |
| Políticas de perfiles normalizadas | Dos políticas RLS | Mismas expresiones y comandos |
| RPC/helper después del SQL previo al nuevo preflight | Mismas definiciones | Mismas definiciones; distinto owner/ACL |

**Prueba causal:** en una base reconstruida donde la RPC funciona, se revocó USAGE
de `auth` a `authenticated` dentro de una transacción de prueba. Una conexión nueva
ejecutó la RPC y produjo el mismo `42501: permission denied for schema auth`.
El cierre por error revirtió la transacción; la RPC volvió a devolver `usuario`.
No se concedieron permisos sobre Auth en este experimento. Las pruebas también
demuestran que resolver/ejecutar `auth.uid()` no permite consultar `auth.users`.

**Conclusión:** el fallo observado deriva del catálogo incompleto de la restauración,
no de una necesidad de elevar la RPC pública a SECURITY DEFINER. El helper inserta
con la identidad del servidor; el SELECT público conserva RLS y requiere poder
resolver `auth.uid()`. El error revierte la llamada completa, sin dejar la inserción
del helper confirmada. No se modificaron owners/ACL de la fuente ni se añadieron
grants generales o específicos sobre `auth` para superar el error.

Hay una mejora de diseño de despliegue: la tercera migración ahora verifica
USAGE de `auth` y EXECUTE de `auth.uid()` para `authenticated` antes de crear o
reemplazar funciones. Ante carencias aborta con `42501` y el mensaje
`Prerrequisitos Auth incompletos: verificar restauración de permisos`.
En la copia fiel, las dos primeras migraciones concluyen y la tercera **se rechaza
antes de instalar la RPC**. Esto sustituye el resultado anterior de DDL instalado
seguido de fallo de ejecución. No repara ni oculta la restauración defectuosa.

También se corrigió una limitación del bootstrap local: su `auth.uid()` solo
consultaba `request.jwt.claim.sub`; la fuente usa además `request.jwt.claims` JSON.
El bootstrap ahora acepta ambos y se añadieron pruebas de recuperación, RLS y
metadatos maliciosos mediante claims JSON. No cambia la función de plataforma de
producción ni se manipulan JWT reales. Las diferencias de saltos de línea en
`es_administrador()` no cambian su comportamiento.

No se determinó en qué paso histórico se perdieron owners/ACL: falta revisar el
dump/procedimiento original. La fuente ya tiene esas carencias y su nueva copia las
reproduce. Se mantiene el bloqueo externo de restauración; no se inventó un mapa
de grants para presentarla como equivalente a producción.

### 9.2 Diagnóstico Android y alternativa comprobada

`coredumpctl` identifica SIGSEGV en `qemu-system-x86_64-headless`, no en un proceso
Flutter/Cercly. El backtrace del PID 44670 contiene cinco frames de
`emulator/lib64/gles_swiftshader/libGLESv2.so`, sin símbolos suficientes para
atribuir una línea concreta. Falló antes de arrancar Android y antes de instalar
o ejecutar el APK. Por tanto el crash investigado corresponde al emulador/renderizador.

KVM v12 está instalado y utilizable; la GPU disponible es AMD Radeon RX 6600.
La advertencia de RAM no demuestra la causa del SIGSEGV. Se hizo un ensayo adicional
sin cámaras y volvió a fallar con SwiftShader (PID 79275). Manteniendo las cámaras
desactivadas y cambiando únicamente el renderizador a `host`, Pixel 7 arrancó en
19 239 ms; `sys.boot_completed=1`. No se actualizó el SDK ni se editaron configuraciones
persistentes del AVD. La alternativa probada es:

```bash
/home/Anthony/Android/Sdk/emulator/emulator -avd Pixel_7 -port 5580 \
  -read-only -no-snapshot -no-window -no-audio -gpu host \
  -camera-back none -camera-front none
```

Es una alternativa local de ejecución, no una corrección del binario SwiftShader.
No se validaron cámaras ni todos los backends gráficos. La documentación oficial
describe los [modos de aceleración gráfica](https://developer.android.com/studio/run/emulator-acceleration).

Se instaló el APK debug existente sin configuración de backend, SHA-256
`6b1f7d53db46a53fe393a685d08cb3bb73784864a75c5cc2c7198a34bbcde38c`.
Se automatizaron cuatro casos: inicio, cierre/reapertura y apertura del callback
`com.cercly.cercly://auth-callback/` con aplicación cerrada y abierta. Todos mostraron
la pantalla esperada «Falta configurar Supabase», conservaron proceso vivo y no
registraron FATAL EXCEPTION/Fatal signal en el logcat del proceso. Se verificó
resolución del intent, UI Automator y captura visual.

Estas pruebas acreditan instalación, renderizado Flutter, arranque y entrega del
intent Android. **No prueban intercambio OAuth, recuperación de sesión, backend ni
consentimiento Google**: el APK no tiene endpoint configurado y no inicializa
Supabase. No se enviaron tokens ficticios ni se usaron cuentas reales.

### 9.3 Validación de esta continuación

| Comprobación ejecutada | Resultado |
|---|---|
| PostgreSQL 17.6 reconstruido | **216/216**, diez suites |
| PostgreSQL 17.11 reconstruido | **216/216**, diez suites |
| Falta de USAGE y falta de EXECUTE en preflight | Dos rechazos esperados por versión, rollback sin GRANT |
| Reproducción del fallo original / recuperación tras rollback | Correcta en ambas versiones |
| Reaplicación, ocho recuperaciones concurrentes y tres fallos DDL bajo bloqueo | Aprobados en ambas versiones |
| Copia fiel | Rechazo preventivo esperado de la tercera migración; fuente sin cambios de datos |
| Flutter: auth_roles, auth_oauth y profile_service | **30/30** |
| Android sobre GPU host | **4/4** smoke; sin backend |

El total SQL aumenta por tres aserciones de prerrequisitos/permisos y tres de
claims JSON: permisos finales 19 y recuperación 27. El resto conserva sus conteos.
No se atribuye a esta continuación una ejecución nueva de toda la suite Flutter,
pub get, analyze ni una compilación nueva: se reutilizó el APK ya auditado y se
repitieron los tests afectados. No se modificó código Dart.

Evidencia agregada versionable y sin datos personales:
[autenticacion_diagnostico_20261025.json](evidencias/autenticacion_diagnostico_20261025.json).
Incluye comparación de roles/ACL, hashes de catálogos, conteos y resultados Android.
Evidencias detalladas temporales:

- SQL 17.6: `/tmp/cercly-security-results-ue2603vm/`.
- SQL 17.11: `/tmp/cercly-security-results-fuzvj7bj/`.
- Copia fiel/preflight: `/tmp/cercly-security-results-rplfzlez/`.
- Comparación anterior al nuevo guard: `/tmp/cercly-security-results-tnrea5f0/` y `/tmp/cercly-security-results-gnwkvq8_/`.
- Fuente: `/tmp/cercly-auth-source-catalog.json`.
- Flutter: `/tmp/cercly-auth-followup-flutter.log`.
- Coredump/backtrace: `/tmp/cercly-pixel7-coredump-info.log`, `/tmp/cercly-pixel7-backtrace.log`.
- Android: `/tmp/cercly-pixel7-no-camera.log`, `/tmp/cercly-pixel7-host-gpu.log`, `/tmp/cercly-android-followup/`.

Para reproducir SQL, añadir `--diagnose-auth` a los comandos de la sección 7.
El diagnóstico guarda catálogos, comprueba rechazos y reproduce la carencia de
USAGE mediante REVOKE transaccional; nunca añade permisos sobre Auth.

**Decisión vigente: NO-GO para producción.** El impedimento de arranque Android
tiene una alternativa comprobada; ya no bloquea los smoke tests locales. Persisten
la restauración completa de seguridad y las pruebas reales de Auth/PostgREST/Google.
Se detiene el trabajo sobre la copia defectuosa sin ampliar permisos ni elevar la
RPC. No se hicieron commits, operaciones remotas, push ni integración en develop.
La instancia temporal Pixel 7 se cerró con `adb emu kill`; el contenedor fuente
volvió a quedar detenido. Se conservaron los cambios anteriores y los respaldos.

## 10. Verificación para commit únicamente local

El usuario autorizó el commit local, sin push, integración en `develop` ni cambios
en producción. Esta autorización no resuelve los bloqueos de despliegue.

Se revisaron los catorce archivos del cambio: tres migraciones, bootstrap local,
arnés Python, consulta de catálogos, dos suites SQL, cinco documentos Markdown y
la evidencia JSON. `README.md.respaldo` queda intacto y sin seguimiento.
La revisión de contenido y patrones no detectó secretos reales, dumps, respaldos
ni archivos ajenos entre los candidatos. La contraseña fija del arnés es sintética
y se usa únicamente en el contenedor desechable sin red. No se certifica el resto
del historial ni los archivos locales excluidos.

Los tres SHA-256 coinciden con el procedimiento de despliegue. La sintaxis Python,
los totales del JSON, los enlaces documentales locales y `git diff --check` son
correctos. Los archivos temporales de catálogos citados por el JSON histórico ya
no están disponibles; no se presenta su comparación como una nueva validación.

Se conserva **NO-GO**: faltan restauración fiel de propietarios/ACL, pruebas con
Auth/PostgREST y Google reales, revisión remota vigente y autorización de despliegue.
En esta revisión no se repitió la copia restaurada ni el smoke Android histórico.

Pruebas repetidas antes del commit:

| Verificación | Resultado |
|---|---|
| SQL PostgreSQL 17.6 y 17.11, con diagnóstico Auth, deriva ACL y contención | 216/216 por versión; diez suites |
| Reaplicación, conservación de datos y ocho recuperaciones concurrentes | Aprobadas en ambas versiones |
| Rechazo de prerrequisitos ausentes y rollback de las tres migraciones | Aprobados en ambas versiones |
| Suite Flutter completa | 140 aprobadas, ocho omitidas por requerir endpoint HTTP, cero fallos |

Logs nuevos fuera de Git: `/tmp/cercly-auth-precommit-176.log`,
`/tmp/cercly-auth-precommit-1711.log` y `/tmp/cercly-auth-precommit-flutter.log`.
Los primeros intentos no iniciaron las pruebas por restricciones del sandbox
sobre Podman y la caché Flutter; las ejecuciones autorizadas posteriores aprobaron.
