# Seguridad administrativa y preparación STAGING — 2026-11-07

Estado: preparación exclusivamente local, rama fix/promociones-solicitudes-sky sobre 0dce3df. Se conservan los cambios previos en la migración estructurada y su suite. No se modificaron bases remotas, geofencing ni código Flutter.

## Inventario de rutas y autorización

- `establecimientos`: política permisiva original `propietario o administrador actualiza establecimiento`, política de colaboradores y grant general UPDATE. La nueva migración elimina la política mixta y el grant general, revoca también ACL de columnas heredadas y permite solamente UPDATE de nombre, descripción, dirección, teléfono y estado (contrato del cliente actual). RLS conserva propietario y colaboradores activos; separa la política administrativa de moderación. Un trigger SECURITY INVOKER prohíbe al administrador modificar datos informativos, incluso si es propietario o miembro. No confía en flags/GUC del cliente.
- Moderación heredada: el panel envía solo `estado`. El trigger permite esa operación, retira publicación al pasar a rechazado/pendiente y no publica implícitamente al aprobar. Así respeta el CHECK de publicabilidad. La RPC nueva `moderar_estado_establecimiento(uuid,public.estado_establecimiento,boolean)` exige administrador autenticado; parámetros cerrados a estado/publicación. No admite datos informativos. No cambia la UI ni se ha conectado a ella: el cliente actual conserva el camino restringido de estado.
- `aplicar_correccion_establecimiento`: administrador autenticado, propuesta estructurada completa revalidada, fila de solicitud y establecimiento bloqueadas, solamente valores solicitados, auditoría y respuesta en una transacción. Propietario/member no se autoaprueban. La RPC antigua no aprueba correcciones sin historial por el trigger de aprobación.
- `responder_solicitud_establecimiento`: administrador autenticado, pendiente, tipo validado. Registro/reclamo/acceso mantienen su lógica existente y parámetros sin valores arbitrarios de actualización de negocios.
- `revisar_eliminacion_cuenta`: administrador diferente del sujeto, sesión reciente y acción limitada; transferencia requiere propiedad y miembro destino autorizado; desactivación y aprobación conservan sus barreras y auditoría existentes.
- Ruta indirecta `establecimiento_categorias` → `sincronizar_categoria_principal` SECURITY DEFINER: políticas restrictivas de INSERT/UPDATE/DELETE impiden al administrador activar esta ruta; solo responsables no administradores. Mismo control en horarios y fotos, incluida la RPC SECURITY INVOKER de horarios. Triggers no requieren permisos EXECUTE del usuario; se revoca la invocación directa del sincronizador.
- Los definers revisados escriben como postgres/supabase_admin y validan identidad y operación antes del UPDATE. El trigger invoker distingue ese rol efectivo del DML del cliente. Estos roles/credenciales de servidor siguen siendo parte del perímetro de confianza de PostgreSQL; un dueño de la base no puede limitarse mediante RLS.
- Se bloquea DELETE directo administrativo de fichas; la política restrictiva también conserva solicitudes de corrección cerradas, incluidas rechazadas. No se concede UPDATE general ni permisos nuevos a anon/service_role.

## Datos y recuperación

Las dos migraciones nuevas son DDL y no hacen backfill ni actualizan filas existentes. La suite comprueba huellas de Auth/public antes y después y tabla de auditoría inicialmente vacía. Al ejecutarse futuras operaciones autorizadas, sí cambian datos y crean historial.

La FK auditoría → solicitud es RESTRICT. La solicitud apunta al usuario con RESTRICT y al establecimiento con CASCADE: intentar borrar usuario o ficha con una corrección auditada falla de forma segura. `tiene_dependencias` dirige cuentas con solicitudes a revisión. No se ha retirado ninguna FK ni borrado datos para evitar ese bloqueo. Las pruebas verifican esta situación y su conservación; no equivale a un procedimiento de eliminación ya resuelto.

Propuesta pendiente de aprobación de privacidad/legal:

1. Archivar o despublicar la ficha para la operación habitual, sin intentar un borrado en cascada.
2. Al cerrar cada caso, registrar el resultado; separar evidencia operativa mínima (campos cambiados y fechas) de la identidad y texto libre. Nombre/dirección/teléfono anteriores pueden ser datos personales: no basta con quitar email.
3. Preparar una migración posterior para desvincular identidades mediante un identificador de caso seudónimo y una relación de identidad restringida, con revisión humana documentada. Permitir eliminar Auth/perfil sin borrar el hecho auditado después de resolver propiedad/membresías y evidencias. No añadir un nuevo RESTRICT a Auth que replique el problema.
4. Evaluar redacción/minimización de `antes`, `despues`, motivos y evidencias. Una redacción autorizada debe dejar constancia de qué categorías de datos se retiraron y por qué, sin copiar nuevamente el dato eliminado al registro de redacción.
5. Los 24 meses son una propuesta interna; `conservar_hasta` es metadato orientativo, no una base legal ni un borrado programado. Pendientes: finalidad/base legal, plazos por tipo de dato, derechos de supresión, excepciones por reclamaciones y acceso a respaldos.

Recuperación: las migraciones usan BEGIN/COMMIT, lock_timeout 5s y statement_timeout 60s. Un error antes de commit revierte el DDL. Después de commit, detener nuevas aprobaciones y aplicar corrección hacia adelante; conservar auditoría y no borrar registros para revertir cambios comerciales. Una reversión comercial requiere nueva propuesta con valores actuales y cambio compensatorio trazable. Restaurar un backup completo puede perder escrituras posteriores: exige autorización, ventana de mantenimiento y ensayo de restauración en instancia aislada antes de considerar reemplazar STAGING.

## Reconciliación comprobada, consultas de lectura a STAGING

STAGING dlajxviqhkdcqnmczhvr. PRODUCTION aimubazregckmjchnszf. El enlace del repositorio actual continúa en Production; no se utiliza --linked allí.

Remoto: 24 filas en supabase_migrations.schema_migrations. Fuente local ahora: 26 migraciones.

| Fuente local | Versión remota | Comprobación |
|---|---|---|
| 20261029085433_preferences_rpc_only_write.sql | 20261029145558, nombre preferences_rpc_only_write_20261029085433 | SQL original idéntico byte por byte |
| 20261029183540_revoke_service_role_preferences_rpc.sql | 20261029183557, nombre revoke_service_role_preferences_rpc | SQL original idéntico byte por byte |
| 20261028071611 | misma versión | 6 sentencias; reconstrucción de terminadores y comparación sin líneas vacías idéntica |
| 20261029025918 | misma versión | 19 sentencias; misma comprobación, sin cambios SQL |
| 20261029032754 | misma versión | 3 sentencias; misma comprobación, sin cambios SQL |

Las otras 19 migraciones coinciden en versión y hash del SQL almacenado. Los hashes distintos de las tres anteriores se explican por representación de sentencias/espaciado; no justifican migration repair ni una nueva aplicación de SQL histórico.

Copia preparada: `/tmp/cercly-staging-preflight-20261107/`, solo config.toml, migraciones y manifest.json con hashes SHA-256 y mapeo fuente/destino. No copia .temp, .env, claves, contraseñas, semillas ni enlace Production. Únicamente allí se usan los timestamps remotos para los dos alias, preservando el SQL. Después del mapeo: 24 versiones concordantes; pendientes 20261106034310 y 20261107121537. No se renombraron archivos históricos en Git. Antes de usar esta copia se debe regenerar/verificar el manifiesto contra el código final; /tmp no es respaldo duradero.

## Plan de despliegue (NO ejecutado)

1. Revisar diff y resultados; conservar los cambios actuales mediante commit local autorizado. Seleccionar exactamente ese código para despliegue y regenerar copia/manifiesto. Verificar que el manifiesto refleja ambas migraciones revisadas y que no hay archivos adicionales.
2. En la copia aislada, ejecutar el binario CLI local `/home/Anthony/.npm/_npx/c34c3565ecb5471d/node_modules/.bin/supabase link --project-ref dlajxviqhkdcqnmczhvr`. No pasar contraseñas por argumentos/chat/logs. Comprobar el ref guardado y detenerse si no coincide. No usar --linked en el checkout original.
3. Solo en esa copia enlazada a STAGING, `supabase migration list --linked` debe mostrar 24 alineadas y exactamente dos pendientes. Volver a consultar explícitamente el ID/nombre del proyecto antes de solicitar autorización de cambios.
4. Verificar plan y respaldo real en Dashboard/Management API: snapshot anterior a la ventana, fecha, cobertura de schema/Auth/datos, retención y acceso. Si no hay respaldo gestionado, exportación lógica segura, permisos restrictivos y restauración comprobada localmente. Storage binario requiere respaldo aparte; sus objetos no están dentro de un backup de PostgreSQL. Actualmente NO se ha confirmado disponibilidad ni se ha ensayado restauración de un respaldo real de STAGING.
5. Con aprobación explícita de cambios remotos y recuperación verificada: revisar dry-run con --skip-vault en la copia, sin seeds ni roles y detenerse ante cualquier migración histórica o destino inesperado. Revisar las dos migraciones y aplicar únicamente ellas en orden mediante el mecanismo autorizado. Esta tarea no ejecuta db push, ni siquiera dry-run, ni migration repair.
6. Comparar huellas/conteos de filas previas de negocio, solicitudes y Auth sin registrar su contenido; verificar grants por columna, RLS, roles efectivos, propietarios de definers, search_path y RPC/trigger de moderación. La auditoría nueva debe empezar vacía.
7. Pruebas remotas posteriores requieren autorización específica de fixtures y cuentas STAGING: administrador DML informativo denegado, mezcla estado/datos denegada, categoría indirecta denegada, moderación válida, ajeno denegado, propietario propone, duplicada denegada, rechazo sin cambio, aprobación exacta, doble aprobación denegada, rollback inducido y RLS de historial. Hasta autorizar fixtures, solo inspección de catálogos; no usar filas reales para pruebas de escritura.
8. Verificar el cliente contra STAGING y comprobar que los caminos heredados de moderación continúan funcionando. No integrar a develop ni generar APK antes de revisar el resultado real y aprobar la integración.

## Estado de las decisiones

El bypass del código versionado queda protegido localmente por ACL de columnas, políticas restrictivas y trigger invoker, más regresiones. STAGING remoto sigue sin esos cambios. NO-GO de despliegue hasta respaldo/restauración verificados y autorización. NO-GO de integración actual hasta validación remota controlada y revisión de los cambios de permisos. La estrategia de supresión es una propuesta pendiente, no se ha activado ni se declara legalmente validada.

## Resultados finales locales

- `flutter analyze`: sin incidencias; `flutter test`: 286 aprobadas, 11 omitidas (integraciones sin configuración remota, sin habilitar acceso remoto para estas pruebas).
- `python3 scripts/test_supabase_security_local.py --legacy-acl-drift --diagnose-auth`: 18 suites, 417 aserciones TAP aprobadas. Correcciones: 59/59; eliminación: 20/20 y 23/23; seguridad de acceso: 58/58; privilegios mínimos: 5/5. Evidencias: `/tmp/cercly-security-results-43gc30pp/`. PostgreSQL en un contenedor nuevo, sin red y con imagen fijada; se detuvo al terminar.
- Confirmadas: DML directo administrativo de información denegado, mezcla de datos/estado denegada, categoría por trigger denegada, RPC invoker de horarios y fotos denegadas, privilegios RPC sin anon/server innecesario, moderación restringida, propietario ajeno sin acceso, solicitud válida/duplicada, rechazo, doble aprobación, auditoría y dependencias de supresión.
- Inyección de grants heredados, errores preflight Auth, rollback por errores de aprobación y ACL, concurrencia de 8 solicitudes y huellas de datos antes/después: PASS.
- La ejecución de contención `/tmp/cercly-security-results-xmjapfpd/` confirmó rollback del catálogo para las cuatro migraciones históricas de seguridad/eliminación. Esa ejecución se detuvo posteriormente por dos expectativas antiguas de permisos en security_access_test; se corrigieron para exigir denegación por ACL de columna y la ejecución final completa anterior aprobó. No se declara probado lock_timeout de las dos migraciones nuevas.
- El arnés conserva el rechazo de nuevas versiones no incluidas en su manifiesto cerrado; aplica las dos migraciones nuevas no idempotentes una sola vez y verifica que no alteren datos previos ni creen auditoría ficticia. No se convirtió el nuevo CREATE TABLE en idempotente para ocultar errores.
- `git diff --check`: correcto. Cambios locales sin commit/push; geofencing y fuentes Dart/Android sin cambios.
