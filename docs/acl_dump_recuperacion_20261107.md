# ACL del dump existente y recuperación local — 2026-11-07

Alcance cumplido: inspección offline del archivo existente con pg_restore --list y SQL seleccionado por TOC, lectura privada del diagnóstico cifrado y pruebas sintéticas. No se restauró otra vez la base REAL, no hubo conexiones remotas, exportaciones nuevas ni migraciones. El respaldo cifrado original no se modificó.

## Evidencia del archivo real

Informe saneado: `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/acl-inspection-711f0566d99b.json`.

Detalle cifrado (TOC seleccionado, SQL necesario, diferencias de roles/membresías): `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/restore-diagnostic-inspection-711f0566d99b.gpg`.

Las herramientas PG17.11 se ejecutaron con --entrypoint=pg_restore, --network=none, sin arrancar un servidor, sin --dbname y con el dump montado solo lectura. La selección TOC incluyó únicamente los dos esquemas/ACL GraphQL, la posible extensión relacionada y metadatos de base. Nunca se imprimió el SQL completo del backup.

| Elemento | Resultado |
|---|---|
| Entradas SCHEMA de graphql/graphql_public | 2 |
| Entradas ACL de esos esquemas | 0 |
| GRANT de esos esquemas en SQL seleccionado | 0 |
| REVOKE de esos esquemas en SQL seleccionado | 0 |
| Entrada EXTENSION pg_graphql coincidente | 0 |
| Entradas DATABASE / DATABASE PROPERTIES | 0 |
| Propietario original de base obtenido del TOC | No disponible |

La ejecución real anterior utilizó pg_restore con --single-transaction y --exit-on-error. No usó --no-acl, --no-owner, listas de exclusión ni omisión de errores. Los 13 propietarios de esquema restaurados coinciden con los originales. Por tanto, no se perdieron las ocho concesiones porque el restaurador descartara esas instrucciones: NO estaban en el archivo nativo. Sí constan en snapshot-catalog.json, ligado criptográficamente al bundle original.

## Causa y límites de atribución

Hay una brecha de cobertura entre el dump SQL nativo y el inventario de ACL archivado: el dump crea los esquemas pero no transporta sus ocho grants. No hay evidencia para afirmar que pg_restore ignorara un GRANT existente.

PostgreSQL puede omitir ACL que considera iniciales de objetos gestionados o pertenecientes a extensiones, esperando que la inicialización de destino las establezca. La prueba sintética reproduce exactamente ese mecanismo con una extensión local de prueba. Esto demuestra la clase de problema y la utilidad del inventario como sidecar de recuperación; NO demuestra retrospectivamente la clasificación particular de pg_init_privs/pg_depend de los esquemas del servidor original. Esos catálogos no se archivaron. La ausencia de una entrada pg_graphql no autoriza atribuir la causa concreta a esa extensión. No se consultó el origen para rellenar esa laguna.

La causa comprobada de la reconstrucción incompleta es que el procedimiento dependía exclusivamente del SQL nativo para esos grants y no reproducía el inventario de ACL que el mismo respaldo sí conserva. La solución propuesta usa esa evidencia original, no una plantilla inventada ni permisos más amplios.

## Roles y membresías: diferencia exacta y defecto del procedimiento

El diagnóstico cifrado confirma cero diferencias de presencia o atributos de roles. Las tres diferencias son exclusivamente membresías ausentes (sin membresías adicionales):

| Rol concedido | Miembro | Grantor | ADMIN | INHERIT | SET |
|---|---|---|---|---|---|
| pg_read_all_settings | pg_monitor | supabase_admin | false | true | true |
| pg_read_all_stats | pg_monitor | supabase_admin | false | true | true |
| pg_stat_scan_tables | pg_monitor | supabase_admin | false | true | true |

El restaurador revocaba TODAS las membresías del cluster nuevo antes de cargar roles-no-passwords.sql. pg_dumpall --roles-only no incluye estas relaciones internas pg_* porque forman parte de la inicialización PostgreSQL. El REVOKE global las destruía y el archivo no las reponía. La prueba sintética confirma la omisión de los tres GRANT por pg_dumpall, la pérdida al revocarlos y su conservación al importar roles sin ese borrado previo.

Corrección mínima: quitar el REVOKE global. Conservar bootstrap y aplicar el archivo de roles. Después se sigue comparando el grafo COMPLETO, incluido grantor y ADMIN/INHERIT/SET. Si el destino introduce otras membresías o flags, fallar; no ignorarlas por ser roles internos. La prueba incluye además una membresía personalizada cuyo INHERIT=false y grantor se reconstruyen exactamente.

## Recuperación limitada de las ocho ACL

`scripts/recuperar_acl_esquemas_local.py` prepara, pero no ejecuta, un plan a partir de los dos catálogos. Rechaza cambios de propietario, esquemas ausentes/adicionales, grants extras, otros esquemas, privilegios CREATE, grantors inesperados u opciones diferentes a las revisadas. Solo repone grants USAGE que figuran como faltantes respecto del inventario original válido.

El efecto SQL equivale a lo siguiente, SOLO en la base restaurada aislada y tras validar el contexto original de roles:

```sql
begin;
set local role supabase_admin;
grant usage on schema graphql, graphql_public to anon, authenticated, service_role;
grant usage on schema graphql, graphql_public to postgres with grant option;
reset role;
commit;
```

SET LOCAL ROLE conserva supabase_admin como grantor. Los propietarios quedan intactos. No se concede CREATE ni WITH GRANT OPTION a los roles de aplicación. El plan real emite cada grant individual desde el inventario, seguido de una comparación completa de ACL, grantor y grant options. No revoca automáticamente privilegios adicionales para hacer coincidir el resultado.

`scripts/restaurar_respaldo_staging_local.py` incorpora el flag explícito --recuperar-acl-archivadas; por defecto no modifica las ACL. Antes de usar el plan exige igualdad completa de atributos de roles y membresías con el inventario; después exige equivalencia exacta de esquemas y grants. Este cambio NO se ejecutó sobre el backup real durante la investigación.

## Propietario de base: evidencia insuficiente

El snapshot no registra pg_database.datdba, ACL de base ni configuración por base/rol. El TOC tampoco contiene una entrada DATABASE de la que recuperar su propietario. El procedimiento anterior fijaba owner=postgres al crear la base local; esa decisión no constituye evidencia de la propiedad original. pg_database_owner tiene membresía implícita dependiente del dueño de la base, por lo que no puede inferirse solamente de pg_auth_members.

Las ACL de esquema y las tres membresías pueden recuperarse con el respaldo existente. No puede certificarse la equivalencia COMPLETA del contexto de base exclusivamente con la información archivada. Un metadato complementario confiable debe acreditar el estado correspondiente al respaldo (no asumir que un estado actual posterior sea idéntico). No hace falta necesariamente volver a exportar datos, pero esta tarea NO autoriza consultar el origen para obtener ese metadato.

El verificador ahora bloquea explícitamente una certificación global cuando falta ese contexto. No se crea un propietario supuesto ni se excluye pg_database_owner de los controles.

## Pruebas sintéticas previas a otra restauración real

`python3 scripts/test_recuperacion_acl_local.py`: 14/14 PASS; evidencia `/tmp/cercly-acl-recovery-ju3jyk6d/result.json`.

Se usó un contenedor nuevo PG17.11, fijado por digest, sin red, sin descargas, sin montar el respaldo real. Los archivos SQL/control de la extensión de prueba se crearon únicamente dentro de ese contenedor y desaparecieron al retirarlo.

La extensión sintética instala los dos esquemas con las ocho concesiones como privilegios iniciales. Se exporta exclusivamente esa base sintética; el dump carece de las ACL de esos miembros. Al reconstruir la extensión con inicialización diferente aparecen ocho grants faltantes, con propietarios iguales. Aplicar el plan limitado restaura exactamente owner/grantor/opciones y hace coincidir el catálogo completo, no solamente las operaciones permitidas.

Controles: omisión nativa de membresías internas; pérdida por REVOKE y rollback; conservación de las tres relaciones originales; flags/grantor de una membresía personalizada; omisión nativa de ACL de extensión; reproducción de ocho faltantes; plan de ocho USAGE sin CREATE; equivalencia completa después; igualdad de grantor/grant options; CREATE y acceso no autorizados denegados; delegación no autorizada sin efecto; detección de privilegio adicional y rechazo del plan ante ese exceso.

El comparador previo conserva sus 16 pruebas aprobadas (orden, NULL/default, ACL vacía, propietarios, grantor/opciones y roles heredados). No se debilitaron esos controles.

## Formato de respaldo que debe prepararse en el futuro

Sin ejecutar exportaciones nuevas ahora, documentar una versión siguiente del bundle con:

- Propietario original y ACL de pg_database, encoding, locale/collation/provider/version, límites/estado de conexión, propiedades y configuraciones por base y por rol/base.
- Roles globales con atributos y configuración; todas las membresías, incluidas internas pg_*, con grantor, ADMIN, INHERIT y SET. No incluir contraseñas de roles en informes.
- ACL estructuradas/canónicas de esquemas, objetos y columnas, valores explícitos/default, grantor y grant options; preservar inventario original cifrado y vincularlo por SHA-256 al dump.
- pg_init_privs y dependencias con extensiones de los objetos gestionados, versiones/propietarios de extensiones y versión de inicialización de la plataforma. Esto permite explicar qué privilegios se espera reconstruir desde bootstrap.
- Roles y metadatos globales compatibles temporalmente con la instantánea exportada; registrar ventana y cualquier limitación de coherencia entre catálogos globales y snapshot de datos.
- Storage binario y configuraciones/secretos externos siguen requiriendo recuperación separada autorizada; los cifrados de Vault pueden depender de claves de plataforma no contenidas en el dump.

## Estado y recomendación

Puede autorizarse un nuevo ensayo local ACOTADO para comprobar las ACL recuperadas y membresías, y avanzar en datos, funciones, triggers, RLS y secuencias. No se ejecuta ahora una restauración real completa. La certificación global seguirá bloqueada hasta acreditar el contexto original de base ausente y completar TODOS los controles.

GO técnico para la corrección limitada probada sintéticamente; NO-GO para anunciar recuperación global equivalente o desplegar migraciones. Si se exige resolver primero todo el contexto, obtener y revisar el metadato complementario fiable antes de otro ensayo real. No inferir un GO de despliegue del pg_restore exit=0.

El respaldo original permanece en `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/staging-database-bundle.tar.gpg`, con SHA-256 `f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297`. Los nuevos detalles de inspección se conservaron cifrados aparte. No se publicó nada ni se hizo push/integración.
