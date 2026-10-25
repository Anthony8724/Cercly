# Cercly — procedimiento de despliegue de autenticación

25 de octubre de 2026. **Preparado, no autorizado ni ejecutado en producción.**
Estado actual: **NO-GO**, por los bloqueos del
[informe final](AUDITORIA_FINAL_AUTENTICACION.md).
Este documento reemplaza para estas tres migraciones el plan histórico que
solo contemplaba las dos primeras y sus hashes anteriores.

## 1. Verificaciones previas

1. Designar responsable técnico, responsable de decisión, ventana, interrupción
   aceptable, RPO y RTO. No hay valores aceptados ni tiempos de recuperación de
   producción medidos en esta auditoría.
2. Revisar el diff definitivo. El usuario autorizó el commit únicamente local en
   `fix/auth-perfiles-automaticos`; esa autorización no incluye push, integración
   ni despliegue. Ver la sección 10 del informe final para la verificación actual.
3. Preparar un directorio de release inmutable del commit aprobado, con las trece
   migraciones versionadas. Las únicas pendientes permitidas son las tres de la
   sección 4; no ejecutar seeds ni scripts de importación.
4. Verificar proyecto, PostgreSQL 17, historial, owners, políticas, ACL, membresías
   de roles, extensiones y consumidores de API. Los conteos del respaldo no son
   prueba del estado actual de producción. Si alguna de estas versiones ya fue
   aplicada, no sustituir su contenido: generar una migración correctiva nueva.
5. Comprobar que el ejecutor puede modificar los objetos como propietario o por
   membresía autorizada. No conceder superusuario ni ampliar permisos cliente
   para superar errores. La copia pertenece a `supabase_admin`; el ensayo
   reconstruido ejecuta migraciones como `postgres`. Esa diferencia sigue abierta.
6. Verificar `anon`/`authenticated` sin SUPERUSER/BYPASSRLS, membresías administrativas
   ni CREATE en esquemas de código privilegiado. Cotejar USAGE y permisos de
   plataforma sobre Auth/Storage y `auth.uid()` con el catálogo de origen.
   Conservar permisos de servicios Auth y confirmar RLS en tablas expuestas.
7. Mantener `cercly_auth_private` fuera de esquemas expuestos de la Data API.
   Inventariar consumidores que insertan/borran perfiles o cambian roles: el
   cliente solo debe leer perfiles y editar nombre; la administración usa RPC
   revisadas. Cotejar las expresiones RLS, no solo sus nombres.
8. Completar respaldo fiel y staging. Conservar PKCE, redirect Google y proveedores
   funcionales. No modificar credenciales.

## 2. Respaldo y restauración

La base existente acredita datos restaurados, pero **no recuperación completa de
seguridad**. Localizar primero el dump y el procedimiento originales, revisar
fecha/cobertura/hash y si se omitieron owners/ACL. No modificar esa copia.

Para un respaldo nuevo, solo tras autorizar la operación remota:

1. Usar conexión protegida mediante servicio libpq/gestor de secretos, sin
   contraseñas en argumentos, repositorio o logs debug. Crear directorio protegido
   fuera de Git y cifrar para retención. Registrar fecha UTC, proyecto, versión,
   tamaño y SHA-256. Auth contiene datos sensibles: proteger el dump completo.
2. Capturar esquema, funciones, políticas, triggers, propietarios, ACL, datos,
   secuencias e historial. Exportar roles/membresías revisados sin hashes de sus
   contraseñas. Verificar cobertura de `auth`, `public`, `storage`,
   `supabase_migrations` y extensiones. No asumir que los filtros por defecto de
   `supabase db dump` conservan todo lo necesario. Patrón libpq propuesto:

   ```bash
   # Solo después de aprobación; servicios y rutas son ejemplos pendientes.
   umask 077
   pg_dump --dbname=service=cercly_backup --format=custom --file=/ruta/protegida/cercly.dump
   pg_dumpall --database=service=cercly_backup --roles-only --no-role-passwords --file=/ruta/protegida/roles.sql
   sha256sum /ruta/protegida/cercly.dump /ruta/protegida/roles.sql
   pg_restore --list /ruta/protegida/cercly.dump
   ```

   Cualquier objeto ilegible/error es NO-GO. Si no puede exportar roles de
   plataforma, cotejar sus definiciones con una fuente autorizada y registrar
   la limitación. Los dos archivos no comparten automáticamente una instantánea:
   congelar cambios administrativos y validar catálogo durante su captura.
3. Respaldar Storage binario y configuración de servicios por separado: el dump
   SQL no contiene los archivos ni configura OAuth.
4. Preparar destino nuevo aislado, con motor/extensiones compatibles. Revisar
   roles contra los provistos por la plataforma; no ejecutar `roles.sql` a ciegas
   en una instancia existente. Crear base vacía desde `template0`; restaurar con
   `pg_restore --exit-on-error` y el rol local autorizado, conservando owners/ACL.
   No usar `--no-owner`, `--no-acl`, `--clean` ni restaurar encima del original.
5. Comparar tablas, secuencias, constraints, funciones, propietarios, ACL, políticas,
   triggers e historial. Comparar huellas de filas ordenadas, roles, propiedad y
   membresías en una ventana consistente, además de conteos. No guardar filas ni
   mapas de identidades en Git. Validar login y autorización: importar sin errores
   no acredita recuperación del servicio.
6. Medir tiempo hasta servicio validado y antigüedad del punto recuperado; aceptar
   RPO/RTO antes de GO. Definir retención y conservar copia protegida fuera del
   equipo de desarrollo. La evidencia temporal `/tmp` no es esa copia operativa.

[Respaldos Supabase](https://supabase.com/docs/guides/platform/backups).

## 3. Ensayo previo en staging

Usar cuentas sintéticas. Los mocks y las suites SQL no sustituyen esta matriz con
GoTrue/PostgREST reales y sesiones firmadas:

| Caso | Resultado exigido |
|---|---|
| Usuario existente, administrador, propietario | Sesión válida, perfil/rol conservados y panel correcto |
| Alta email y Google | Un perfil básico; nombres válidos; metadatos sin autoridad |
| Perfil sintético ausente | Recuperación propia; repetición y ocho llamadas simultáneas dejan una fila |
| Sesión ausente/inválida/ajena | Sin acceso ajeno; anon no ejecuta RPC |
| Manipulación de rol, identidad, fecha o metadatos | Rechazo, sin cambios persistidos |
| Propiedad, aprobación, colaboradores | Solo responsables autorizados gestionan; desactivación retira acceso; no se falsifica verificación |
| Error de trigger de perfil | Alta Auth revertida, mensaje sanitizado, sin huérfano |
| Pantallas públicas | Negocios/promociones publicados visibles; borradores ajenos invisibles; ejecutar los ocho tests HTTP omitidos |
| Android | Google, cancelación, denegación, callback con app abierta/cerrada, logout, expiración y persistencia al reabrir |
| Contención DDL | Aborto por lock_timeout sin cambios parciales; reintento deliberado tras liberar bloqueo |

El consentimiento Google real puede requerir intervención manual. Registrar casos
realmente ejecutados y build, sin tokens. Ensayar también CLI/ledger de migraciones
en staging; SQL por psql no acredita ese mecanismo de release.

## 4. Orden exacto y aplicación

| Orden | Archivo | SHA-256 revisado |
|---|---|---|
| 1 | `20261017233138_fortalecer_acceso_perfiles.sql` | `51063a2200fb362a7c05e18781ea5634023c6e8a052ecda1ec2940d4247baea2` |
| 2 | `20261018000337_validar_seguridad_acceso.sql` | `ad454b029313b2c164524b179f0bcfe23f5be307026547db75787babdf39458f` |
| 3 | `20261022033531_recuperar_perfil_autenticado.sql` | `ddad7a3b4898df4f003e015d3f273be5a7ec2beb2c92c1d8a94dfcc47804dbd2` |

Los hashes históricos ya no describen estos archivos. Detenerse ante cualquier
diferencia, versión aplicada previamente, migración extra pendiente o deriva no
revisada. Las diez migraciones de septiembre son prerrequisito.

Tras GO y autorización explícita de despliegue, verificar con
`supabase migration list --linked --workdir <release>` y aplicar mediante
`supabase migration up --linked --workdir <release>`. La ayuda de CLI 2.119.0
para `migration up` y `db dump` se consultó; **no se ejecutó aplicación ni dump
remoto**. Resolver placeholders y comprobar el proyecto antes de pedir aprobación.
No usar `--include-all`, `migration repair`, `db reset` ni autoaceptación para
superar discrepancias.

Cada archivo tiene BEGIN/COMMIT, `lock_timeout=5s` y `statement_timeout=60s` locales.
El conjunto **no es atómico** y los límites por sentencia no son una ventana total.
Detener el ejecutor al primer error, sin pasar a la siguiente migración.
La tercera también rechaza antes del DDL la falta de USAGE sobre `auth` o de
EXECUTE sobre `auth.uid()` para authenticated. No concede esos permisos:
corregir la fidelidad de la restauración mediante su procedimiento revisado,
sin elevar la RPC ni añadir grants amplios.

## 5. Validaciones posteriores

Mantener la ventana de control de escrituras durante la comparación. Estas son
consultas de lectura propuestas; revisar para el release antes de ejecutarlas.
No correr suites de fixtures contra producción.

```sql
begin read only;
select version from supabase_migrations.schema_migrations order by version;
select count(*) as usuarios_sin_perfil
from auth.users a left join public.usuarios u on u.id=a.id where u.id is null;
select rol, count(*) from public.usuarios group by rol;
select tgname, tgenabled, pg_get_triggerdef(oid)
from pg_trigger where tgrelid='auth.users'::regclass and not tgisinternal;
select r, has_any_column_privilege(r,'public.usuarios','INSERT') as inserta,
  has_column_privilege(r,'public.usuarios','rol','UPDATE') as modifica_rol,
  has_table_privilege(r,'public.usuarios','TRUNCATE') as trunca
from unnest(array['anon','authenticated']) r;
select has_column_privilege('authenticated','public.usuarios','nombre','UPDATE') as edita_nombre,
  has_any_column_privilege('anon','public.usuarios','SELECT') as anon_lee,
  has_function_privilege('anon','public.recuperar_mi_perfil()','EXECUTE') as anon_rpc;
select polname, polpermissive, pg_get_expr(polwithcheck,polrelid)
from pg_policy where polrelid='public.establecimientos'::regclass;
commit;
```

Comparar huellas de perfiles/roles, propiedad y membresías con la captura previa;
inspeccionar RLS, ACL de columna, MAINTAIN y owners/search_path de funciones.
Confirmar que el helper parametrizado es inaccesible para clientes y el trigger
Auth sigue activo. Verificar historial y definiciones conjuntamente: una
desconexión entre COMMIT y ledger puede dejar estado ambiguo. Si aparece PGRST202,
revisar/refrescar descubrimiento de RPC en PostgREST por el procedimiento ensayado.

Revisar errores y métricas Auth/PostgREST sin datos sensibles. Hacer únicamente
los smoke tests de producción incluidos en la autorización: cualquier cuenta de
control también requiere ese alcance. No promover usuarios reales para probar.
Comparar con staging antes de distribuir la app.

## 6. Contingencia y recuperación

| Situación | Acción |
|---|---|
| Error antes del COMMIT | Se revierte ese archivo. Revisar SQLSTATE, locks, catálogo y ledger antes de reintentar |
| Primera/segunda confirmada y siguiente fallida | Conservar controles aplicados, detener release y flujos afectados; no asumir rollback de todo el lote |
| Desconexión en COMMIT/ledger | Inspeccionar ambos estados; no marcar versiones ni repetir a ciegas |
| RPC/trigger falla después | Pausar distribución/flujo afectado, conservar datos y preparar corrección nueva probada y autorizada |
| Recuperación de datos necesaria | Restaurar punto validado en destino separado, comparar escrituras posteriores y aceptar RPO antes de cambiar tráfico |

No conceder INSERT/UPDATE general a clientes, deshabilitar RLS, restaurar roles en
masa ni borrar usuarios para forzar perfiles. No hay migración inversa universal
segura: una reversión ciega reabriría controles previos. Preferir corrección hacia
adelante con revisión y autorización nueva.

La recuperación completa necesita autorización separada, responsable y ventana.
Conservar evidencia y escrituras posteriores para reconciliación; volver a un
punto anterior puede perderlas. Validar Auth, permisos, Storage y clientes antes
de cambiar tráfico. Revertir la app no revierte la base.

## 7. GO/NO-GO

**GO solo con todas las condiciones:** diff/commit aprobado, hashes y ledger
exactos, catálogo compatible, respaldo reciente restaurado con owners/ACL y
RPO/RTO aceptados, SQL y staging HTTP aprobados, Android/Google real validado,
esquema privado no expuesto, ventana/contingencia listas y permiso explícito para
las tres migraciones y los smoke tests de producción.

**Estado actual: NO-GO.** Faltan permisos de plataforma en la copia restaurada;
Auth/PostgREST reales y Google siguen pendientes. El fallo SwiftShader del emulador
tiene una alternativa local comprobada con GPU `host`: los cuatro smoke tests
Android pasan, pero no validan autenticación real. Ver sección 9 del informe.
El commit local está autorizado; el despliegue sigue sin autorización. La próxima
decisión depende de resolver esos puntos, no de repetir pruebas aprobadas sobre fixtures.
