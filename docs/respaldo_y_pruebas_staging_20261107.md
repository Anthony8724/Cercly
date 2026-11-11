# Respaldo, restauración aislada y autorización STAGING

Preparación del 7 de noviembre de 2026. Seguridad guardada en commit local `b10a889421b52faea266767f50da0cefc8cb92c6`, rama `fix/promociones-solicitudes-sky`. No se ha exportado ninguna base remota, enlazado la copia ni aplicado migraciones. No hay un respaldo real de STAGING acreditado por este informe.

## Identidad y herramientas verificadas

- STAGING: `dlajxviqhkdcqnmczhvr`, Cercly Staging, ACTIVE_HEALTHY, PostgreSQL 17.11.0.003.
- Production: `aimubazregckmjchnszf`. El checkout original sigue enlazado a Production: ninguna operación --linked debe ejecutarse allí.
- MCP permite consultar metadatos e historial explícitamente por project_id; su conjunto de herramientas no ofrece listar backups. La presencia de restore_project no acredita backups y no se invocó esa operación.
- No se ha confirmado el plan, un snapshot, ventana PITR, fecha del último backup ni una restauración real. Consultarlos en el Dashboard del ID STAGING o en GET de Management API de backups con autorización y acceso adecuados. No inferirlos de ACTIVE_HEALTHY.
- La documentación ofrece backups diarios para planes Pro/Team/Enterprise, PITR según plan/configuración y exportaciones lógicas. Los objetos binarios de Storage no están en el backup PostgreSQL. Referencias: https://supabase.com/docs/guides/platform/backups y https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore.
- CLI local 2.119.0: ayuda db dump verificada, soporta --project-ref, --schema, --role-only, --data-only y --use-copy. El dump por defecto NO es un backup completo: excluye esquemas gestionados y no incluye datos ni roles por defecto. Antes de adoptar esa vía hay que confirmar cobertura de Auth/Storage/esquemas privados con el script de exportación que generaría la versión instalada; no asumirla.
- Clientes nativos del equipo: PostgreSQL 18.6. No se usarán para el ensayo destinado a PG17 sin revisión. La imagen local fijada usada por las suites contiene pg_dump 17.11; no necesita descarga:
  `public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53`.

## Alcance de autorización pendiente para respaldo

Solicitar autorización concreta para leer y exportar STAGING, incluyendo Auth y esquemas privados, y guardar un backup cifrado fuera del repositorio. La autorización debe identificar ubicación privada duradera y custodia de la clave de recuperación. No solicitar contraseñas en chat, parámetros --password o URI con contraseña en argumentos, logs o Git. No se solicitan permisos de escritura remotos ni de despliegue como parte del respaldo.

Una exportación lógica es técnicamente viable con PG17.11 y acceso de lectura suficiente. No se ha probado la conexión de pg_dump ni que el rol autorizado pueda leer todas las relaciones; si falla por permisos o extensiones, detenerse y revisar cobertura. No omitir tablas silenciosamente ni otorgar permisos generales para lograr un archivo aparentemente correcto.

Procedimiento previsto, NO ejecutado:

1. Revisar de nuevo el ID STAGING y su estado usando metadatos. Verificar endpoint directo `db.dlajxviqhkdcqnmczhvr.supabase.co` o pooler de SESIÓN oficial, cuyo usuario debe corresponder a ese ref. No usar pooler transaccional ni el enlace del repositorio original. Verificar SSL y la CA oficial cuando corresponda, sin rebajar protecciones ante un error de conexión.
2. Crear una carpeta privada duradera fuera del proyecto (directorio 0700, archivos 0600, umask 077). Ejemplo de ubicación, todavía no creada: `/home/Anthony/RespaldosPrivados/Cercly/STAGING/<fecha-UTC>/`. /tmp sirve para el ensayo, no es un respaldo duradero.
3. Provisionar por el mecanismo seguro autorizado un `pg_service.conf` con servicio `cercly_staging_backup` y un archivo pgpass privado separado. Credenciales fuera del bundle y del repositorio. El servicio debe fijar endpoint/usuario/base correctos; verificar esos campos sin imprimir la contraseña. Usar `PGSERVICEFILE` y `PGPASSFILE`, sin incluir una URI secreta en argv. No usar --debug ni imprimir el entorno.
4. Ejecutar el cliente PG17.11 de la imagen fijada mediante un contenedor cliente temporal con salida de red autorizada, credenciales montadas solo lectura y directorio privado de salida. Capturar stderr en archivo privado; resumir el código de salida, sin volcar errores COPY ni contenido SQL en el chat.
5. Exportación principal propuesta: pg_dump de la base STAGING completa en formato custom, con estructura y datos en UN archivo y snapshot coherente. Argumentos dentro de ese contenedor: `pg_dump --dbname=service=cercly_staging_backup --format=custom --file=/backup/database.dump`. No ejecutar --clean sobre una base remota ni utilizar pg_restore contra STAGING. El dump debe incluir esquemas de aplicación, `cercly_auth_private`, `cercly_account_private`, auditorías, historial `supabase_migrations`, Auth/Storage, funciones, triggers, RLS, ACL, propietarios y secuencias. Confirmar lo que realmente contiene mediante pg_restore --list e inventario de catálogos; si las extensiones excluyen objetos, documentar y comprobar cómo se reconstruyen con la plataforma compatible.
6. Exportar también definiciones de roles/custom grants SIN contraseñas de roles: `pg_dumpall --dbname=service=cercly_staging_backup --roles-only --no-role-passwords --file=/backup/roles-no-passwords.sql`. Puede necesitar permisos adicionales de lectura de roles: un fallo bloquea declarar cobertura completa y no autoriza escalar privilegios. El backup de Auth contiene hashes de contraseñas y otros datos sensibles: cifrarlo y restringirlo, aunque no contenga contraseñas SQL en claro.
7. Guardar fuera de Git un inventario privado: versiones PostgreSQL/extensiones, esquemas/tablas, conteos y huellas por tabla, constraints/grants/policies/funciones/triggers/secuencias, UTC de inicio/fin, ref, commit de código, lista de migraciones y SHA-256 de archivos. Los datos y las huellas detalladas se consideran privados; el informe compartido solo registra PASS/FAIL y cobertura. Las comprobaciones contra el origen requieren lecturas autorizadas. Si hay escrituras concurrentes, usar una ventana de prueba coordinada o el mismo snapshot exportado: no comparar un conteo posterior como si perteneciera al snapshot.
8. Registrar configuraciones externas necesarias sin exponer sus valores secretos: OAuth/redirects, SMTP, dominios, parámetros de Auth/API/Realtime, secretos requeridos, tareas programadas y replicación. Conservar el código de Edge Functions desde Git. Contraseñas de roles personalizados y secretos deben recuperarse o rotarse desde custodia separada; no están garantizados por un dump sin passwords.
9. Storage: el dump conserva metadatos, no los bytes. Si se exige recuperación completa de archivos, solicitar por separado su copia autorizada y comprobación de integridad; guardar claves/rutas de objetos fuera de informes públicos. Hasta entonces declarar cobertura de archivos pendiente.
10. Cifrar el bundle con mecanismo y clave de recuperación acordados, custodiados separadamente; probar descifrado en almacenamiento privado. No mostrar passphrases en línea de comandos. Los dumps nunca se añaden a Git; no borrar originales ni temporales privados sin acordar su conservación. Conservar una segunda copia cifrada duradera.

La ruta oficial alternativa de tres archivos (roles, schema, data) puede ser necesaria para compatibilidad con una plataforma nueva. No sustituye automáticamente el archivo coherente: usa exportaciones separadas y filtros gestionados. Revisar sus schemas y la coherencia temporal; un pg_dump nativo completo también puede contener objetos gestionados incompatibles con un proyecto hospedado nuevo. Un archivo generado no acredita restaurabilidad en ambos destinos.

## Restauración aislada prevista

Primero obtener autorización de exportación/custodia; después ensayar los archivos reales en una instancia NUEVA local. Sin conectarla a STAGING, sin cambiar DNS, URL de aplicación ni secretos de Production.

1. Verificar integridad/cifrado y manifeste del backup antes de leerlo; confirmar ref de origen. Descifrar únicamente a carpeta privada 0700, archivos 0600, fuera de Git.
2. Crear contenedor Supabase PostgreSQL 17.11 fijado, --pull=never, --network none, sin puertos expuestos ni montajes del proyecto, con nombre único. Solo se detiene al final el contenedor creado por ese ensayo; no tocar volúmenes o instancias existentes.
3. Consultar pg_available_extensions/versiones frente al inventario. No sustituir extensiones desconocidas ni ignorar errores. Crear base nueva con template0. Verificar roles reservados del cluster de prueba y preparar SOLO los roles personalizados necesarios tras revisar roles-no-passwords.sql; no ejecutar ciegamente un script de roles contra el cluster compartido ni reemplazar passwords de roles existentes.
4. El destino vacío debe disponer de los requisitos de plataforma de la versión elegida. Para archivo nativo, usar pg_restore con --single-transaction --exit-on-error hacia la base local NUEVA; restaurar pre-data, datos y post-data/constraints/ACL. No usar --no-owner o --no-acl para ocultar divergencias. Si falla por propietarios, esquemas gestionados o extensiones, conservar diagnóstico privado y corregir el entorno de destino; no declarar éxito parcial como recuperación completa.
5. Para la variante oficial roles/schema/data sobre una instancia Supabase preinicializada compatible, revisar los defaults/grants de destino y evitar que la restauración reintroduzca UPDATE general. Importar datos con el procedimiento oficial únicamente en ese destino aislado; si se cambia session_replication_role para evitar triggers durante la importación, restaurar origin y comprobar restricciones después. No trasladar ese cambio a un entorno remoto ni desactivar triggers durante las pruebas de autorización.
6. Comparar estructura, inventario y conteos/huellas del snapshot sin emitir filas. Verificar secuencias, FK validadas, propietarios, RLS activa, ACL de columnas, definers y search_path. El archivo de auditoría debe coincidir con el snapshot. Ensayar consultas con roles anon/authenticated y JWT sintéticos locales. No enviar correo, notificaciones ni solicitudes HTTP reales desde la copia.
7. Crear otra copia local del respaldo restaurado para aplicar las dos migraciones pendientes en orden y ejecutar las suites de regresión con identidades sintéticas y rollback. Conservar intacta la primera restauración como punto de comparación. Las pruebas del repositorio sobre esquema reconstruido ya aprobaron, pero no equivalen a este ensayo con datos/versiones reales.
8. Documentar tiempo real de restauración, pérdidas potenciales desde snapshot y cobertura exacta. NO-GO si hay permisos ampliados, relaciones ausentes, filas/huellas discordantes, FK sin validar, pérdida de auditoría o dependencia de secretos no recuperables. Una restauración remota posterior requeriría autorización específica y otra ventana; este procedimiento solo prepara PostgreSQL aislado.

Ensayo realizado en esta tarea: backup y pg_restore de fixtures sintéticos en un contenedor sin red, base destino nueva template0, cliente PG17.11. Datos, función, RLS y secuencia: PASS. Evidencia `/tmp/cercly-backup-probe-yf5t8t_4/result.json`. NO se exportaron datos STAGING y NO se acredita recuperación de Auth, roles personalizados, extensiones remotas ni Storage real mediante ese ensayo.

## Preflight reproducible y pendientes

Se conserva la copia original `/tmp/cercly-staging-preflight-20261107/`. También se generó `/tmp/cercly-staging-preflight-b10a889/`. Ambas carecen de enlace y credenciales. /tmp es volátil.

Reproducción desde este repositorio, eligiendo un destino NUEVO fuera de él:

```bash
python3 scripts/preparar_preflight_staging.py --dest /tmp/cercly-staging-preflight-revision-nueva
```

El script no usa red ni Supabase CLI. Verifica el manifiesto de 24 históricas y 2 pendientes, los SHA-256 de todos los archivos y la ausencia de archivos adicionales. Renombra los dos alias SOLO en la copia; nunca copia .temp/.env ni secretos. Falla si cambia una migración o existe el destino. El manifiesto versionado solo contiene versiones, nombres, hashes e IDs de proyecto públicos.

Historial remoto vuelto a consultar en modo lectura: 24, última versión 20261029183557. Concordancia: 19 SQL idénticos; 3 equivalentes tras reconstruir límites de sentencias y quitar líneas vacías; 2 alias con SQL idéntico y timestamps diferentes. No usar migration repair. Pendientes en la copia reconciliada: 20261106034310 y 20261107121537. La fuente Git conserva los timestamps originales para no alterar a ciegas historiales de otros entornos.

## Funciones afectadas y pruebas remotas propuestas

La siguiente fase necesita autorización expresa de despliegue y de fixtures SOLO STAGING, después de un backup restaurable. Cuentas sintéticas: administrador revisor, propietario A, propietario B/ajeno, colaborador activo y usuario sin negocios; no usar cuentas personales, administrador sintético del experimento geográfico ni promociones existentes. No registrar passwords/tokens de las sesiones.

- Moderación del panel: `cambiarEstado` envía estado; rechazo retira publicación para respetar el CHECK. Reaprobación desde el panel actual no vuelve a poner publicable=true. La RPC moderar_estado_establecimiento permite publicación explícita y aún no está conectada al cliente: validar esta limitación de UX antes de integrar. No prometer ficha publicada por el mero mensaje de aprobación.
- Correcciones: aplicar_correccion exige exactamente la propuesta y motivo, conserva antes/después y detecta datos obsoletos. La RPC antigua responder_solicitud no debe aprobar correcciones por su cuenta; sí conserva registro/reclamo/acceso y rechazo. Verificar UI sin fallback de éxito.
- Admin propietario/miembro: la restricción informativa también se aplica aunque tenga membresía; categorías, horarios y fotos no admiten usar esa condición como bypass. Las pantallas no deben mostrar éxito si RLS filtra una operación.
- Propietario: sus cuatro campos de edición directa están en el grant limitado. Atención adicional del cliente: toSupabaseParaActualizarInformacion puede incluir estado=pendiente al editar una ficha aprobada, mientras proteger_establecimiento reserva cambios de estado a administradores. Esa interacción existente requiere prueba específica; el test SQL de nombre solo no acredita el flujo de UI completo. No se modificó Flutter para resolverla en esta tarea.
- Cancelación de solicitudes: eliminarPendiente ya filtra estado pendiente. Las correcciones cerradas quedan retenidas; no se debe incorporar un borrado administrativo de cerradas para evitar un error RLS.
- Eliminación de cuenta: revisar_eliminacion y validar_eliminacion conservan sus barreras. La existencia de solicitudes/auditoría restringe borrados y dirige a revisión. NO hay todavía supresión/anonimización resuelta, y 24 meses no es política legalmente aprobada. La propuesta de separación de identidad y minimización sigue en docs/seguridad_administrativa_y_staging_20261107.md. No usar una cuenta real para ensayar borrado ni quitar FK como solución.

Plan de aceptación remoto, todavía NO ejecutado:

1. Preservar huellas/conteos de datos previos; acordar IDs de fixtures de negocio/solicitud y cualquier limpieza posterior, siempre fuera de datos existentes. La autorización de pruebas debe especificar si permite crear/modificar y retirar esos fixtures; no se presume permiso de borrar datos.
2. Comprobar grants/RLS por catálogo después del despliegue autorizado. Admin directo nombre, coordenadas, propietario, mezcla estado/datos y categoría indirecta deben fallar sin cambios. Admin/moderación válida y corrección por RPC deben funcionar.
3. Propietario ajeno y usuario normal no leen historial ajeno ni modifican fichas; propietario A envía propuesta válida; duplicado pendiente falla; rechazo conserva negocio y motivo; aprobación aplica solo campos propuestos y audita; repetida falla; propuesta obsoleta falla sin cambios.
4. Probar cambio de categoría, coordenadas y detalle de publicación con fixtures, sin promociones ni geofences reales. No alterar geofencing, cooldown ni permisos del Honor.
5. Forzar error únicamente en fixture/copia local para verificar atomicidad; no instalar un trigger de fallo general en STAGING. En remoto, usar propuestas obsoletas/invalidaciones controladas del fixture.
6. Revisar lectura de historial, denegación de reescritura y conservación de rechazo. Las pruebas de eliminación real de Auth se reservan al entorno local aislado; en STAGING solo diagnóstico del estado revision salvo autorización adicional específica.
7. Reabrir cliente con cuentas de prueba y confirmar mensajes, estado y publicación efectiva. Detenerse ante permisos generales, pérdida de historial, falsas confirmaciones o alteraciones de datos previos.

## Recomendación

GO para solicitar autorización del inventario privado de backups y exportación lógica SOLO STAGING con custodia cifrada, seguida de restauración local. NO-GO para ejecutar migraciones o pruebas remotas con escritura ahora: no hay respaldo real restaurado ni autorización de despliegue/fixtures. La eliminación/anonimización sigue pendiente y la interacción del cliente con publicación/cambio de estado requiere aceptación funcional. No integrar a develop hasta cerrar esos requisitos.
