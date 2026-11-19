# Plan cerrado: 12 verificadores y 14 días

**Preparado, no ejecutado.** No hay lista real, invitaciones enviadas, fechas iniciadas ni evidencia de cumplimiento. Google exige este mínimo para cuentas personales creadas después del 13/11/2023; primero confirmar aplicabilidad. La prueba cerrada y el acceso a Producción no se sustituyen por APK instalado por USB ni se aprueban automáticamente al pasar 14 días.

## Condiciones de inicio

- AAB definitivo con código único, firma contrastada y política/retención/eliminación/declaraciones/UGC revisados; resolver NO-GO del estado actual.
- Titular autoriza distribución cerrada; no se envían invitaciones aquí.
- Play Console → Test and release → Testing → Closed testing: preparar el track y su lista/grupo, países, URL de inscripción e instrucciones. Comprobar acceso con cuenta de prueba antes de compartir.
- Tener al menos 12 participantes elegibles continuamente inscritos durante 14 días completos. Proponer 2 reservas voluntarias también inscritas desde el inicio para evitar perder el mínimo; no usar cuentas ficticias para inflar cifras.
- Registrar tiempos de inscripción por persona, no solo el número de descargas. Si alguien abandona, comprobar cuántos siguen con 14 días continuos; una reserva nueva no hereda antigüedad.

## Distribución propuesta

| IDs internos | Cobertura asignada |
|---|---|
| T01–T02 | HONOR, Android disponible y restricciones del fabricante; permisos/retorno de Maps |
| T03–T04 | Android 15/16, edge-to-edge, teclado, back y ubicación aproximada |
| T05–T06 | Conexión lenta/offline, reintentos, catálogo/mapa y cancelación de Maps |
| T07–T08 | Cuenta, recuperación, Google OAuth y cambio de sesión autorizados |
| T09–T10 | Accesibilidad: TalkBack, fuente 200 %, contraste, foco y RIIOTE |
| T11–T12 | Flujos de negocio/promociones con fixtures autorizados y sin datos reales |
| R01–R02 | Reservas voluntarias desde el inicio y escenarios cruzados |

La matriz es una asignación por conseguir, no una afirmación de que haya dispositivos o personas disponibles. Guardar correos, credenciales y correspondencia ID-persona en un registro privado, nunca en Git. Compartir solo errores saneados y consentidos.

## Calendario de ejecución

| Día | Objetivo y evidencia |
|---|---|
| D0 (preparación, fuera del cómputo) | Autorizar y configurar track; confirmar enlaces y código; formar participantes y criterios de reporte |
| D1 | Inscripción/instalación desde Play; comprobar que se recibe versión correcta y registrar fecha/hora |
| D2–D3 | Explorar con/sin GPS, aproximada/precisa, mapa, categorías, detalles, promociones y RIIOTE |
| D4–D5 | Cómo llegar: aviso, cancelar, confirmar solo destino, retorno; sin rutas internas ni fallback al proveedor bloqueado |
| D6–D7 | Offline, reconexión, permisos revocados, segundo plano y restricciones HONOR; cierre de primera revisión |
| D8–D9 | Cuenta/OAuth y preferencias con identidades QA; verificar que Radar/push no se activen solos |
| D10–D11 | Accesibilidad y negocios autorizados. Eliminación se ensaya en entorno autorizado con fixture, no en cuentas reales de participantes |
| D12–D13 | Corregir incidencias, distribuir nueva build con code superior si cambia código; regresión cruzada sin manipular continuidad de inscripción |
| D14 y después de 14 días completos | Revisión de elegibles y tickets, QA final, evidencia de correcciones; esperar que Console confirme elegibilidad |
| Solicitud posterior | Titular responde con lo efectivamente probado, feedback y cambios; solicita acceso a Producción solo si cumple y autoriza |

Las sesiones propuestas permiten observar uso real y obtener feedback; Google no se representa aquí como exigiendo abrir la app todos los días. No fabricar actividad, reseñas ni comentarios.

## Registro y criterios de salida

Plantilla privada: ID, modelo/SO, track, versionCode, SHA/build, alta (UTC), última comprobación de inscripción, baja si existe, escenarios ejecutados, resultado, ticket y fecha de corrección. En el repositorio conservar solo totales y ejemplos sin datos personales.

Cero errores críticos reproducibles; no envío de origen/proveedor bloqueado; consentimiento y permisos correctos; login/revisión accesibles; eliminación acreditada y documentos públicos coherentes; al menos 12 elegibles con continuidad comprobada y respuesta de Google documentada. Un fallo crítico suspende la recomendación de envío, sin declarar que ya se cumplió el requisito.

Fuente oficial: https://support.google.com/googleplay/android-developer/answer/14151465
