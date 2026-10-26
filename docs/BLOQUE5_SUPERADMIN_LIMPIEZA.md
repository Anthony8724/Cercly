# Bloque 5 — capacidad superadministradora y limpieza futura

## Estado y arquitectura

Trabajo local en `fix/auth-perfiles-automaticos`, sin asignaciones, borrados ni despliegues. Los cambios de Cercly Sky Fase 3 y `README.md.respaldo` se conservan. Las migraciones de seguridad y eliminación de octubre siguen pendientes de confirmar en staging antes de considerar producción.

`public.usuarios.rol` es el rol de autorización existente (`usuario`, `propietario`, `administrador`). `public.es_administrador()` gobierna las políticas RLS administrativas. `public.establecimientos.propietario_id` y `public.miembros_establecimiento` representan propiedad y colaboración; promociones, fotos, horarios y solicitudes dependen del establecimiento. El cliente no puede editar `usuarios.rol`: la migración de seguridad revoca escrituras y el trigger protege identidad y rol. `recuperar_mi_perfil()` usa el UUID de la sesión, no metadatos del usuario.

Las migraciones `20261026064908_capacidad_superadministrador.sql` y `20261026072156_aislar_operaciones_propietario_y_auditar_superadmin.sql` añaden una **capacidad** privada asociada a un UUID de perfil administrador. No añaden otro valor a `rol_usuario` ni conceden capacidad a ninguna cuenta. `mis_capacidades()` devuelve solo las capacidades de `auth.uid()`; no recibe UUID ni correo como parámetro. El cliente no tiene DML sobre concesiones ni auditoría, tampoco `service_role` de cliente. La cuenta candidata indicada por el responsable aún no tiene UUID verificado ni permiso asignado. El rol `service_role` jamás se distribuye en Flutter.

## Modos de interfaz

`Usuario` está disponible para toda sesión. `Propietario` aparece cuando el servidor encuentra un establecimiento propio o membresía activa. `Administración` requiere `usuarios.rol = administrador`; un administrador normal no obtiene la capacidad superadministradora. La cuenta con esta capacidad puede usar los tres modos **si tiene propiedad o membresía**. El selector en Mi cuenta y en los paneles recuerda la elección por UUID en preferencias locales. Al cambiar de modo y al reanudar la app se consultan de nuevo los permisos. Una preferencia manipulada se descarta si el servidor no autoriza ese modo. La elección visual no cambia RLS ni convierte al usuario en dueño de otros negocios.

Los servicios del panel propietario consultan establecimientos por `propietario_id` o membresía. Lecturas de promociones/fotos, URLs firmadas y escrituras del panel comprueban `public.puede_gestionar_como_propietario(uuid)`, que deliberadamente no consulta `es_administrador()`. La ruta administrativa continúa usando políticas y servicios administrativos existentes. La autorización efectiva de una identidad administradora conserva el alcance que ya otorgan RLS y Storage: estos controles hacen que las operaciones del cliente en el flujo Propietario fallen para un negocio no asignado, pero el modo guardado localmente no reduce los permisos de esa sesión y el administrador puede seguir usando sus rutas autorizadas o APIs directas. **No hay aislamiento absoluto entre modos con el mismo JWT.** Para eso se necesitaría una identidad/token distinto o un cambio del modelo de autorización del servidor.

## Auditoría y bootstrap superadministrador

Cada concesión o revocación confirmada genera una fila inmutable con UUID de titular y actor, tipo, fecha, motivo, referencia de aprobación, resultado, `session_user` de PostgreSQL y `txid_current()`. La fila activa conserva motivo y actor de otorgamiento; al revocar exige actor, fecha, motivo y referencia separados. No se permite borrar una concesión activa, reactivarla ni cambiar sus datos de origen. Una cuenta Auth solo se puede borrar tras revocar su capacidad. Los UUID de auditoría no llevan FK a Auth para conservar evidencia sin bloquear una baja posterior.

El trigger valida que titular y actor sean administradores distintos, con email confirmado y proveedor Google en `raw_app_meta_data`; la referencia debe estar presente. Esto valida el estado de las identidades, pero **no demuestra quién operó el SQL Editor ni que una referencia externa sea auténtica**. `session_user` y el ticket permiten contrastar esa operación. Se exige verificación humana y registro externo; la tabla guarda operaciones aplicadas. Los intentos rechazados se revierten junto con la transacción, así que se conservan en logs administrativos externos y no se simulan como filas de una transacción abortada.

Bootstrap futuro: dos responsables verifican por separado la identidad, el UUID de Auth y una sesión Google reciente; uno confirma el perfil administrador y el otro revisa la aprobación. Después ejecutan una única transacción privilegiada en una ventana registrada, indicando actor administrador distinto, UUID exacto del titular, motivo y ticket aprobado. Comprueban la fila de auditoría (principal DB y transacción incluidos) y cierran el acceso operativo. No existe RPC cliente ni endpoint permanente de otorgamiento. Si no existe otro administrador, un responsable de plataforma autoriza y documenta la operación inicial bajo doble control. El correo candidato no basta como prueba. Este bloque no concedió capacidad a ninguna cuenta.

## Verificación previa a cualquier concesión

1. En un entorno autorizado, identificar el usuario en Supabase Auth por el correo candidato y anotar su **UUID**, identidades de proveedor, estado de verificación y fecha de acceso. El correo visible, `user_metadata` y la preferencia local no constituyen prueba de identidad.
2. Confirmar con el titular una sesión Google reciente y que el UUID observado corresponde a su cuenta; revisar homónimos, cambios de correo, cuentas duplicadas y proveedor vinculado.
3. Revisar el perfil `public.usuarios` del mismo UUID, las dependencias, el administrador otorgante distinto del titular y una justificación aprobada. Conceder primero el rol administrador mediante el procedimiento institucional existente, después la capacidad adicional mediante una operación privilegiada auditada. No hay una ruta de autoasignación en la app.
4. Probar revocación, pérdida de rol y recuperación administrativa en staging con cuentas sintéticas. La recuperación requiere dos responsables autorizados y evidencia de identidad; no se crea una puerta trasera basada en correo.

## Inventario y simulación de limpieza

`scripts/sql/vista_previa_limpieza.sql` es una transacción **READ ONLY**. Entrega conteos, UUID de Auth con relaciones, dependencias por establecimiento, objetos agrupados por bucket/propietario y el grafo de claves foráneas. No contiene `DELETE`, `UPDATE` ni clasificación automática. Solo un operador autorizado debe ejecutarlo en un entorno aprobado y proteger su salida, que incluye UUID. No se consultó Supabase remoto en este bloque.

Clasificación posterior, con evidencia documentada por registro:

- **Conservar:** UUID principal confirmado, cuentas reales, registros de usuarios con actividad legítima y datos estructurales (categorías, subcategorías, políticas, migraciones, configuración y taxonomía).
- **Candidato ficticio:** únicamente registros vinculados a una cuenta de prueba documentada, creados con consentimiento para ensayo y sin relaciones reales o compartidas.
- **Revisión manual:** cualquier cuenta o negocio sin evidencia concluyente, objetos huérfanos, establecimientos compartidos y solicitudes o promociones con dependencias cruzadas.

Los respaldos locales previos sirven solo como referencia histórica; no prueban el estado remoto actual. Antes de una futura limpieza aprobada: obtener un volcado consistente de Auth, perfiles, tablas públicas y esquemas privados con roles/ACL; exportar por separado **los binarios** de Storage y un manifiesto bucket/ruta/tamaño/SHA-256; cifrar el material y restringir acceso. Restaurar ambos en un staging aislado, comprobar conteos, FK, accesos RLS y hashes de objetos, y ensayar allí el procedimiento. Un volcado de `storage.objects` no restaura por sí solo los archivos. Registrar punto de recuperación y responsables.

Tras aprobación explícita para una limpieza futura, volver a capturar inventario y dependencias; separar negocios compartidos y cuentas reales; revisar solicitudes, membresías, promociones, fotos, horarios y objetos antes de actuar. La secuencia exacta de cambios debe prepararse y aprobarse para los UUID concretos después del ensayo de restauración. Verificar después conteos, integridad referencial, archivos, inicio de sesión de cuentas conservadas, RLS y acceso a negocios. Ante discrepancias, detener el proceso y restaurar desde el respaldo verificado. Este documento no autoriza ni contiene instrucciones de eliminación remota.

## Puertas pendientes

Confirmar UUID e identidad Google; definir autoridad de concesión/revocación y retención de la evidencia; validar migraciones pendientes en staging; ensayar backup y restauración de Storage; revisar el inventario remoto con un operador autorizado; aprobar por separado cualquier cambio de permisos o limpieza. Producción permanece **NO-GO**.
