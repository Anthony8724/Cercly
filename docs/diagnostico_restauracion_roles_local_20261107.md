# Diagnóstico local de restore_roles_prepare — 2026-11-07

Alcance: solo contenedores nuevos con datos sintéticos, sin red. No se volvió a conectar a Supabase, no se descifró el respaldo real, no se aplicaron migraciones ni se repitió la restauración real. El repositorio de partida permanece en 28dac2b.

## Evidencia y límite del registro histórico

El registro del intento real conserva solamente `restore_roles_prepare / LOCAL_RESTORE_COMMAND_FAILED`. El wrapper original capturaba stderr/returncode en memoria y los sustituía por una categoría genérica; no guardó el comando concreto, returncode ni SQLSTATE. No es posible recuperar esos campos del intento pasado. Los códigos siguientes corresponden a reproducciones nuevas de los comandos y la secuencia exactos, no a un log histórico reconstruido.

Se comprobaron DOS defectos del procedimiento, ambos anteriores al contenido del dump:

1. Carrera de arranque. El script aceptaba el primer `pg_isready -U postgres` satisfactorio por socket Unix. En la reproducción de esa secuencia, el siguiente primer comando de preparación falló con salida 2:

   `podman --remote=false exec -i <contenedor-local> psql -X -qAt -U postgres -d postgres --set=ON_ERROR_STOP=1`

   Entrada estándar SQL, sin credenciales: `create role "cercly_restore_operator_probe" login superuser;`

   Error sintético completo: `connection to server on socket "/run/postgresql/.s.PGSQL.5432" failed: No such file or directory`. El servidor había respondido a readiness, pero su socket desapareció durante la transición de arranque. Una consulta posterior, sin cambiar permisos ni datos, conectó con normalidad. Evidencia: `/tmp/cercly-roles-exact-8r6tux5m/result.json`. Esto reproduce el tipo de error que el wrapper clasificaba genéricamente como LOCAL_RESTORE_COMMAND_FAILED.

2. Ejecutor de bootstrap equivocado. Una vez estable el servidor, `postgres` tiene `rolsuper=false`, `rolcreaterole=true`, `rolcreatedb=true`, `rolbypassrls=true`. CREATEROLE no permite crear otro SUPERUSER. El mismo SQL ejecutado con postgres falla con salida 3 y SQLSTATE 42501:

   `ERROR: permission denied to create role`

   `DETAIL: Only roles with the SUPERUSER attribute may create roles with the SUPERUSER attribute.`

   `supabase_admin` es el superusuario real de esta imagen. El comando con `-U supabase_admin` terminó con salida 0. No se elevó postgres ni ningún rol de aplicación. Evidencia sintética final: `/tmp/cercly-roles-diagnostic-ejcbdndu/result.json`.

PostgreSQL 17 documenta el requisito de SUPERUSER para crear otro superusuario: https://www.postgresql.org/docs/17/sql-createrole.html . psql documenta salida 2 para pérdida/fallo de conexión y 3 para error SQL con ON_ERROR_STOP: https://www.postgresql.org/docs/17/app-psql.html .

No hay evidencia de incompatibilidad del respaldo: el error ocurre antes de ejecutar pg_restore. Tampoco se debe declarar que el respaldo sea restaurable hasta probarlo realmente. La primera carrera reproduce una salida 2 compatible con la categoría histórica; no se puede afirmar retrospectivamente su código exacto sin el log que faltó. El segundo defecto es independiente y determinista: habría bloqueado la preparación si la carrera no se producía.

## Corrección mínima preparada

- Esperar `pg_isready -h 127.0.0.1 -U supabase_admin` dentro del contenedor con NetworkMode=none; todos los clientes locales de preparación/restore usan el loopback de ESA instancia. No se publica ningún puerto. No se infiere readiness del nombre de PID 1, que no resultó un indicador válido en esta imagen.
- Comprobar mediante una consulta local que el ejecutor de bootstrap es realmente superusuario; crear un operador de mantenimiento local único usando supabase_admin. El operador no pertenece a la aplicación ni se exporta a ningún proyecto remoto.
- Usar ese operador también para pg_restore, importación de roles y verificaciones, en lugar del postgres no superusuario. Conservar propietarios y ACL del dump; no agregar --no-owner, --no-acl o un mecanismo que ignore errores.
- Mantener los atributos originales de los roles de aplicación, postgres y miembros. La identidad local adicional se excluye únicamente de la comparación del inventario global por ser el ejecutor de mantenimiento creado para el ensayo; no se excluyen los roles ni atributos de origen. Es una identidad superusuario temporal exclusivamente dentro de la instancia sin red, retirada al eliminar esa instancia.
- Desactivar ejecución de jobs cron en el contenedor local para evitar efectos del scheduler durante el ensayo. No afecta al servidor remoto.
- Subdividir restore_roles_prepare en bootstrap_identity, create_local_operator, inventory, create_missing_roles y create_database. Conservar código de salida y SQLSTATE en el informe saneado. psql usa VERBOSITY=sqlstate y SHOW_CONTEXT=never para evitar que errores con COPY o funciones reproduzcan valores personales. No imprimir stderr del dump real.

Archivos preparados:

- `scripts/restaurar_respaldo_staging_local.py`: copia durable corregida del procedimiento antes ubicado en /tmp. Exige flag explícito de ejecución y socket privado del agente de cifrado; su ayuda y compilación fueron comprobadas. NO se ha ejecutado con el respaldo real. Valida SHA-256 esperado fijo, cifrado, manifiesto y ref antes de restaurar; conserva todas las comparaciones del catálogo, roles, datos, ACL, RLS, triggers y secuencias. No contiene conexión a Supabase. No elimina el archivo cifrado ni carpetas ajenas.
- `scripts/cercly_backup_catalog.py`: consultas de verificación usadas por el procedimiento; sin claves, datos personales ni conexiones.
- `scripts/diagnosticar_roles_restauracion_local.py`: diagnóstico reproducible sin red ni entradas de backups/URLs. Reproduce el rechazo del superusuario incorrecto y verifica el camino corregido con un archivo sintético.
- `/tmp/cercly-staging-restore.py`: corregido igualmente para evitar reutilizar el procedimiento viejo. /tmp sigue siendo volátil; la copia durable es la fuente a revisar para un futuro intento.

## Prueba sintética final

Comando ejecutado: `python3 scripts/diagnosticar_roles_restauracion_local.py`.

Imagen local fijada: `public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53`.

pg_dump y pg_restore: PostgreSQL 17.11; NetworkMode=none; sin descargas ni montajes del respaldo real. Resultado PASS. Se prepararon los roles con el administrador local correcto, se crearon dos bases nuevas template0 y se exportó/restauró únicamente el schema de fixtures.

Once controles aprobados: número de filas, RLS efectivo, UPDATE no autorizado rechazado con 42501, propietario conservado, política presente, trigger habilitado, estado de secuencia conservado, ejecución del trigger, continuidad de secuencia, cliente sin SUPERUSER/BYPASSRLS y postgres sin elevación. El comando de bootstrap corregido terminó con salida 0; los rechazos esperados no se silenciaron. Se detuvieron y retiraron solamente los contenedores creados por estos ensayos.

## Respaldo y siguiente autorización

Archivo original (no modificado): `/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/staging-database-bundle.tar.gpg`.

Tamaño 232982 bytes; SHA-256 esperado y verificado antes del diagnóstico: `f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297`.

La prueba sintética acredita la corrección del arranque/bootstrap y el ejecutor local. NO acredita compatibilidad de todos los objetos gestionados, extensiones ni roles particulares del dump real: las comprobaciones estrictas deben mantenerse en el próximo intento.

GO para solicitar autorización de UN nuevo intento exclusivamente local con este procedimiento corregido y el respaldo existente. Será necesario introducir otra vez la frase mediante diálogo oculto, porque el agente anterior cerró y no la guardó. No se necesitan credenciales PostgreSQL remotas ni una nueva exportación. Antes del próximo intento se revisará el procedimiento corregido y se abrirá un nuevo agente de cifrado privado; no se ejecuta como parte de este diagnóstico.

NO-GO para desplegar migraciones: todavía no hay restauración real satisfactoria. La autorización de un ensayo local no autoriza aplicar migraciones, cambiar datos remotos ni integrar a develop.
