# Bloque 5 — Verificación previa al despliegue de seguridad Supabase

**Actualización de recuperación:** ejecución detenida por falta de acceso PostgreSQL acreditado para un respaldo lógico consistente. No se creó ni restauró un respaldo; los 24 casos HTTP continúan pendientes. Ver sección 11.

**Recomendación: NO-GO para producción.** Las dos migraciones están preparadas y pasan las pruebas SQL locales, pero no hay un respaldo restaurable acreditado ni pruebas HTTP de autorización con sesiones reales de Supabase Auth en staging. Este documento no autoriza el despliegue.

Verificación: **18-10-2026, aproximadamente 00:18–00:20 UTC** (17-10-2026 en America/Guayaquil). Repetir las comprobaciones inmediatamente antes de cualquier despliegue futuro; los conteos y catálogos son una fotografía de esta sesión.

## 1. Identidad, alcance y restricciones cumplidas

| Elemento | Resultado comprobado |
|---|---|
| Repositorio | `/home/Anthony/Proyectos/Cercly` |
| Rama / HEAD | `develop` / `0dd874b6e6b4db549b9559c3d616620e2c5b7827` |
| Estado inicial | Solo `README.md.respaldo` sin seguimiento; intacto |
| Proyecto Supabase | **Cercly**, ref `aimubazregckmjchnszf` |
| Organización / plan | Cercly, **Free**, confirmado por API |
| Región / estado | `us-east-2` / `ACTIVE_HEALTHY` |
| PostgreSQL remoto | `17.6.1.166`, canal GA |
| Asociación de la app | El host de `SUPABASE_URL` local corresponde al mismo ref; no se imprimieron claves |
| Enlace CLI del checkout | No existe `supabase/.temp/project-ref`; no asumir que el checkout está enlazado |
| Herramienta comprobada | Supabase CLI `2.119.0`; ayuda de backups y migration list/up consultada |

Se leyeron los informes de entrega y autenticación del Bloque 3 y la auditoría del Bloque 4. Las notas del Bloque 3 sobre SQL no ejecutado quedaron superadas por las ejecuciones del Bloque 4 y por la repetición de esta sesión; no significan que se haya probado Auth HTTP real.

Las consultas remotas fueron listas de proyecto, organización, migraciones y respaldos, catálogos SQL y conteos agregados dentro de `BEGIN READ ONLY`. También se ejecutó GET de Auth settings. No se consultaron ni imprimieron nombres, emails, teléfonos, IDs personales, tokens, contraseñas o cadenas de conexión. No se modificaron usuarios, datos, roles, RLS, configuración, respaldos ni historial remoto. No se inició una restauración. No se ejecutó `supabase db push`, ni comandos de aplicación de migraciones, ni commit/push.

La reconstrucción y las escrituras de prueba ocurrieron exclusivamente en un contenedor local desechable sin red, con fixtures sintéticos y el CSV OSM ya versionado.

## 2. Historial: diez aplicadas y dos pendientes

| Versión | Nombre | Estado remoto |
|---|---|---|
| 20260912000438 | remote_schema | Aplicada |
| 20260912001054 | storage_buckets | Aplicada |
| 20260912005223 | categorias_iniciales | Aplicada |
| 20260912024346 | guardar_horarios_establecimiento | Aplicada |
| 20260912043748 | gestionar_solicitudes_establecimiento | Aplicada |
| 20260912061744 | permitir_storage_a_colaboradores | Aplicada |
| 20260913010000 | modelo_osm_postgis | Aplicada |
| 20260913060000 | refinar_taxonomia_osm | Aplicada |
| 20260914010000 | busqueda_establecimientos | Aplicada |
| 20260914120000 | corregir_reclamo_establecimiento_osm | Aplicada |
| **20261017233138** | **fortalecer_acceso_perfiles** | **Pendiente** |
| **20261018000337** | **validar_seguridad_acceso** | **Pendiente** |

No hay versiones remotas ausentes del directorio local. Coinciden nombres y versiones de las diez aplicadas. No se certifica igualdad byte a byte del SQL histórico registrado: se contrastó el **resultado de los catálogos**, que es lo relevante para las dependencias actuales.

Huella SHA-256 del contenido autorizado para una futura revisión:

```text
20261017233138_fortalecer_acceso_perfiles.sql
0e196d9b71f6c4e2414341ae3b66cd9dee85c9a56000556c2e5844fd3ecb3442

20261018000337_validar_seguridad_acceso.sql
833a9719ff2cc4aa8c09defc2676aa6fda59172247219df0eb17ea9926e912dc
```

## 3. Comparación efectiva de catálogos

Se reconstruyó una base limpia aplicando las diez migraciones previas, se capturó su catálogo, se aplicaron B3/B4, se capturó el catálogo objetivo y se repitieron las suites. No se utilizó un dump de datos remotos.

Se compararon objetos por nombre/firma, usando search_path `pg_catalog` para las expresiones y normalizando CRLF/LF en funciones. El alcance incluye tablas de `public`, funciones propias no pertenecientes a extensiones, triggers propios de `public` y el trigger de alta de `auth.users`, políticas de `public` y `storage.objects`, columnas/ACL, restricciones, índices y enums. No equivale a comparar todo Auth, Storage, extensiones, publicaciones, jobs, Edge Functions, roles personalizados o secretos de infraestructura.

| Categoría | Cantidad remota | Remoto frente a las diez migraciones previas |
|---|---:|---|
| Funciones propias de public | 14 | Coinciden definiciones, propietarios, SECURITY DEFINER y ACL |
| Triggers incluidos | 13 | Coinciden definición y estado habilitado |
| Políticas RLS incluidas | 56 | Coinciden roles, operación, USING, WITH CHECK y carácter permisivo |
| Tablas public | 11 | Coinciden propietarios y RLS; ACL de usuarios difiere solo en orden de entradas |
| Columnas | 99 | Una diferencia de permiso y nueve diferencias de posición física, detalladas abajo |
| Restricciones | 61 | Coinciden |
| Índices | 36 | Coinciden |
| Valores de enum | 27 | Coinciden |

**Diferencia funcional previa:** `usuarios.nombre` tiene UPDATE a authenticated en remoto, pero no en el catálogo reconstruido solo con las diez migraciones. La migración inicial concede el permiso de columna antes de revocar ALL de tabla. La reproducción no conserva esa concesión. B3 establece UPDATE(nombre) después de la revocación, por lo que el estado final recupera expresamente el permiso remoto legítimo. No se modifica una migración ya desplegada para ocultar esta diferencia.

**Diferencias de posición:** `estado`, `creado_en` y `actualizado_en` de establecimientos; `estado`, `motivo_respuesta`, `creado_en` y `actualizado_en` de solicitudes; `rol` y `creado_en` de usuarios tienen distinto ordinal. Tipos, nulabilidad, defaults y restricciones coinciden. No afectan las migraciones pendientes, que usan columnas por nombre. Revisar consumidores externos que usen INSERT sin lista de columnas, COPY o decodificación posicional; no se certificó su ausencia.

Frente al catálogo **objetivo** tras B3/B4 solo aparecen los cambios funcionales previstos:

- Tres cuerpos de función reemplazados: `crear_perfil_nuevo_usuario`, `proteger_rol_usuario`, `convertir_en_propietario`.
- ACL EXECUTE reducida en esas tres y en `sincronizar_categoria_principal` (esta última conserva su cuerpo).
- Un trigger reemplazado: `convertir_en_propietario_trigger`, ahora INSERT o UPDATE OF estado/propietario_id.
- Una política nueva, restrictiva: `alta sin verificacion autoconcedida`.
- ACL de las cinco tablas objetivo endurecida; UPDATE(nombre) permanece autorizado.
- Sin cambios de columnas, tipos, restricciones ni índices; persisten las diferencias de ordinal preexistentes, no creadas por el despliegue.

Otros controles remotos de lectura: no hay vistas/materialized views en public; anon/authenticated no son superusuarios, no pueden iniciar sesión SQL ni tienen BYPASSRLS o CREATE en public; service_role sí tiene BYPASSRLS. RLS está habilitado en las once tablas. El rol de aplicación administrador se resuelve contra `usuarios`, no contra metadatos editables.

Los default privileges de postgres en public siguen concediendo amplios permisos a anon/authenticated para tablas, secuencias y funciones futuras. B4 no los cambia. También queda MAINTAIN en las cuatro tablas comerciales auditadas. Son riesgos residuales de privilegio mínimo; no se encontró una RPC pública genérica que ejecute DDL/SQL arbitrario. Esta entrega no afirma endurecer toda la plataforma.

Evidencia temporal de esta sesión: `/tmp/cercly-b5/catalog.sql`, `remote.json`, `remote-vs-baseline.json`, `remote-vs-target.json`; catálogos locales y resultados en `/tmp/cercly-security-results-te79qrpt`. No son respaldos y su persistencia no está garantizada.

## 4. Impacto sobre objetos y datos existentes

Conteos de lectura, sin extraer registros individuales:

| Indicador | Resultado |
|---|---:|
| Perfiles usuarios | 11 |
| Rol usuario / propietario / administrador | 5 / 4 / 2 |
| Establecimientos | 259 |
| Aprobados / rechazados | 257 / 2 |
| Solicitudes pendientes | 0 |
| Membresías activas | 2 |
| Usuarios Auth sin perfil usuarios | **1** |
| Propietarios sin negocio aprobado ni membresía activa | **1** |
| Establecimientos Cercly con campos de verificación poblados | 0 |

Los dos indicadores de anomalía no identifican necesariamente personas diferentes ni demuestran fraude. Un propietario podría tener una autorización histórica válida. No se cambió ningún rol ni se intentó reparar perfiles. El alta futura no repara perfiles antiguos ausentes: la reparación individual exige revisión/autorización aparte.

### B3: fortalecer_acceso_perfiles

Afecta permisos de usuarios, tres funciones y un trigger. No ejecuta UPDATE/DELETE sobre perfiles durante el despliegue. Los UPDATE presentes están dentro de funciones que se ejecutarán por eventos posteriores. El rol de nuevos perfiles será siempre usuario; crear un establecimiento pendiente dejará de promover al creador. Aprobar un establecimiento sí podrá promover a usuario→propietario, sin degradar administradores. El RPC existente conserva su vía de promoción después de aprobación real.

No elimina usuarios ni rellena perfiles/roles retroactivamente. Mantiene lectura propia/administrativa y edición de nombre; quita INSERT/DELETE de perfiles a clientes. Esto exige que cualquier herramienta administrativa externa use el flujo de servidor autorizado para altas/bajas y no una sesión cliente. No se inventó una herramienta externa ni se certificó su compatibilidad.

### B4: validar_seguridad_acceso

Revoca TRUNCATE/REFERENCES/TRIGGER en usuarios, establecimientos, solicitudes_establecimientos, miembros_establecimiento y promociones; conserva DML necesario y SELECT requerido por subconsultas RLS. No ejecuta TRUNCATE.

La política restrictiva de INSERT exige verificado_en/verificado_por nulos a no administradores. La comprobación del administrador se basa en la base de datos. Conserva el alta verificada administrativa. UPDATE de esos campos ya está protegido por el trigger anterior. No reescribe ni elimina establecimientos existentes.

Retira EXECUTE cliente de un trigger de sincronización de categoría. Los triggers siguen operando bajo sus permisos internos; las alertas de EXECUTE de funciones RETURNS trigger no prueban por sí solas una RPC explotable.

### Conservación de acceso

Los dos administradores existentes no se cambian. Los propietarios y miembros activos conservan sus negocios/membresías; el rol global propietario por sí solo no autoriza gestionar negocios ajenos. Desactivar una membresía impide la gestión aunque el usuario conserve ese rol global. Los borradores privados y promociones asociadas se mantienen editables para su responsable, sin exposición pública antes de aprobar/publicar el negocio.

Las pruebas locales cubren estos casos con roles SQL reales y fixtures. No se inició sesión con ninguna cuenta real; la compatibilidad HTTP sigue pendiente.

## 5. Respaldo y capacidad de recuperación: bloqueo

Se ejecutó realmente `supabase backups list --project-ref aimubazregckmjchnszf`, operación de lectura, con salida exitosa:

```json
{"region":"us-east-2","walg_enabled":true,"pitr_enabled":false,"backups":[],"physical_backup_data":{}}
```

**No hay un respaldo listado ni punto PITR acreditado.** `walg_enabled=true` no demuestra que exista una copia recuperable. La organización está en Free. No se deduce disponibilidad de copias diarias a partir de la versión PostgreSQL o de la existencia de WAL-G.

La búsqueda por nombres habituales de dump/backup/restauración dentro del proyecto no encontró un artefacto de respaldo de base de datos. `README.md.respaldo` es un archivo de documentación, no una copia SQL. No se inspeccionaron ubicaciones externas o cuentas de almacenamiento fuera del alcance disponible, por lo que no se afirma que no existan copias en otro lugar.

**Recuperabilidad actual: no demostrada. RPO/RTO medidos: no disponibles.** No se creó, alteró ni restauró ningún respaldo. No se considera suficiente prometer un backup antes de aplicar.

Para levantar el bloqueo hace falta evidencia concreta, bajo autorización separada:

1. Inventario de una copia completa accesible: fecha UTC, proyecto de origen, versión, tamaño, estado completo, ubicación protegida, hash cuando aplique, custodio y retención.
2. Alcance comprobado: datos de aplicación, Auth, esquema, grants, funciones, triggers, RLS, roles necesarios e historial de migraciones. Un dump por defecto puede excluir esquemas gestionados; validar expresamente Auth/Storage y personalizaciones, sin asumir que un dump de public es completo.
3. Copia separada de los objetos binarios de Storage y configuración de servicios que no cubre el respaldo de base de datos. El respaldo SQL almacena metadatos, no los ficheros de Storage. No guardar secretos de proveedores en Git.
4. Evidencia de un ensayo de restauración en un destino separado y autorizado, nunca sobre este proyecto durante la preparación: integridad de FK, conteos y roles, funciones/ACL, Auth/lectura de Storage, pruebas HTTP y tiempo empleado.
5. RPO y RTO aceptados explícitamente. Si el ensayo requiere un proyecto nuevo, coste y acceso deben autorizarse antes. La reproducción de migraciones con fixtures no sustituye este ensayo.

La documentación oficial describe [respaldos y PITR](https://supabase.com/docs/guides/platform/backups) y [recuperación lógica mediante CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Esos procedimientos no se ejecutaron aquí.

## 6. Procedimiento de aplicación exclusiva — preparado, NO ejecutado

Se verificó la ayuda de CLI 2.119.0: `migration up` admite `--linked`, `--local`, `--db-url`, `--project-ref` e `--include-all`; no ofrece selección por nombre de archivo. **La exclusividad depende de congelar el directorio y comprobar que exactamente estas dos versiones están pendientes.** No usar `--include-all`, reparación de historial ni aplicación de SQL a mano que deje el ledger incoherente.

Procedimiento propuesto después de levantar el NO-GO y recibir autorización explícita:

1. Preparar un directorio de release inmutable desde `0dd874b`, con las doce migraciones versionadas y config correspondiente; sin seeds, scripts auxiliares ni nuevas migraciones. Verificar las dos huellas anteriores y que ningún proceso concurrente pueda añadir archivos. No modificar el checkout de trabajo para simular el release.
2. Establecer/verificar en ese directorio el enlace al ref exacto, con credenciales gestionadas fuera del repositorio y sin valores en línea de comandos, historial, logs o salida debug. No hay enlace existente acreditado en este checkout. Tener acceso a la API de respaldos no prueba acceso directo al Postgres remoto.
3. Ejecutar `supabase migration list --linked --workdir <release>` y repetir comparación de catálogos. El único conjunto pendiente permitido es `{20261017233138, 20261018000337}`. Cualquier tercera versión, divergencia nueva o hash distinto detiene el procedimiento.
4. Acreditar respaldo/recuperación, staging HTTP, ventana y responsable. Pausar escrituras de prueba/administración concurrentes durante la comprobación de preservación. Capturar de forma protegida una huella consistente de ID→rol/perfil, propiedad y membresías; nunca incorporar ese mapa a Git. Los conteos por sí solos no detectan una permuta de roles.
5. Configurar límites de espera en la conexión del ejecutor y comprobar que son efectivos en staging: B4 ya fija lock_timeout=5s; B3 no lo hace. Acordar también statement_timeout. No suponer que una variable de entorno será propagada sin ensayo. No cambiar GUC globales del proyecto.
6. Solo tras autorización, el comando de aplicación previsto es **`supabase migration up --linked --workdir <release>`**, que aplica las pendientes por orden y mantiene el historial mediante la herramienta. No se invocó en esta sesión. Revisar y aceptar únicamente las dos versiones esperadas; no activar autoaceptación global.
7. Cada archivo tiene su propia transacción, no existe atomicidad conjunta de ambos archivos. Si falla B4 tras confirmar B3, detener, consultar ledger y catálogos y resolver antes de reintentar. Si el proceso pierde conexión en el límite de COMMIT/registro, no inferir éxito ni fracaso: verificar ambos. No usar migration repair para ocultar un estado dudoso.
8. Ejecutar las comprobaciones de la sección 8. No abrir tráfico de pruebas de escritura ni dar por finalizado el despliegue hasta validarlas. No aplicar staging/importaciones ni suites con rollback a producción.

No se ha ensayado el camino de conexión remota de ese comando ni su registro de versiones en este proyecto. La ayuda confirma las opciones, no la autorización operativa. [Referencia oficial de migration up](https://supabase.com/docs/reference/cli/supabase-migration-up).

## 7. Matriz de riesgos

| Riesgo | Nivel | Evidencia / mitigación | Puerta de salida |
|---|---|---|---|
| No hay copia restaurable acreditada | Crítico | Lista de backups vacía, PITR deshabilitado; exigir copia e integridad/ensayo | **Bloquea GO** |
| Auth/REST no probados con sesiones reales | Alto | SQL aprobado, plataforma HTTP no ensayada | **Bloquea GO** hasta staging |
| Un usuario Auth sin perfil | Medio | Conteo agregado=1; alta nueva no hace backfill | Revisar caso y documentar tratamiento autorizado; no reparar en lote |
| Un propietario sin negocio aprobado/membresía activa | Medio | Puede ser histórico legítimo; no revocar automáticamente | Revisar y aceptar preservación de derechos históricos |
| Bloqueos DDL durante B3 | Medio | Reemplaza trigger; B3 sin lock_timeout propio | Límites efectivos, ventana, vigilancia y aborto limpio |
| Herramientas externas que insertan/borran perfiles | Medio | B3 retira permisos cliente; no se inventarían consumidores inexistentes | Inventario de consumidores y prueba autorizada |
| Inserciones con verificación enviada por clientes | Medio | B4 deniega; es el cambio intencional | Cliente omite esos campos o usa flujo administrativo real |
| Aplicación parcial B3/B4 | Medio | Dos transacciones | Comprobar ledger/catálogos tras cada fallo; no restaurar roles en masa |
| Diferencia de privilegio nombre en baseline antigua | Bajo | Remoto sí tiene UPDATE(nombre), objetivo también | Revalidar permiso efectivo después |
| Ordinales distintos | Bajo/condicional | SQL propio por nombre compatible | Revisar integraciones posicionales externas |
| PG local 17.11 vs remoto 17.6 | Medio | Misma versión mayor; bootstrap Auth/Storage mínimo | Ensayo plataforma representativa, no equivalencia asumida |
| Default grants amplios y MAINTAIN residual | Medio residual | Fuera de las dos correcciones; no se ocultó | Registrar aceptación/seguimiento separado, no ampliar migraciones sin revisar |
| Restauración borra escrituras posteriores | Alto si se usa | Recuperación temporal pierde cambios posteriores al punto | Preferir corrección hacia adelante; RPO aceptado y decisión explícita |

## 8. Plan de comprobaciones posteriores

### Catálogos y preservación

Con lectura de catálogos en una transacción de solo lectura:

- Historial con exactamente las doce versiones; objetos de B3/B4 presentes una vez.
- RLS activo en las cinco tablas objetivo y las otras seis ya auditadas.
- usuarios: authenticated SELECT y UPDATE(nombre), sin UPDATE(rol/id/creado_en), INSERT, DELETE ni privilegios generales retirados; anon sin acceso de tabla. Verificar permisos efectivos, no solo texto de ACL, incluidas posibles membresías heredadas nuevas.
- Cinco tablas sin TRUNCATE/REFERENCES/TRIGGER para anon/authenticated/PUBLIC. No ejecutar esas operaciones destructivas para probarlo: usar `has_table_privilege`.
- Cuatro funciones de trigger sin EXECUTE para clientes; demás helpers/RPC con permisos esperados. Funciones privilegiadas con propietario confiable y search_path vacío.
- Trigger de promoción habilitado para INSERT/UPDATE OF estado, propietario_id; protección de rol y alta de perfil habilitadas.
- Política restrictiva INSERT con la excepción de administrador basada en `es_administrador`.
- Comparar huellas protegidas de filas preexistentes, además de conteos de roles/propiedad/membresía, durante una ventana sin escrituras concurrentes. Las migraciones no deben crear/eliminar perfiles ni cambiar roles.
- Revisar errores de alta Auth, 42501 inesperados, fallos de RPC y bloqueos. Repetir asesor: distinguir helpers SECURITY DEFINER necesarios y staging deliberadamente cerrado de defectos explotables.

Ejemplo de control no destructivo preparado (NO ejecutado después de un despliegue, porque no hubo despliegue):

```sql
begin read only;
select has_column_privilege('authenticated','public.usuarios','nombre','UPDATE') as nombre,
       has_column_privilege('authenticated','public.usuarios','rol','UPDATE') as rol,
       has_table_privilege('authenticated','public.usuarios','INSERT') as alta_directa;
-- Esperado: true, false, false.
select rol, tabla,
       has_table_privilege(rol,tabla,'TRUNCATE') as truncar,
       has_table_privilege(rol,tabla,'REFERENCES') as referenciar,
       has_table_privilege(rol,tabla,'TRIGGER') as crear_trigger
from (values ('anon'),('authenticated')) r(rol)
cross join (values ('public.usuarios'),('public.establecimientos'),
 ('public.solicitudes_establecimientos'),('public.miembros_establecimiento'),
 ('public.promociones')) t(tabla);
-- Todas las capacidades anteriores deben ser false.
select policyname, permissive, cmd, roles, with_check
from pg_policies where schemaname='public'
 and policyname='alta sin verificacion autoconcedida';
commit;
```

### Pruebas HTTP/RLS preparadas para staging

**Estado: especificadas, no ejecutadas.** El GET real de `/auth/v1/settings` confirmó correo habilitado y Google/Azure/Facebook/teléfono deshabilitados; no valida login, entrega de correos/SMS ni autorización. No activar proveedores como parte de este despliegue.

Preparación del entorno: proyecto staging autorizado con Auth, PostgREST y Storage completos; mismas migraciones y configuración relevante; cuentas sintéticas A/B (usuarios), O (propietario), D (administrador), C (colaborador activo), I (inactivo). Autorizaciones iniciales solo por fixture de backend confiable, nunca alterando usuarios reales. Negocios E1 de O aprobado/publicable, E2 pendiente de A, E3 de otro propietario; promociones vigentes y no vigentes; membresías y solicitudes propias/ajenas. Registrar los IDs generados en memoria, no usar IDs de producción.

Obtener sesiones **reales** mediante `POST /auth/v1/token?grant_type=password`, con cuenta de ensayo confirmada. Verificar cada token mediante `GET /auth/v1/user` y su perfil. Tokens firmados por Auth, no JWT inventados, no inyección de request.jwt.claim.sub y no service_role para peticiones bajo prueba. La clave pública va en `apikey`; el access token real en `Authorization: Bearer <sesión>`. No escribir tokens, contraseñas, respuestas Auth ni headers en logs, HAR o comandos visibles. Para anon usar clave pública sin sesión de usuario. Separar clientes HTTP por identidad, sin arrastre de headers.

Los prefijos de endpoints de la tabla son `/auth/v1` y `/rest/v1`. En mutaciones usar `Prefer: return=representation` y luego GET de comprobación. Un 200 con `[]` puede ser denegación por RLS, no una edición exitosa. Un fallo de red, un 404 por recurso ausente o cualquier 4xx no relacionado no demuestran seguridad; comprobar código SQL/PostgREST y el estado persistido. Todos los cuerpos con identidades se completan con los IDs de fixtures, nunca datos reales.

| Caso | Identidad y petición preparada | Aserción requerida |
|---|---|---|
| H01 | Nueva cuenta: POST Auth `/signup`, data con `rol=administrador`, `tipo_cuenta=propietario` | Tras confirmación y sesión válida, GET usuarios devuelve rol usuario y un solo perfil |
| H02 | A: PUT Auth `/user`, cuerpo `{"data":{"rol":"administrador","tipo_cuenta":"propietario"}}`; renovar sesión | GET perfil sigue usuario; RPC es_administrador devuelve false; reabrir app no cambia panel |
| H03 | A: GET REST `/usuarios?select=id,nombre,rol` | Solo su perfil; GET con id de B devuelve [] |
| H04 | A: PATCH REST `/usuarios?id=eq.<A>`, cuerpo `{"nombre":"Ensayo autorizado"}` | 200 y una fila; lectura confirma cambio |
| H05 | A: PATCH perfil con `rol=propietario`, luego `rol=administrador`; ensayos separados con id/creado_en | 403 y SQLSTATE 42501; perfil y rol invariantes |
| H06 | A: POST usuarios con id propio y rol administrador; DELETE propio | Denegación 42501; perfil original continúa presente |
| H07 | A: POST establecimientos con propietario_id=A, categoria_id válida, nombre/dirección, latitud/longitud válidas y defaults pendientes | 201; estado pendiente/no publicable; perfil continúa usuario |
| H08 | A: dos POST de establecimiento, uno con verificado_en y otro con verificado_por; otro con ambos | 403/42501; ningún establecimiento nuevo de esos intentos |
| H09 | A: PATCH E2 para aprobar/publicar/cambiar propietario/verificación, cada campo por separado | Error del trigger P0001 (4xx esperado), sin cambio; nunca aceptar error de formato como prueba |
| H10 | A: POST promoción válida de E2; anon GET E2 y promoción | Escritura privada permitida; anon obtiene [] para ambos |
| H11 | D: PATCH E2 con `{"estado":"aprobado","publicable":true}` | Una fila modificada; A pasa a propietario por aprobación real; D conserva administrador |
| H12 | D: POST establecimiento aprobado con propietario D y verificación válida | 201; verificación admitida; D no se degrada a propietario |
| H13 | B: POST solicitud de acceso a E1 con solicitante B y estado pendiente/defaults | 201; todavía no puede gestionar E1 |
| H14 | B: PATCH su solicitud a aprobada; POST RPC `/rpc/responder_solicitud_establecimiento` con p_solicitud_id, p_estado=aprobada, p_motivo_respuesta="" | PATCH sin filas cambiadas; RPC rechazado por autorización, solicitud sigue pendiente y sin membresía |
| H15 | D: misma RPC para la solicitud de B | Éxito; solicitud aprobada, membresía activa, B propietario; segunda respuesta falla sin duplicar membresía |
| H16 | C/B autorizado: PATCH promoción de E1; O: PATCH nombre de E1 | Una fila efectiva y GET confirma; no basta lives_ok/HTTP 200 vacío |
| H17 | I o usuario ajeno: PATCH promoción/negocio E1; POST promoción ajena | UPDATE filtra cero filas o deniega; INSERT 42501; valores originales intactos |
| H18 | C: PATCH E1 reasignando propietario o aprobación; POST membresía propia en E3 | Trigger/RLS deniega; no se roba propiedad ni se concede membresía |
| H19 | D desactiva membresía de C; C reutiliza el mismo access token | Pierde gestión inmediatamente según datos RLS; puede conservar lectura pública y su rol global |
| H20 | Anon GET negocios/promociones vigentes, pendientes y vencidas; GET usuarios | Solo contenido aprobado/publicable/vigente; perfiles denegados 42501 (401 para anon o 403 según capa) |
| H21 | GET de perfil con JWT inválido o vencido | 401; sin filas; no considerar este caso sustituto de RLS con sesión válida |
| H22 | O agrega categoría principal permitida de E1 | Trigger sincroniza categoría pese a EXECUTE cliente revocado; sin elevación de rol |
| H23 | O/D RPC de reemplazo de horarios; C activo e I inactivo sobre E1 | Flujo legítimo preservado, inactivo no altera horarios; comprobar filas posteriores |
| H24 | C activo gestiona objeto de Storage de E1; usuario ajeno intenta misma ruta | Acceso por propiedad/membresía, ajeno denegado; probar reemplazo con INSERT+SELECT+UPDATE y lectura pública según políticas |

No usar RPC de prueba, RLS deshabilitado, service_role ni superusuario para fabricar un resultado positivo de las peticiones anteriores. El backend de fixtures solo prepara identidades/autorizaciones y observa invariantes. La limpieza se limita a fixtures de staging y requiere autorización de ese entorno; no se preparó una limpieza destructiva sobre producción.

Criterio de salida: todos los casos ejecutados con resultado persistido esperado, sin secretos en la evidencia. Registrar caso, identidad lógica, status HTTP, código SQL/PostgREST y aserción, nunca credenciales. Casos de OAuth/SMS quedan pendientes mientras los proveedores estén deshabilitados; no son requisito para afirmar que este cambio de RLS funciona con el método correo realmente ensayado.

Después del despliegue futuro, repetir lectura de catálogos y smoke HTTP con cuentas/recursos de ensayo previamente autorizados. Ninguna escritura contra cuentas reales está autorizada por este plan.

## 9. Recuperación propuesta, sin ejecutar

- Fallo antes de COMMIT: transacción revierte DDL; confirmar ledger y objetos, no asumir que una desconexión equivale a rollback.
- B3 aplicado y B4 fallido: conservar B3 y resolver el fallo; las migraciones son repetibles, pero la decisión depende de catálogo/historial real. No restaurar masivamente roles ni reactivar el trigger inseguro de promoción de pendientes.
- Incompatibilidad posterior: detener el flujo afectado, reunir errores sin datos sensibles y preferir una migración correctiva mínima ensayada. No reabrir TRUNCATE ni UPDATE(rol) para ocultar errores del cliente.
- Recuperación completa: solo con una copia restaurable ya acreditada y autorización separada. Elegir punto previo, evaluar escrituras posteriores que se perderían, ventana y responsables; ensayar en destino separado y validar Auth, ACL, RLS y Storage antes de cualquier cambio de tráfico. No asumir que el respaldo SQL contiene los objetos binarios ni todos los ajustes del proyecto.
- No reset, no borrado de usuarios/negocios, no restauración automática, no desactivación de RLS y no reparación manual del historial como parte de este bloque.

## 10. Resultado de esta sesión y condiciones GO

**Ejecutado:** revisión de informes/migraciones; identidad y estado Git; consulta remota de diez versiones; comparación de catálogos con reconstrucción local; conteos agregados de compatibilidad; consulta real de backups; GET Auth settings; ejecución SQL local **170/170**, incluyendo reaplicación y conservación exacta de perfiles sintéticos. No se repitió Flutter en este bloque: su cierre anterior documenta analyze sin incidencias y 118 pruebas aprobadas/8 omitidas.

**No ejecutado:** despliegue, cambio remoto alguno, login real, pruebas HTTP con escritura, restauración, creación de backup o staging, verificación de consumidores externos y aceptación de RPO/RTO. No se comprobó recuperabilidad por promesa ni se confundió el contenedor de fixtures con una copia de producción.

Para reconsiderar GO deben existir: (1) respaldo y evidencia de recuperación, (2) staging HTTP/RLS aprobado, (3) revisión/decisión sobre los dos indicadores de compatibilidad, (4) conexión y procedimiento de release ensayados con límites efectivos, (5) catálogo/historial/huellas frescos sin diferencias nuevas, y (6) autorización explícita de despliegue. Hasta entonces: **NO-GO**.

## 11. Intento de desbloqueo: respaldo lógico y recuperación

Esta sección corresponde a la continuación solicitada después del predespliegue.
Las consultas remotas y las 170 pruebas descritas en secciones anteriores son
**evidencia de la sesión anterior**, no nuevas ejecuciones de esta continuación.
Se mantiene `develop` en `0dd874b`.

### Documentación actual revisada

La documentación oficial recomienda exportaciones lógicas y copias externas
para proyectos Free. Los respaldos diarios gestionados corresponden a planes
Pro/Team/Enterprise; PITR es una opción adicional de planes compatibles.
No se cambió el plan ni se activó un servicio facturable. La respuesta anterior
de backups vacíos/PITR deshabilitado no se volvió a consultar en esta continuación.
[Supabase: Database Backups](https://supabase.com/docs/guides/platform/backups).

La recuperación lógica documentada requiere conexión PostgreSQL y su credencial.
Hay consideraciones específicas para historial de migraciones, personalizaciones
de Auth/Storage y claves de cifrado de Vault/columnas. El acceso a Management API
no acredita por sí mismo la conexión que necesita pg_dump. No se siguió ninguna
sugerencia de restablecer contraseñas: está prohibido para esta tarea.
[Supabase: Backup and Restore using CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).

### Bloqueo comprobado y punto de detención

Se consultó únicamente `supabase db dump --help` de CLI 2.119.0; admite proyecto,
conexión explícita, contraseña y archivo de salida. No se invocó el dump ni
`--dry-run`, que puede imprimir el script con parámetros de conexión.

Inspección local de disponibilidad, sin imprimir valores:

- Ausentes PGHOST, PGPORT, PGUSER, PGPASSWORD, PGPASSFILE, PGSERVICE y PGSERVICEFILE.
- Ausentes DATABASE_URL, SUPABASE_DB_URL y SUPABASE_DB_PASSWORD.
- No existen `~/.pgpass` ni `~/.pg_service.conf`.
- No existen los archivos de enlace `supabase/.temp/project-ref` y `pooler-url`.
- `config/supabase.local.json` no contiene campos identificados de acceso
  PostgreSQL. No se mostraron sus valores. Tampoco se encontraron los archivos
  convencionales `.env`, `.env.local` o `supabase/.env` en las rutas revisadas.

Esto demuestra que **no se ha localizado una conexión PostgreSQL utilizable en
los mecanismos revisados**, no que nadie disponga de ella ni que no pueda existir
en otro gestor autorizado. No se probaron contraseñas, no se buscaron secretos
por todo el equipo y no se creó un rol/login temporal para eludir la restricción.
No se probó conectividad ni permisos efectivos de exportación: falta el acceso
necesario para realizar esa comprobación de forma fiable.

Se respeta la instrucción: «Si crear un respaldo verificable requiere permisos o
información no disponibles, no improvises. Detente en ese punto y documenta el
bloqueo». No se sustituyó el respaldo por consultas JSON del conector, lecturas
REST parciales, logs ni fixtures locales. Esos medios no acreditan un archivo de
recuperación completo, un snapshot común y la preservación de Auth/ACL.

**No existe un nuevo artefacto de respaldo en esta continuación.** No hay ruta de
backup, tamaño, hash, cobertura efectiva ni restauración aprobada que informar.
No se extrajeron hashes de contraseñas, sesiones, tokens ni datos personales.

### Diseño de respaldo consistente, pendiente de ejecución

Cuando exista acceso válido, la autorización para intentar el respaldo y la
restauración local ya está expresada por el usuario; falta el acceso técnico,
no volver a decidir la arquitectura. Proporcionar una conexión existente por un
mecanismo protegido fuera del repositorio —por ejemplo, servicio libpq y passfile
con modo 0600— y comunicar únicamente el nombre del servicio/ruta. No pegar
contraseñas ni cadenas de conexión en el chat. Debe corresponder al proyecto
Cercly y permitir leer todos los objetos incluidos, sin resultados filtrados por
RLS. Si falla un permiso, detener el dump; no crear roles ni ampliar grants en
producción para resolverlo sin autorización adicional.

Diseño técnico propuesto, **no ejecutado**:

1. Validar servidor, versión y privilegios por conexión TLS directa o pooler de
   sesión, con parámetros oficiales del proyecto; no inventar hostname de pooler.
   Usar herramientas PostgreSQL 17 compatibles y conexión de solo lectura.
2. Exportar esquema y datos de la base en **un único pg_dump en formato custom**,
   con un snapshot consistente. No afirmar consistencia global por ejecutar
   varios dumps independientes de esquema/datos/Auth mientras hay escrituras.
   Si hubiera que separar archivos, usar un snapshot exportado compartido con
   la sesión exportadora viva y validar su compatibilidad con la conexión.
3. Inventariar primero todos los esquemas no de sistema y dependencias. Cobertura
   mínima exigida: public, auth completo, storage (metadatos), staging e historial
   supabase_migrations; funciones, triggers, políticas RLS, ACL, secuencias, enums,
   índices y constraints. Incluir/revisar esquemas y dependencias de extensiones
   presentes (por ejemplo extensions, realtime, vault) según su inventario real.
   No excluir silenciosamente un esquema administrado para que el comando termine.
4. Guardar por separado definiciones necesarias de roles/membresías sin hashes de
   contraseñas de roles de servidor. pg_dump no incluye objetos globales de clúster.
   Documentar consistencia y cualquier cambio concurrente de DDL/grants; coordinar
   una ventana sin cambios de esquema. No confundir esas contraseñas excluidas con
   los hashes de usuarios de Auth, que sí son parte sensible de auth.users.
5. Guardar exclusivamente fuera del repositorio, en un directorio persistente
   dedicado modo 0700, archivos 0600 y umask 077. No usar un archivo compartido en
   /tmp para datos reales. Acreditar almacenamiento cifrado o un destinatario de
   cifrado antes de custodiar material Auth; no inventar ni versionar una clave.
   Escribir el archivo directamente, sin pasar datos por la salida de herramientas.
   Errores detallados y TOC también son privados; al informe solo pasan resultados
   agregados. Permisos restrictivos no equivalen a cifrado.
6. Exigir código de salida exitoso, archivo no vacío, hash SHA-256 y lectura de TOC
   completa mediante pg_restore. Verificar presencia de esquemas/tablas/datos
   requeridos sin mostrar su contenido. El hash y el TOC prueban integridad de
   transporte/estructura, no recuperabilidad por sí solos.
7. Restaurar en PostgreSQL aislado nuevo, sin red/salida a SMTP, SMS, webhooks ni
   servicios reales; almacenamiento y logs restringidos. Preparar versiones de
   extensiones y roles necesarios sin reutilizar credenciales productivas.
   Fallar ante errores no explicados; comprobar FK, conteos/invariantes, roles,
   triggers, funciones y ACL. No habilitar jobs ni ejecutar funciones que puedan
   activar conexiones externas. No restaurar sobre un clúster del usuario existente.
8. Registrar alcance, exclusiones, tiempos reales de exportación/restauración,
   resultado y prueba de recuperación. No declarar RPO/RTO medidos antes del ensayo.
   Conservar el original inmutable; cualquier adaptación al destino se realiza en
   una copia separada, documentada y sin relajar silenciosamente controles.

El snapshot de pg_dump cubre una base; roles globales requieren tratamiento
separado. El inventario debe confirmar permisos y extensión del archivo antes de
atribuirle cobertura completa. [PostgreSQL 17: pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html).

### Cobertura prevista frente a lo que no cubre

**Cobertura efectiva hoy: ninguna copia nueva creada.** La cobertura anterior es
un requisito de diseño, no una afirmación de datos ya respaldados.

Un respaldo lógico de la base no basta para recuperar objetos binarios de Storage,
configuración de proveedores OAuth/SMTP/SMS, callbacks y URL settings, secretos de
Edge Functions, código externo no versionado, DNS, claves de firma/API y claves
externas de cifrado. El cifrado presente en Vault/columnas requiere su material de
clave original, custodiado por separado; copiar ciphertext no acredita capacidad
de descifrado. No se extrajo ese material ni se modificaron credenciales.

Las sesiones/tokens/hashes contenidos en Auth son material sensible incluso en un
archivo local. El ensayo de recuperación de datos reales debe permanecer separado
del entorno HTTP de fixtures: no iniciar sesión como usuarios reales ni reutilizar
sus tokens. Las pruebas funcionales usan cuentas sintéticas creadas en el entorno
aislado y claves de firma exclusivas de ese entorno.

### Estado de las restantes actividades al detenerse

| Actividad de esta continuación | Estado real |
|---|---|
| Lectura de informes B3/B4/predespliegue y Git | Ejecutada |
| Consulta de documentación oficial y ayuda de dump | Ejecutada |
| Disponibilidad de conexión PostgreSQL | Revisada; no localizada en mecanismos comprobados |
| Respaldo lógico / integridad / restauración aislada | **No ejecutados por bloqueo** |
| Revisión de los 24 casos HTTP/RLS | Leídos; siguen especificados en sección 8 |
| Ejecución de esos casos con Supabase Auth real | **No ejecutada**; no se sustituyó por pgTAP |
| Investigación adicional de las dos cuentas | **No ejecutada**, por detención solicitada; conteos anteriores no se presentan como nuevos |
| Nueva ejecución de asesores y revisión remota de permisos | **No ejecutada**, por detención solicitada |
| Repetición de SQL/Flutter | No ejecutada; resultados anteriores conservan su fecha/alcance |
| Migraciones, cambios de cuentas/credenciales, restauración remota | No ejecutados |

La investigación pendiente de cuentas deberá devolver solo categorías y conteos
agregados: tipo de identidad/confirmación y estado del trigger para el perfil
faltante; propiedad por estado, membresías inactivas y solicitudes aprobadas para
el propietario sin acceso activo. No registrar emails, UUID, fechas exactas de
actividad, hashes identificables ni atribuir una causa histórica sin evidencia.
No modificar cuentas para hacer desaparecer el indicador.

**Decisión actual: NO-GO.** Para retomar hace falta acceso PostgreSQL existente y
protegido, con alcance de lectura suficiente, y custodia segura para el archivo.
Después deberán completarse el respaldo verificable, la recuperación aislada,
los 24 casos HTTP y las revisiones pendientes. No se creó ningún commit ni se hizo
push; no se tocó producción.
