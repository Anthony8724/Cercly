# Comparación de esquemas restaurados — 2026-11-07

Diagnóstico exclusivamente local; sin conexiones a STAGING o Production, exportaciones nuevas, migraciones ni cambios del respaldo original. No se corrigieron ACL ni propietarios en el destino para aparentar equivalencia. La aplicación de definiciones archivadas de roles forma parte del procedimiento de restauración existente.

## Evidencia real

Nuevo ensayo diagnóstico: `20261107T170758Z-cdaf959c`, PostgreSQL 17.11 en contenedor nuevo con NetworkMode=none. pg_restore terminó con salida 0. El procedimiento se detuvo intencionalmente tras la comparación de esquemas; no continuó con validación completa.

Informe saneado fuera de Git: `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/schema-diagnostic-20261107T170758Z-cdaf959c.json`.

Detalle íntegro cifrado (incluye los catálogos, roles y membresías): `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/restore-diagnostic-20261107T170758Z-cdaf959c-schemas.gpg`. La frase solo existió en memoria durante el ensayo.

Resultados:

- 13 esquemas originales y 13 restaurados; ninguno faltante ni adicional.
- Cero propietarios de esquema distintos.
- Dos esquemas con grants realmente diferentes: `graphql` y `graphql_public`.
- Dos esquemas con diferencia exclusivamente de representación; sus nombres no se exponen aquí porque el detalle completo ya está protegido en el diagnóstico cifrado.
- Contexto global de roles/membresías: NO coincide completamente. Falta desglosar esa diferencia; este diagnóstico no la atribuye a un rol concreto.
- Propietario original de la base: no consta en snapshot-catalog.json. El pseudo-rol pg_database_owner depende de ese dato, no solamente de pg_auth_members. No inferir equivalencia completa a partir del nombre del pseudo-rol.
- Las 24 versiones/nombres del catálogo de migraciones restaurado coinciden con el inventario archivado. No se aplicó ninguna migración nueva.

## Atributos exactos distintos

La siguiente lista se aplica a AMBOS esquemas `graphql` y `graphql_public`:

| Privilegio original ausente en destino | Concedido por | Con opción de conceder |
|---|---|---|
| USAGE a anon | supabase_admin | No |
| USAGE a authenticated | supabase_admin | No |
| USAGE a service_role | supabase_admin | No |
| USAGE a postgres | supabase_admin | Sí |

Son ocho entradas ausentes en total. No hay entradas adicionales en esos esquemas ni cambio de propietario. La proyección de USAGE/CREATE también difiere para ambos bajo el grafo LOCAL restaurado. Esa proyección no se presenta como una lectura histórica del acceso efectivo original: primero deben conciliarse los atributos/membresías y el propietario original de base.

Esto afecta el contrato de permisos de acceso a GraphQL y la opción de volver a conceder USAGE de postgres. No es únicamente el orden de un array. No hay evidencia en este informe de un exceso de permisos de esquema; la diferencia concreta es ausencia de grants originales, mientras el contexto global de roles aún requiere revisión.

## Causa comprobada y evidencia pendiente

El comparador anterior hacía igualdad literal de listas y nspacl::text. Esa representación puede diferir por orden de entradas o por ACL nula (default) frente a explícita equivalente. Se confirmaron dos diferencias de representación sin cambio de grants y dos diferencias reales independientes.

El procedimiento que ya ejecutó pg_restore sin --no-acl NO reconstituyó las ocho concesiones de los esquemas GraphQL administrados por Supabase. Reaplicar roles/membresías no es lo mismo que restaurar ACL de esquemas. La evidencia identifica el estado resultante y el componente de recuperación afectado; NO identifica todavía si las instrucciones ACL fueron omitidas del archivo por pertenencia a extensión/privilegios iniciales o si otro detalle del entorno administrado influyó. Se necesita inspeccionar el TOC y el SQL de esquema del archivo existente antes de atribuir la omisión al formato de backup o prescribir un parche definitivo.

No se ignorarán los esquemas de GraphQL por ser gestionados, ni se aceptará automáticamente que el destino sea más restrictivo. Tampoco se ejecutan GRANT/ALTER SCHEMA por suposición. Una eventual corrección debe reconstruir únicamente los grants archivados con el mismo grantor, destinatario, privilegio y grant option, y demostrar igualdad del catálogo y del contexto de roles después. No requiere modificar bases remotas ni cambiar la lógica comercial.

Clasificación:

- Comparador: corregido para normalizar representación sin descartar diferencias reales.
- Procedimiento de recuperación: requiere revisión de cobertura ACL de objetos gestionados por Supabase; no se corrigió el destino real todavía.
- Propietarios de esquema: no requieren corrección según esta evidencia (todos coinciden).
- Roles/membresías y contexto del propietario de base: pendientes antes de afirmar equivalencia de seguridad.

## Implementación local

`scripts/comparar_esquemas_respaldo.py` indexa esquemas por nombre y pide a PostgreSQL interpretar aclitem[] mediante aclexplode/acldefault. Conserva grantor, tipo de destinatario (PUBLIC especial distinto del rol llamado PUBLIC), privilegio y grant option. Una ACL nula se interpreta usando el default del propietario; una ACL vacía representa cero grants, y NO se convierte al default. Nombres con espacios/citas se resuelven mediante el parser PostgreSQL. No se separan ACL con split(',').

También proyecta USAGE/CREATE mediante pg_has_role para contemplar herencia, y declara explícitamente que usa el contexto local. Owner, grants, grant options, grantor y ausencia/presencia de esquema siguen siendo controles estrictos. Las diferencias de permisos nunca se aceptan solamente porque alguna cuenta conserve acceso por otra vía.

`scripts/restaurar_respaldo_staging_local.py` incorpora --diagnosticar-esquemas: después de reconstruir en una instancia sin red, guarda el detalle cifrado y un resumen saneado, y se detiene. La comparación completa posterior permanece pendiente y el modo no puede declarar recuperación PASS. En modo completo, las discrepancias de otros catálogos también conservan su detalle cifrado antes de retirar temporales.

No se imprime SQL del backup, datos de filas ni configuraciones privadas de roles. El resumen solo muestra identificadores técnicos públicos conocidos; otros se sustituyen por etiquetas privadas. El detalle sin redacción permanece cifrado fuera de Git.

## Pruebas previas al ensayo real

`python3 scripts/test_comparador_esquemas_local.py`: 16/16 PASS, en imagen fijada PG17.11, nueva y sin red:

- Igualdad pese a distinto orden de ACL y de esquemas.
- NULL frente a ACL explícita default equivalente.
- NULL frente a ACL vacía: diferencia detectada.
- CREATE adicional, grant option y grantor diferentes: rechazo.
- Propietario cambiado, esquema faltante y esquema adicional: rechazo.
- Roles con espacios/citas y PUBLIC frente a rol llamado PUBLIC.
- Herencia efectiva y cambios de INHERIT; contraste con has_schema_privilege real.
- Catálogo con nombres duplicados: rechazo.

Evidencias sintéticas: `/tmp/cercly-schema-test-5u7r7yly/result.json`.

Dos controles de privacidad adicionales aprobaron: ocultar identificadores privados sintéticos conservando las categorías técnicas de la discrepancia. La prueba inicial detectó que aclexplode no acepta directamente un array vacío de cero dimensiones; el decoder lo trata como cero filas de grants, preservando su diferencia respecto al default. No se eliminó esa prueba para aprobar.

## Continuación y veredicto

Con esta evidencia ya no es necesario repetir una restauración completa para saber qué ACL de esquema falta: el detalle se conservó cifrado. Sí será necesario abrir de forma privada el diagnóstico y el TOC/SQL del respaldo existente para revisar su procedencia y los roles/membresías. No se necesitan credenciales remotas ni una nueva exportación.

Después de revisar ese contenido, preparar y probar sintéticamente una recuperación de las ACL originales si corresponde; solicitar un ensayo local controlado para comprobar la corrección y continuar la verificación completa. No corregir permisos ni continuar el ensayo actual automáticamente.

GO para continuar el diagnóstico local protegido del archivo existente y preparar una solución documentada, bajo las autorizaciones que correspondan. NO-GO para certificar recuperación o desplegar migraciones. Siguen pendientes comparación de datos, funciones, triggers, RLS, otros privilegios, secuencias y contexto original del propietario de base. Las 24 migraciones coincidentes no sustituyen esos controles.

Respaldo original: `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/staging-database-bundle.tar.gpg`, 232982 bytes. SHA-256 esperado: `f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297`.

Referencias técnicas: https://www.postgresql.org/docs/17/ddl-priv.html ; https://www.postgresql.org/docs/17/functions-info.html ; https://www.postgresql.org/docs/17/predefined-roles.html .
