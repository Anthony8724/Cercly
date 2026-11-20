# Controles UGC de Cercly 1.0

## Recuperación y alcance

La rama `compliance/ugc-cercly-1.0` parte de `f90c382420a3732032591784c00b3077e7f8dedf`, HEAD comprobado del PR Android #41. Esa base contiene el trabajo de RC2 y la integración de `develop` en `3ef19a820263c2add7db27a78d43570dd5f52cfd`. El worktree permanente está en `~/Proyectos/Cercly-ugc-1.0`. La rama anterior y `test/failures/` del worktree de integración se conservaron.

No se encontró una copia de los cambios en el historial de VS Code, la papelera ni los respaldos identificados. El listado de instantáneas Btrfs devolvió un error de permisos. Se recuperaron los archivos a partir de parches del historial local de la sesión y se contrastaron con esta base. Para la web se conservó también el commit local `a7cb59b` del trabajo del PR #15.

## Cambios

| Área | Archivos y comportamiento |
| --- | --- |
| Servidor | `supabase/migrations/20261120034446_controles_ugc_cercly.sql` registra identidad, fecha, versión y huella de la aceptación. Aplica la aceptación en PostgreSQL y en los buckets de imágenes. |
| Denuncias y bloqueo | La app permite denunciar la ficha, su foto visible, una promoción y la cuenta responsable. Bloquear a la cuenta propietaria oculta sus negocios y publicaciones para el usuario que bloqueó. Los colaboradores publican a nombre de ese responsable. Una ficha OSM sin responsable registrado sigue siendo denunciable como ficha. |
| Moderación | La cola del panel administrativo muestra los casos, contenido e historial disponibles. Solo un administrador independiente con sesión vigente y reciente puede cambiar el estado. Se registra el motivo, el responsable de la acción y la transición. Retirar oculta el contenido del catálogo y conserva el registro. |
| Permisos | Las políticas restrictivas se suman a los grants y políticas existentes. La aceptación no concede propiedad. Los RPC limitan consultas y cambios al actor autenticado o al moderador autorizado. Los reportes abiertos duplicados convergen por usuario y objetivo. El límite es 10 envíos nuevos en una hora y 20 en un día. |
| Flutter | `lib/features/ugc/` contiene el servicio, diálogo, denuncias, bloqueos y cola. Los cambios integran esas pantallas en Mi cuenta, administración, detalle, flujos de edición y publicaciones. Explorar, mapa y promociones vuelven a consultar el catálogo después de un bloqueo. |
| Pruebas | `supabase/tests/ugc_play_test.sql`, `scripts/test_ugc_http_local.py` y `test/ugc_controls_test.dart` cubren la aplicación del contrato nuevo. Los cambios en tres pruebas existentes modelan la aceptación como condición previa para conservar sus casos de edición y errores HTTP. |

### Publicación y compatibilidad

En un stack sintético, la versión recuperada devolvió HTTP 403, SQLSTATE `42501`, al insertar una foto con `Prefer: return=representation`. El mensaje señaló `ugc_fotos`. La política buscaba la misma foto por ID mientras PostgreSQL aún evaluaba la fila insertada. Ahora usa el ID y el establecimiento de la fila que evalúa. La consulta del establecimiento conserva su RLS y el predicado privado solo consulta bloqueos y moderación. Storage mantiene sus SELECT existentes a través de esas tablas, incluidos los permisos de gestión ya autorizados.

El ensayo comprobó también que el propietario con normas aceptadas puede enviar un registro y que el administrador puede tramitarlo mediante el RPC existente, transcribiendo la ficha y el horario. La comprobación de sesión rechazó la modificación con un JWT revocado mediante HTTP 403, SQLSTATE `28000`, y el bloqueo persistió.

### Evidencias

Archivos en `~/Proyectos/Cercly-evidencias-1.0`:

| Archivo | Resultado |
| --- | --- |
| `http-reproduccion.log` | 6 comprobaciones antes del fallo reproducido en `ugc_fotos`. |
| `http-final.json` y `http-final.log` | 49 aprobadas y 0 fallidas en Auth, PostgREST y Storage locales. Incluye altas autorizadas con representación, altas ajenas rechazadas, denuncias concurrentes, aislamiento entre lectores y retirada. |
| `sql-final.log` | 802/802 de la base antes de aplicar UGC y 40/40 posteriores a la migración. 31 suites en total. Las pruebas con rollback conservaron las huellas de datos del arnés. |
| `flutter-final.log` | 479 aprobadas, 21 omitidas y 0 fallidas. Las pruebas que dependen de un backend alojado no se habilitaron. |
| `flutter-ugc.log` | 11/11 de interfaz, incluidas en el total Flutter. |
| `analyze-final.log` | Analizador sin incidencias. Formato Dart y diff comprobados. |

Los intentos intermedios conservaron evidencia separada. El reinicio del stack falló en el DNS local. Un fixture SQL duplicó el orden de una foto. Una política adicional de Storage rechazó al visitante al comprobar el permiso de una función de colaborador, por lo que se conservó el flujo de lectura original. La prueba de revocación se corrigió para comprobar el SQLSTATE y que la operación no cambiara el bloqueo, además del estado HTTP.

## Antes de distribuir

- El titular debe aprobar el texto de las normas y confirmar quién atiende la cola, cómo se escalan casos y qué se conserva de aceptaciones, bloqueos, denuncias y actuaciones.
- Las URL firmadas antes de una retirada pueden seguir funcionando hasta su vencimiento. Las pruebas demuestran la exclusión en nuevas consultas y nuevas firmas.
- Las nuevas FK identificadas permiten la retirada por cascada de aceptaciones y bloqueos propios. Cuando el sujeto figura en denuncias o actuaciones, el servidor deriva a revisión. Se necesita validar el procedimiento operativo de supresión en un entorno autorizado antes de distribuir la app.
- La combinación app y backend requiere validación en Staging autorizado y en un HONOR real. La regresión local no acredita la configuración alojada ni el funcionamiento en un dispositivo.

Estado para Google Play **NO-GO** hasta atender esos puntos y aprobar la web legal. La numeración de lanzamiento corresponde a la futura candidata. Referencia oficial de los controles de contenido [Política UGC de Google Play](https://support.google.com/googleplay/android-developer/answer/9876937).
