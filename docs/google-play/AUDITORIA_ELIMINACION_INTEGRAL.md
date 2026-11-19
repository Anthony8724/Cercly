# Bloque C — auditoría de eliminación integral

19/11/2026. Lecturas de metadatos en Production y pruebas locales sintéticas; ninguna eliminación remota ni modificación de datos reales.

## Hallazgo confirmado

La migración de cuota introdujo cercly_rutas_privado.rutas_limites_usuarios → auth.users, CASCADE y validada. La función privada tiene_dependencias inspecciona también el catálogo completo de FK y cierra el proceso ante cualquier relación no reconocida. El helper desplegado no conoce esa FK: su existencia hace que la guarda devuelva true incluso para un UUID inexistente, sin depender de si el usuario pidió rutas.

Diagnóstico remoto de solo lectura: UUID cero inexistente; tiene_dependencias(UUID cero)=true; FK de cuota no reconocida por helpers FCM ni plataforma. Por tanto, el proceso no puede considerarse integralmente operativo. Solicitar eliminación no equivale a borrar y una aprobación manual no elude las revalidaciones de dependencias.

## Corrección preparada, NO desplegada

20261119231916_reconocer_cuota_rutas_eliminacion.sql amplía la lista del helper existente con una única firma: esquema, tabla, nombre de constraint, columna usuario_id, Auth.id, CASCADE y validación. CREATE OR REPLACE conserva dueño y permisos. No concede acceso al esquema privado ni excepciones genéricas para otras cascadas.

Regresiones: 15/15. Una cuota propia permite la solicitud y cascada; FK desconocida, cambio a RESTRICT o FK no validada vuelven a bloquear. La eliminación sintética borra cuota, perfil y sesiones. El arnés actualiza su lista cerrada con la migración de rutas y la corrección; no omite suites ni relaja controles.

## Inventario del mecanismo real

| Componente | Verificado | Límite |
|---|---|---|
| Edge eliminar-cuenta | Production v3 ACTIVE, verify_jwt=true; cuatro archivos coinciden exactamente con código local | No acredita un borrado HTTP real |
| Identidad y sesión | getUser verifica sujeto; cuerpo vacío; RPC exige auth.sessions reciente; no acepta usuario ajeno en el body | JWT emitido no desaparece por revocar refresh tokens |
| Solicitud y revalidación | Solicita, valida, revoca globalmente, revalida y después usa Auth.admin.deleteUser | Auth y SQL no forman una sola transacción; hay estados pendientes |
| Perfil y relaciones propias | FK Auth→usuarios, preferencias y ciertas instalaciones en cascada | No todo vínculo se borra automáticamente |
| Establecimientos/promociones | Dependencias protegidas exigen revisión; propietario, solicitudes y moderación no se eliminan sin resolver | No autorizar transferencia/borrado ajeno automáticamente |
| Fotografías | Dos buckets privados con MIME/tamaño limitado, RLS de lectura pública condicionada y gestión por permisos; objetos del sujeto bloquean supresión | El flujo no elimina bytes de Storage; no prometer eliminación de fotografías por borrar Auth |
| Sesiones/tokens | Revocación global previa; cascadas Auth y guardas de identidad RLS; limpieza local de sesión, preferencias y notificaciones | Comprobar comportamiento del JWT antiguo con GoTrue/PostgREST real |
| Solicitudes y auditorías | Cola y estados; historial puede exigir revisión; finalización solo tras desaparición de Auth | No existe una retención general aprobada que justifique conservar todo indefinidamente |
| Datos económicos | Confirmaciones/referencias administrativas y auditoría deben entrar en revisión de retención | No hay prueba para afirmar que Auth.deleteUser los suprime todos |
| Canal externo | Página y correo; formulario condicionado; portal OTP bloqueado por ACCOUNT_DELETION_PORTAL_VERIFIED=false | Contactar o recibir una aceptación Formspree no elimina ni prueba titularidad |

## Prueba ejecutada

scripts/test_supabase_security_local.py crea un contenedor nuevo con imagen fijada local, --pull=never, --network none, sin montar datos ni copiar un respaldo real. Todas las migraciones y 30 suites pgTAP aprobaron: **802/802**, incluidas 15 nuevas de rutas, 24 de eliminación básica, 20 de política y 42 de dependencias FCM. Cada suite revierte sus fixtures; el arnés verifica integridad y detiene únicamente su contenedor.

Node: 37 pruebas de eliminación/sesión/FCM aprobadas con dobles. Se revisan sujeto autenticado, cuerpo, CORS, errores, orden de validación/revocación y fallos parciales. SQL crea filas sintéticas de Auth/Storage: **no** es un ensayo real de GoTrue, OTP, API Storage ni eliminación de archivos físicos.

## Procedimiento pendiente tras aprobación de despliegue

1. Revisar migración y permisos, respaldos y estado de migraciones sin copiar datos reales a QA.
2. Aplicar y comprobar primero en Staging autorizado; aquí no se aplicó remotamente.
3. Crear cuentas y archivos exclusivamente sintéticos por mecanismos Auth/Storage autorizados. Documentar identificadores privados y su titularidad; no registrarlos en Git.
4. Caso simple: solicitud → respuesta → desaparición Auth/perfil/preferencias/cuota/sesiones y rechazo del token viejo.
5. Caso con fotografías/negocio/solicitud/historial: debe quedar en revisión; comprobar conservación de datos ajenos y procedimiento aprobado de cada objeto propio.
6. Casos duplicado, sesión antigua, error de red, revocación parcial y reintento. Confirmación solo ante evidencia completa.
7. Probar recepción y verificación segura de la solicitud externa y su resultado, sin pedir contraseñas/OTP por correo. Registrar qué se conserva y por qué.
8. Con esa evidencia, solicitar autorización separada para desplegar la corrección en Production. No saltar la prueba alojada por haber pasado SQL local.

**Estado: corrección local APROBADA; eliminación desplegada BLOQUEADA; eliminación integral y canal externo PENDIENTES.**
