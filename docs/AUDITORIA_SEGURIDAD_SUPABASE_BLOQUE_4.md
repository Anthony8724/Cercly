# Bloque 4 — Auditoría de seguridad de Supabase

Fecha de sesión: 17 de octubre de 2026, America/Guayaquil (18 de octubre UTC al crear la migración). Base: `develop`, `33892f113594055b94a7d3744e82d5ede9392982`.

**Resultado: correcciones locales probadas; despliegue pendiente de revisión y autorización.** No se aplicaron migraciones remotas, no se consultaron filas de usuarios reales, no se modificaron datos ni credenciales, y no se hicieron commits ni push durante la auditoría inicial. El cierre local autorizado se documenta más abajo. `README.md.respaldo` se mantuvo intacto.

## Alcance y evidencia remota

Se usó la conexión autorizada de Supabase, exclusivamente para listar proyectos/migraciones, consultar el asesor de seguridad y leer catálogos PostgreSQL en transacciones `BEGIN READ ONLY`. Proyecto Cercly: `aimubazregckmjchnszf`; PostgreSQL remoto `17.6.1.166`.

El historial remoto contiene estas diez versiones, presentes también en el repositorio:

```text
20260912000438 remote_schema
20260912001054 storage_buckets
20260912005223 categorias_iniciales
20260912024346 guardar_horarios_establecimiento
20260912043748 gestionar_solicitudes_establecimiento
20260912061744 permitir_storage_a_colaboradores
20260913010000 modelo_osm_postgis
20260913060000 refinar_taxonomia_osm
20260914010000 busqueda_establecimientos
20260914120000 corregir_reclamo_establecimiento_osm
```

**No figuran** `20261017233138_fortalecer_acceso_perfiles` ni `20261018000337_validar_seguridad_acceso`.

Se revisaron `pg_policies`, funciones propias de `public` (definiciones, propietarios, ACL y SECURITY DEFINER), triggers, privilegios de tabla/columna, RLS y roles de acceso. Las once tablas de aplicación tienen RLS activo. `anon` y `authenticated` no tienen LOGIN, SUPERUSER, BYPASSRLS, membresías heredadas ni CREATE en `public`. `service_role` sí tiene BYPASSRLS, como corresponde a una identidad exclusivamente de servidor. La única concesión explícita de columna en `usuarios` es UPDATE(nombre) a `authenticated`.

Esto no constituye una comparación exhaustiva de todo el esquema remoto ni una auditoría de datos históricos, configuración de JWT, Edge Functions o secretos de infraestructura.

## Hallazgos y decisiones

| Prioridad | Hallazgo | Evidencia y resolución |
|---|---|---|
| Alta | El trigger remoto promueve al creador de cualquier establecimiento, incluso pendiente. | Definición remota confirmada. Bloque 3 limita la promoción a `estado = aprobado`; las solicitudes aprobadas por un administrador conservan su promoción mediante RPC. Pruebas locales del pendiente y de la aprobación satisfactorias. Sigue pendiente desplegar Bloque 3. |
| Media | Un cliente puede insertar `verificado_en` y `verificado_por` en un establecimiento Cercly pendiente. | Reproducido con `SET ROLE authenticated`: antes de la corrección la inserción no falla. No concede por sí sola rol administrador ni publicación, pero falsifica atribución de verificación. Nueva política restrictiva de INSERT exige ambos campos nulos salvo administrador real. |
| Media, defensa adicional | `anon`/`authenticated` tienen TRUNCATE y otros privilegios de tabla innecesarios. | Catálogos remotos y ensayo local. RLS no protege TRUNCATE. No se ejecutó TRUNCATE ni se encontró una RPC que lo exponga a un cliente REST. Bloque 3 ya revoca estos permisos en perfiles; Bloque 4 revoca TRUNCATE, REFERENCES y TRIGGER en las cinco tablas auditadas. |
| Baja, defensa adicional | Funciones de trigger SECURITY DEFINER tienen EXECUTE público. | Bloque 3 revoca tres; Bloque 4 revoca `sincronizar_categoria_principal()`. Una función `RETURNS trigger` no se convierte automáticamente en una RPC invocable por tener EXECUTE. No se ha demostrado elevación por esta vía. |
| Pendiente externo | El asesor informa protección contra contraseñas filtradas deshabilitada. | Revisar disponibilidad/configuración del proyecto antes de activarla. No se modificó Auth. |

La corrección se agrega como una migración nueva, generada mediante Supabase CLI. No se reescriben las diez migraciones desplegadas ni la del Bloque 3 ya publicada en Git. Las correcciones no actualizan filas existentes.

La política nueva es **restrictiva**, de modo que se combina con AND con las políticas permisivas existentes. Una política permisiva adicional no neutraliza la restricción. Los administradores mantienen la posibilidad de crear una verificación explícita.

Se conservan SELECT y las operaciones DML requeridas por las políticas existentes. Revocar indiscriminadamente SELECT sobre `miembros_establecimiento` podría romper subconsultas de RLS, incluida la lectura pública de categorías asociadas.

## Revisión por recurso

| Recurso | Autorización y límites comprobados |
|---|---|
| `usuarios` | Alta por trigger con rol fijo `usuario`; no se copia `rol` ni `tipo_cuenta` de metadatos. Nombre OAuth/telefonía funciona. Lectura propia o administrativa; cliente solo puede actualizar nombre. INSERT directo, identidad, rol y fecha protegidos por privilegios. No hay escritura de roles desde Flutter en el flujo revisado. |
| `establecimientos` | Un usuario puede preparar su borrador pendiente. Eso no concede el rol global de propietario tras Bloque 3. Propietario/colaborador puede editar campos comerciales, pero el trigger protege propietario, estado, publicación, procedencia, reclamo y verificación. Publicación requiere administrador. INSERT con verificación falsificada queda bloqueado por Bloque 4. |
| `solicitudes_establecimientos` | Alta propia pendiente sin respuesta ni revisor. UPDATE directo reservado al administrador. La RPC comprueba sesión y rol en base de datos antes de operar; bloquea solicitud/establecimiento con FOR UPDATE y rechaza una segunda respuesta. Solicitud pendiente no concede acceso. |
| `miembros_establecimiento` | Gestión de membresías reservada al administrador global. El solicitante no se puede agregar a sí mismo. Miembro activo puede gestionar el establecimiento asignado; inactivo pierde esa autorización. El rol de miembro llamado `administrador` no equivale al rol global administrador. |
| `promociones` | Solo propietario, colaborador activo del establecimiento o administrador puede gestionar. Lectura pública exige promoción activa/vigente y establecimiento aprobado/publicable. Se conserva la preparación privada de promociones de borradores; no se publican mientras el negocio siga pendiente. |

Las políticas otorgan gestión por propiedad o membresía concreta, no por poseer únicamente el rol global `propietario`. Conservar ese rol tras perder una membresía no concede acceso a negocios ajenos. Los propietarios históricos mantienen sus filas/rol; no se intentó distinguir automáticamente cuáles fueron promovidos por el trigger antiguo. Una revisión histórica posterior requiere autorización y criterios caso por caso.

Los administradores mantienen lectura administrativa, aprobación de establecimientos, resolución de solicitudes y gestión de miembros. No se concede a un administrador cliente UPDATE(rol) general: los cambios de rol pasan por código de confianza. Esto ya concuerda con los privilegios remotos actuales (UPDATE solo sobre nombre).

## Triggers, RPC y dependencias

- `crear_perfil_nuevo_usuario`: SECURITY DEFINER, propietario `postgres`, search_path vacío. Ignora metadatos de privilegios. Bloque 3 añade nombres OAuth y tolerancia al conflicto de ID. No sincroniza roles desde futuras modificaciones de metadatos.
- `proteger_rol_usuario`: SECURITY INVOKER. Bloquea cambios directos de identidad/rol cuando current_user es `anon` o `authenticated`. En la RPC administrativa SECURITY DEFINER se ejecuta como su propietario de confianza; esa excepción es necesaria para aprobar solicitudes. Debe mantenerse restringida la capacidad de crear/modificar funciones privilegiadas.
- `convertir_en_propietario`: Bloque 3 reemplaza el trigger de solo INSERT por INSERT/UPDATE OF estado, propietario_id. Solo promueve `usuario`, nunca degrada administrador ni reescribe roles históricos al desplegar.
- `responder_solicitud_establecimiento`: versión corregida `20260914120000`, comprobación de administrador basada en `usuarios`; concesión EXECUTE solo a authenticated/servidor. Reclamo y acceso aprobados promueven al solicitante; corrección no cambia automáticamente el negocio. Las pruebas existentes de reclamo se complementan con casos bajo el rol SQL authenticated.
- `es_administrador`, `puede_gestionar_establecimiento`, `puede_gestionar_ruta_storage`: SECURITY DEFINER con search_path vacío, sin SQL dinámico. Sus respuestas dependen de auth.uid y datos autorizados. Se conservan los permisos de ejecución requeridos por RLS; las alertas del asesor sobre ellas no son evidencia de explotación.
- Horarios y búsqueda geográfica: SECURITY INVOKER; operan bajo RLS. No se encontró una RPC pública genérica para ejecutar SQL o asignar roles arbitrariamente.
- Staging: RLS sin políticas y permisos revocados a clientes es un cierre deliberado, no una falta de política que deba corregirse abriendo acceso.

La migración B3 depende de los roles SQL de Supabase, `usuarios`, el enum de rol, el trigger de protección ya instalado y la tabla/estado de establecimientos. B4 depende además de los campos de verificación del modelo OSM y las funciones/políticas anteriores. El ensayo reprodujo todas las migraciones en orden.

B4 usa transacción y `lock_timeout = 5s`. B3 también usa transacción, pero no establece timeout: al desplegar debe fijarse un límite en la conexión y elegir una ventana breve. La sustitución de trigger necesita bloqueo DDL. No hay escaneo/reescritura masiva de filas ni normalización de roles. Ambas migraciones se reaplicaron localmente sin error y sin alterar perfiles de prueba existentes.

## Pruebas ejecutadas

Alternativa disponible: Podman rootless con la imagen local de Supabase PostgreSQL **17.11**, sin puertos publicados, `--network none`, sin montajes del proyecto y sin descargar datos remotos. Imagen fijada por digest en el ejecutor. PostgreSQL remoto es 17.6: queda pendiente repetir en staging con la versión/plataforma exactas.

El bootstrap de `scripts/sql/security_platform_bootstrap.sql` completa solamente las columnas Auth y tablas/función de Storage necesarias sobre la imagen base. No instala GoTrue, PostgREST ni el servicio Storage completo. Los casos de autorización cambian a `authenticated`/`anon`; no simulan JWT firmados ni peticiones HTTP. El CSV OSM es el fixture ya versionado, no una copia de la base remota.

Reproducción:

```bash
python3 scripts/test_supabase_security_local.py
```

Requiere Podman y la imagen fijada disponible localmente. No recibe URL, clave ni nombre de contenedor existente. Crea un contenedor con nombre aleatorio, espera al servidor definitivo, aplica el esquema, guarda evidencia en `/tmp/cercly-security-results-*`, valida planes TAP completos y detiene únicamente su propio contenedor. `--rm` elimina ese contenedor de prueba.

Ejecución final: `/tmp/cercly-security-results-sbemwv4s`.

| Suite | Resultado |
|---|---:|
| `auth_access_test.sql` (original, sin modificaciones) | 11/11 |
| `security_access_test.sql` (nueva) | 57/57 |
| `consulta_establecimientos_cercanos_test.sql` | 19/19 |
| `importacion_osm_tulcan_test.sql` | 17/17 |
| `modelo_osm_postgis_test.sql` | 18/18 |
| `promover_osm_establecimientos_test.sql` | 28/28 |
| `reclamar_establecimiento_osm_test.sql` | 17/17 |
| `refinar_taxonomia_osm_test.sql` | 3/3 |
| **Total** | **170/170** |

Además: reaplicación de B3/B4 dos veces sobre perfiles preexistentes sintéticos de administrador, propietario y usuario; comparación exacta de filas antes/después aprobada. Compilación sintáctica del ejecutor Python y revisión de espacios finales aprobadas; `git diff --check` sin errores. No se cambió Flutter. Sus validaciones se repitieron durante el cierre documentado abajo.

Las once comprobaciones originales cubren perfiles, metadatos, grants y aislamiento, pero por sí solas no comprobaban aprobación, membresías ni inserciones con campos de verificación. La suite nueva agrega esos escenarios, clientes anónimos, promociones privadas/públicas, RPC, revocación de membresía y privilegios de tabla/función.

Fallos intermedios resueltos: tres suites OSM carecían de carga de fixtures/funciones auxiliares; tras preparar las dependencias pasan. El ejecutor inicial detectó el servidor temporal de arranque: ahora espera al servidor TCP definitivo. Antes de B4 la suite nueva reprodujo nueve fallos de seguridad: inserción de verificación y ocho concesiones TRUNCATE innecesarias; tras B4 pasan. No se ocultan esos fallos como verificaciones exitosas previas a la corrección.

## Despliegue propuesto, pendiente de autorización

1. Revisar el diff y confirmar que el historial remoto aún termina en `20260914120000`. No asumir que este informe representa un estado remoto futuro. Revisar de nuevo triggers, funciones, grants y políticas si hubo cambios externos.
2. Capturar respaldo autorizado del esquema, ACL/políticas/funciones y un respaldo recuperable de datos conforme al proceso del proyecto. No extraer datos sensibles a logs. Confirmar propietarios `postgres`, sin grants de columna o membresías nuevas que eludan restricciones.
3. Ejecutar el ensayo en staging representativo de la plataforma remota; validar con cuentas de prueba las operaciones HTTP de alta, edición de nombre, aprobación, solicitud, colaboración y lectura pública. No correr las suites con fixtures sobre producción.
4. Aplicar exclusivamente B3 y luego B4, con revisión previa del listado pendiente, límites de espera y ventana de mantenimiento. Evitar un `db push` indiscriminado que incluya otras migraciones. No ejecutar scripts de staging/importación/pruebas locales sobre remoto.
5. Verificar versiones registradas, ACL resultantes, política restrictiva, triggers habilitados y ausencia de cambios en roles existentes. Validar un alta de prueba autorizada y aprobación con cuentas de ensayo; revisar errores 42501, altas Auth y bloqueos.
6. Repetir el asesor. Mantener justificadas las alertas de helpers SECURITY DEFINER que implementan RLS; revisar aparte protección de contraseñas filtradas. No abrir staging para eliminar una alerta.

## Reversión y contención

Si falla una transacción de migración, PostgreSQL revierte sus DDL; B3 y B4 son transacciones separadas. Si falla B4 después de confirmar B3, conservar B3 y resolver el bloqueo/fallo antes de reintentar B4. No intentar compensar modificando roles.

Si surge una incompatibilidad después del despliegue, detener el flujo afectado y preparar una **migración correctiva nueva** con el cambio mínimo sobre la política/ACL implicada. La política restrictiva solo afecta nuevas inserciones; permitir que clientes omitan los campos de verificación es la primera corrección de compatibilidad a evaluar. Restaurar una definición concreta desde el respaldo únicamente tras revisión y nueva autorización.

No se incluye un rollback automático que reactive la promoción de pendientes, reabra TRUNCATE o conceda UPDATE(rol). Volver al esquema anterior completo reintroduce vulnerabilidades. No usar reset de base, borrar usuarios, quitar RLS, alterar versiones del historial ni rebajar roles en masa. Si fuera imprescindible revertir exactamente una definición, hacerlo con una migración compensatoria auditada, medidas temporales de contención y pruebas en staging; nunca borrar escrituras legítimas realizadas después del despliegue.

## Pendientes y límites

- Despliegue remoto de B3/B4 y verificación posterior: **no ejecutados**.
- Pruebas HTTP integradas de Auth, OAuth/SMS, Storage y versión remota exacta: **no ejecutadas**.
- Revisión de datos históricos (roles antiguos, verificaciones existentes) y carreras concurrentes de aprobación: **no ejecutadas**. La revisión estática comprobó los bloqueos del RPC, no su comportamiento bajo carga.
- Los privilegios excesivos de tablas fuera de las cinco solicitadas y los default privileges para tablas futuras requieren otra revisión de alcance; esta corrección no afirma endurecer todo Supabase.
- La conservación probada cubre fixtures representativos y las reglas revisadas, no una certificación de cada cuenta real. No se consultaron perfiles reales para esa conclusión.

## Referencias

- [Supabase: RLS y metadatos editables](https://supabase.com/docs/guides/database/postgres/row-level-security).
- [PostgreSQL 17: RLS, políticas restrictivas y operaciones no cubiertas](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).
- [PostgreSQL 17: REVOKE y privilegios de columna](https://www.postgresql.org/docs/17/sql-revoke.html).
- [Supabase: alertas de funciones SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- [Supabase: protección de contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- Changelog de Supabase consultado en la copia local de esta sesión; sin cambio de dependencias por esta auditoría.

## Cierre local del Bloque 4

Se revisaron los cinco archivos nuevos, partiendo de `develop` en `33892f1`.
La revisión mantuvo la migración y las 57 comprobaciones nuevas sin cambios.
Se corrigió el ejecutor para rechazar explícitamente salidas sin plan TAP o
con plan vacío; seis casos de comprobación del validador pasaron, incluyendo
salidas truncadas, duplicadas y fallidas.

Validaciones repetidas antes del commit:

- Las doce migraciones se ejecutaron en orden desde un contenedor limpio;
  B3 y B4 se reaplicaron y conservaron exactamente los tres perfiles
  sintéticos preexistentes (administrador, propietario y usuario).
- SQL: **170/170** comprobaciones aprobadas. Evidencia de esta repetición:
  `/tmp/cercly-security-results-2v6_x2v9`.
- `flutter analyze`: **sin incidencias**; registro
  `/tmp/cercly-b4-close-analyze.log`.
- `flutter test --reporter expanded`: **118 aprobadas, 8 omitidas, 0 fallidas**;
  registro `/tmp/cercly-b4-close-test.log`. Las ocho omitidas son pruebas de integración sin configuración de Supabase; no se cuentan como aprobadas.
- `git diff --check` y revisión de espacios finales de archivos nuevos:
  sin errores.
- Revisión manual y búsqueda de patrones de claves privadas, JWT, tokens y
  URLs con credenciales: no se encontraron secretos reales. La contraseña
  fija del ejecutor es únicamente para el contenedor efímero sin red; los
  correos `.test` y UUID de las pruebas son sintéticos. El identificador de
  proyecto del informe no es una credencial.

Se prepara un commit exclusivamente con los cinco archivos del Bloque 4.
No se modifica el historial previo ni se incluye `README.md.respaldo`
(SHA-256 `53df3e7810dff02c9850a6d18c0d501bc20b7a5d071012ce7594186db9774044`).
No se hace push, no se despliegan migraciones remotas y no se modifican
usuarios ni datos reales. Los límites y pendientes de staging/HTTP descritos
arriba siguen vigentes.
