# Eliminación: evidencia HTTP real y alcance de la migración

19/11/2026 (hora Ecuador; registros UTC hasta el 20/11). **43 comprobaciones PASS, 0 FAIL en la ejecución final. NO-GO para prueba cerrada alojada.** No se repitieron las 802 aserciones SQL ni Flutter ya aprobados: no cambiaron la migración, el handler ni el código Android.

## Qué se ejecutó

Instalación nueva `cercly-delete-http-20261119`, creada sin restaurar bases ni montar datos reales. Supabase CLI 2.119.0, imágenes locales existentes, red Podman **internal=true**, puertos de prueba 56431/56432. Servicios GoTrue v2.197.0, PostgREST, Storage v1.79.28 y Postgres 17.11.0.002. Deno 2.9.8 y SDK supabase-js **2.75.0**, como el entrypoint de eliminación. No hubo acceso de este ensayo a Staging, Production, SMTP externo o HeiGIT.

Se invocó por HTTP el handler real `createNormalDeletionHandler`, sin dobles, desde un servidor Deno en 127.0.0.1:56435. Auth, RPC y Storage son servicios reales. **No se probó el gateway Edge ni su verify_jwt**: el handler verifica getUser por sí mismo. El entorno alojado puede tener otras versiones/configuraciones.

| Comprobación | Resultado y evidencia |
|---|---|
| Alcance de migración | Una sola función reemplazada, sin DML/ALTER/GRANT; se añade únicamente la firma exacta de FK de cuota |
| Regresión antes/después | Al retirar solo esa excepción dentro de una transacción de prueba reaparece el bloqueo global; al aplicarla desaparece para UUID inexistente |
| Integridad de migración | Dueño, ACL, SECURITY DEFINER y search_path iguales; huella de datos preexistentes public/Auth/cuota/Storage conservada |
| Caso simple real | Alta y login GoTrue, sesión/refresh reales, cuota por RPC, preferencias/categorías e instalación FCM sintética inactiva |
| Eliminación por handler | HTTP 200 eliminada; desaparecen Auth, perfil, sesiones, refresh, cuota, preferencias, categorías, push, instalación y solicitud |
| Sujeto ajeno | Cuerpo que intenta elegir otro UUID rechazado HTTP 400 |
| Token anterior | Auth rechaza con HTTP 403 y error_code=user_not_found; refresh rechazado; JWT antiguo no puede recrear cuota PostgreSQL |
| Fotos reales de prueba | PNG sintéticos subidos mediante API Storage con JWT de cada titular y bytes comprobados |
| Foto propia existente | Handler devuelve 202 revisión y conserva Auth, sesión y foto; no borra el objeto silenciosamente |
| Retirada autorizada de foto | El titular sintético usa DELETE Storage; desaparece metadato y ya no se recuperan bytes por API, incluso usando credencial local de servicio |
| Revisión posterior | No se aprueba sola tras retirar la foto. Administrador sintético aprueba por RPC; posterior handler elimina la cuenta y finaliza solicitud |
| Datos ajenos | Auth/perfil, negocio, promoción, relación de foto y cuota del otro usuario coinciden antes/después; sus bytes/hash de imagen siguen iguales |
| Propietario con negocio | Permanece en revisión; negocio, promoción y foto no se eliminan |

Los identificadores/tokens/passwords solo existieron en el entorno de prueba y no se incluyen en Git ni en la evidencia saneada. No se envió ningún mensaje real de soporte. La prueba no acredita borrado forense en disco, replicación, cachés o respaldos del proveedor.

## Evidencia y arnés

- [Resultado de cada caso](evidencias/eliminacion-http-local.json).
- `scripts/run_account_deletion_http_local.py` inicia y detiene solo su handler.
- `scripts/serve_account_deletion_http_local.ts` usa el handler/SDK reales con guardia de URL local.
- `scripts/test_account_deletion_http_local.py` comprueba nombre/red local, crea sus sujetos y solo elimina los UUID devueltos por sus propias altas. Rechaza credenciales fuera de /tmp o legibles por otros usuarios.
- Las versiones, hashes y comprobación de parada están en `evidencias/eliminacion-http-procedencia.json`.

Dos intentos previos se detuvieron en una expectativa del arnés: primero exigía 401, después buscaba la cadena de error en `code` (numérico), cuando este GoTrue devuelve 403 con `error_code=user_not_found`. Se corrigió para comprobar rechazo y código semántico; **no se modificó ni relajó seguridad del servidor**. El lanzador final se ejecutó completo con otras cuentas nuevas: 43/43. Los informes de esos intentos se conservan saneados como evidencia.

## Reproducción sin tocar un proyecto existente

1. Usar CLI 2.119.0 y las imágenes fijadas en la procedencia; no actualizar SDK/migraciones para hacer pasar el ensayo. Crear un directorio **nuevo** /tmp/cercly-delete-http-20261119 mediante `supabase init --workdir ...`, sin `.temp/project-ref` ni enlace remoto. Si ya existe, no sobrescribirlo: preservar evidencias y preparar otro ensayo revisando los guards.
2. Copiar solo `supabase/migrations` a ese directorio. En su config generado, mantener project_id=cercly-delete-http-20261119 y cambiar puertos 54321/22/20/23/24/27/29 a 56431/32/30/33/34/37/39. Seed vacío/deshabilitado; no copiar .env ni claves reales.
3. Usar un socket Podman local temporal y crear red `podman network create --internal cercly-delete-http-20261119`. Arrancar **ese workdir** con `--network-id cercly-delete-http-20261119 --exclude studio,realtime,imgproxy,mailpit,postgres-meta,edge-runtime,logflare,vector,supavisor`. No utilizar --ignore-health-check, remoto, ni reset sobre un contenedor existente.
4. Guardar únicamente API_URL, ANON_KEY y SERVICE_ROLE_KEY de **ese stack local** en un JSON /tmp protegido 600, dentro de directorio 700. No imprimirlo, subirlo ni mezclarlo con credenciales alojadas. El API_URL debe ser exactamente http://127.0.0.1:56431.
5. Con supabase-js 2.75.0 en la caché Deno, ejecutar desde la rama:

   ```sh
   python3 scripts/run_account_deletion_http_local.py --credentials /tmp/ensayo-privado/local-credentials.json --report /tmp/ensayo-privado/resultados.json
   ```

   El lanzador usa cached-only y allow-net limitado a los dos puertos localhost; termina su servidor en finally. El reporte no contiene claves.
6. Detener solo `supabase stop --project-id cercly-delete-http-20261119 --workdir /tmp/cercly-delete-http-20261119` con el mismo socket. **No usar --all ni --no-backup.** El ensayo actual quedó detenido y sus volúmenes sintéticos preservados; no se tocó ningún otro contenedor.

## Bloqueos que permanecen

Lectura remota final: UUID cero inexistente, tiene_dependencias=true, cuota reconocida=false y migración 20261119231916 no registrada. No se ejecutó DDL/DML remoto. Autorizar explícitamente la prueba/configuración alojada y después el despliegue de Production por separado.

Faltan: flujo de cuenta con negocio/historial que requiera decisiones reales de minimización; correo/portal externo, titularidad, respuesta y confirmación; ciclos de respaldos y retención; prueba en entorno alojado con versiones/configuración equivalentes. Instalar RC2 no aplica esta migración. Eliminar Auth no equivale a que todo JWT sea criptográficamente inválido: las operaciones sensibles deben seguir verificando identidad/sesión; el catálogo público sigue siendo público.

Referencia oficial de Auth/Storage y tokens: https://supabase.com/docs/guides/auth/managing-user-data.
