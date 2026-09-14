# Reclamación de establecimientos OSM

## Flujo del MVP

1. Un establecimiento público es reclamable únicamente si procede de OSM,
   está `no_reclamado`, no tiene propietario, está aprobado y es publicable.
2. El usuario autenticado crea una solicitud de tipo `reclamar`.
3. El índice parcial existente impide otra solicitud pendiente del mismo tipo,
   usuario y establecimiento.
4. Un administrador aprueba o rechaza la solicitud desde el panel existente.
5. La aprobación asigna el propietario, cambia el reclamo a `reclamado`,
   registra la fecha y promueve el rol del usuario cuando corresponde.
6. La verificación no es automática. El estado `verificado` queda reservado
   para una revisión administrativa posterior.

Las solicitudes `acceso` conservan la creación o reactivación de una membresía
de editor. Las solicitudes `correccion` continúan siendo informativas: aprobarlas
no modifica automáticamente el establecimiento.

## Evidencias

La tabla `evidencias_solicitud` y sus políticas se conservan sin cambios. La
subida de documentos no forma parte de este ajuste del MVP y queda preparada
para una fase posterior.

## Prueba manual

1. Entrar como usuario y abrir el detalle de un OSM no reclamado.
2. Pulsar **Reclamar establecimiento**, escribir el motivo y enviar.
3. Entrar como administrador, abrir Solicitudes y aprobar el reclamo.
4. Volver a iniciar sesión con el usuario solicitante.
5. Abrir **Mi negocio** y verificar que el establecimiento asignado aparece.
6. Editar un dato permitido y guardar para confirmar la gestión del propietario.

Si se rechaza la solicitud, debe indicarse un motivo. El establecimiento debe
conservar propietario nulo y estado `no_reclamado`.
