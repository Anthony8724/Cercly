# Auditoría histórica de la propuesta inicial de correcciones

**Documento supersedido:** la propuesta inicial fue sustituida por la migración
`supabase/migrations/20261106034310_aplicar_correcciones_estructuradas.sql`.
Su veredicto NO-GO corresponde únicamente al diseño anterior. Consulte el
informe de correcciones estructuradas para el estado actual.


**Fecha:** 5 de noviembre de 2026. **Rama:** `fix/promociones-solicitudes-sky`.
**Alcance:** propuesta local inicial (retirada al convertirla en migración) y sus contratos actuales. La propuesta no es una migración activa; no se aplicó a Production ni Staging.

## Resultado

**NO-GO para desplegar la propuesta tal como está.** La seguridad básica del RPC superó las pruebas locales, pero dos decisiones de producto/privacidad y una de operación siguen abiertas:

1. **Crítico — divergencia respecto de la solicitud:** hoy el solicitante entrega texto libre (`datos_propuestos.descripcion_solicitud`); el administrador puede aprobar cualquier cambio de los siete campos permitidos, aunque no conste en esa descripción. La RPC prueba que el actor es administrador y guarda el antes/después, pero no puede demostrar que el solicitante pidió exactamente esos valores. El diálogo exige revisión humana, no establece correspondencia verificable con una propuesta estructurada. Se necesita definir una propuesta de campos y valores y su validación, o un procedimiento de revisión explícito que trate las correcciones como decisiones administrativas y deje claro ese alcance al solicitante.
2. **Alto — retención y eliminación:** `correcciones_aplicadas.solicitud_id` tiene FK sin regla de borrado (`NO ACTION`). En local, borrar una solicitud aprobada con historial falla con `23503`, incluso bajo un rol SQL administrativo. La política de eliminación de cuentas ya considera las solicitudes dependencias; la nueva FK añade otra dependencia para cualquier limpieza futura. Antes del despliegue hay que definir retención, borrado autorizado y preservación o anonimización del historial. No debe cambiarse a `CASCADE` sin esa decisión porque eliminaría la trazabilidad.
3. **Alto — reversión posterior al despliegue:** el archivo incluye `BEGIN`/`COMMIT`, por lo que un fallo de aplicación revierte el esquema. No hay migración versionada ni procedimiento seguro para retirar el esquema después de que existan correcciones aplicadas. Eliminar la tabla destruiría pruebas de revisión; quitar el trigger reabriría la aprobación antigua sin actualización de ficha. La recuperación posterior debe conservar historial y usar una migración de avance.

## Operaciones exactas propuestas

| Objeto | Operación | Permisos y efecto |
|---|---|---|
| `public.correcciones_aplicadas` | Crear tabla con PK/FK a solicitud; guarda negocio, revisor, fecha, motivo y JSON `antes`/`despues`. La PK crea índice para el lookup por solicitud. | RLS activada. `REVOKE ALL` a `public`, `anon`, `authenticated`; solo `GRANT SELECT` a `authenticated`. No hay escritura directa de cliente. |
| Política `revisor y solicitante leen correccion aplicada` | Crear política `SELECT`. | Administrador o solicitante de la solicitud. La comprobación de identidad usa `auth.uid()` y la solicitud relacionada. Un tercero no ve historial. |
| `public.validar_aprobacion_correccion()` | Crear función de trigger `SECURITY DEFINER`, `search_path=''`. | Rechaza cambiar estado a `aprobada` para una corrección sin historial previo. `EXECUTE` revocado a roles públicos/clientes; el trigger la invoca internamente. |
| Trigger `validar_aprobacion_correccion` | Crear `BEFORE UPDATE` en `public.solicitudes_establecimientos`. | Impide que clientes anteriores usen la RPC vieja para aprobar sin aplicar la corrección. No altera otros tipos ni rechazos. |
| `public.aplicar_correccion_establecimiento(uuid,jsonb,jsonb,text)` | Crear RPC `SECURITY DEFINER`, `search_path=''`. | `EXECUTE` solo a `authenticated`; dentro comprueba `auth.uid()` y `public.es_administrador()`. Actualiza los siete campos permitidos, inserta auditoría y cierra solicitud mediante la RPC existente en una transacción. |

No cambia tablas, políticas, RLS ni funciones existentes; no crea usuarios, promociones ni geofences. La RPC **actualiza filas de establecimientos** solo cuando la invoca un administrador autorizado tras desplegarse.

## Autorización y alcance de cambios

`public.es_administrador()` consulta el rol de `public.usuarios` para el `auth.uid()` de la sesión; no confía en metadatos editables del perfil. La RPC exige ese rol antes de leer o bloquear la solicitud. El solicitante no puede autoaprobar; `anon` no tiene `EXECUTE`. El `SECURITY DEFINER` está delimitado por `search_path=''`, comprobación de rol, lista explícita de campos y validaciones. El usuario puede presentar una solicitud; esa acción no le otorga propiedad ni membresía.

El SQL solo escribe `nombre`, `direccion`, `categoria_id`, `descripcion`, `telefono_publico`, `latitud` y `longitud`. Rechaza claves adicionales como `propietario_id`, valores inválidos, categorías inactivas, fichas privadas/no aprobadas, propuestas vacías y datos de revisión obsoletos. La columna geográfica generada se recalcula desde latitud/longitud. La PK de la auditoría y la condición `estado='pendiente'` evitan la doble aprobación. El índice parcial existente `solicitud_pendiente_unica` impide que el mismo usuario tenga dos solicitudes pendientes del mismo tipo para el mismo negocio; solicitudes de distintos usuarios son posibles y requieren revisión individual.

La tabla de historial guarda el antes y el después, hora, motivo y UUID del revisor. La prueba local verificó ambos JSON, el cambio de categoría y coordenadas, y la actualización de la ubicación geográfica. Los clientes autenticados carecen de `INSERT`, `UPDATE` y `DELETE` sobre esa tabla. Un actor privilegiado de base de datos conserva capacidades administrativas, como en el resto del esquema.

## Rechazo, errores y recuperación

- **Rechazo:** la RPC existente `responder_solicitud_establecimiento(...,'rechazada',motivo)` exige motivo, registra el estado y no toca ficha ni historial de correcciones aplicadas.
- **Errores antes del cierre:** validación, datos obsoletos, geografía inválida, solicitud no pendiente o error de escritura abortan la llamada. Se inyectó un fallo en el trigger de cierre: ficha, solicitud e historial permanecieron en sus estados anteriores.
- **Durante el despliegue:** ejecutar la versión final en una transacción versionada; si falla antes de `COMMIT`, abortar la transacción y comprobar que no existen los nuevos objetos.
- **Después del despliegue, sin filas aplicadas:** es posible preparar una reversión de objetos dentro de una nueva migración, siempre que se compruebe el historial vacío y se acepte que la aprobación de correcciones quedaría suspendida. No se ha preparado esa migración porque falta la decisión sobre retención.
- **Después de aplicar cambios:** revocar temporalmente `EXECUTE` de la nueva RPC si hay un incidente; mantener trigger y auditoría, investigar solicitudes afectadas y corregir mediante una nueva migración o una reversión **individual auditada** de los valores del negocio. No borrar la tabla ni restaurar toda Production indiscriminadamente.
- **Solicitudes ya aprobadas por la función antigua:** no hay garantía de que sus cambios se aplicaran. No deben recibir entradas de auditoría inventadas ni procesarse otra vez sin revisión separada.

## Pruebas ejecutadas

`python3 scripts/test_correcciones_local.py` reconstruyó todas las migraciones del repositorio en un contenedor PostgreSQL Supabase nuevo, sin red y con imagen local; lo detuvo al finalizar. Resultado: **37/37** pruebas de correcciones, **12/12** de registro, **17/17** de reclamo: **66/66 aprobadas**. Las nuevas pruebas confirmaron actualización ajena `UPDATE 0`, duplicado `23505`, falta de `EXECUTE` para `anon`, falta de escritura directa del historial, doble aprobación bloqueada, lectura RLS y bloqueo de eliminación `23503`. La evidencia local está en `artifacts/solicitudes-sky-20261105/sql-*.log` y en el arnés `scripts/test_correcciones_local.py`.

`git diff --check` correcto. Las pruebas Flutter previas de esta rama fueron **284 aprobadas, 11 omitidas**, y `flutter analyze` sin incidencias. Esta auditoría solo añadió pruebas SQL y este informe; no cambió código Flutter, Android, geofencing, notificaciones, Supabase remoto ni APK.

## Condiciones para reconsiderar GO

1. Decidir el contrato de propuestas: valores estructurados verificables o aprobación administrativa explícita de una corrección editorial, con trazabilidad y texto claro para el solicitante. Agregar las pruebas de esa regla.
2. Decidir retención/eliminación del historial; ajustar FK y procedimiento de eliminación de cuentas de modo coherente, sin borrar evidencia accidentalmente. Probar ambos casos.
3. Convertir la propuesta revisada en una migración versionada por el flujo del repositorio, con control de tiempo de espera y plan de recuperación. Antes de Production, verificar grants/RLS, definición de la RPC y caché de PostgREST en un entorno autorizado.
4. Validar con cuentas de solicitante y administrador reales en un entorno autorizado. Las pruebas locales no confirman aún integración HTTP ni datos desplegados.

Hasta entonces, la aplicación debe seguir mostrando que la corrección no puede aplicarse cuando falta la nueva RPC. El rechazo conserva su comportamiento actual.
