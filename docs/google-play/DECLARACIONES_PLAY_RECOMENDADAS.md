# Bloque D — respuestas recomendadas de Play Console

Propuesta del 19/11/2026 para RC2. No se obtuvo acceso a las respuestas reales de Console; se pidió su transcripción al titular. No se modificó ni envió ninguna declaración. Verificar el formulario vigente, el alcance de todas las versiones distribuidas y los SDK, no solo una pantalla.

| Pregunta / categoría | Respuesta recomendada o condición | Evidencia | Incertidumbre / estado |
|---|---|---|---|
| ¿Se recopilan datos? | Sí | Auth, perfil, preferencias, ubicación a Supabase, fotos y solicitudes | VERIFICADO |
| Correo, nombre e ID de usuario | Declararlos para cuenta, autenticación y permisos | Registro, perfil y sesión | Nombre/opcionalidad y datos OAuth exactos por confirmar |
| Teléfono/dirección | Declarar si el campo identifica a una persona, incluidos negocios unipersonales | Fichas y solicitudes | No confundir teléfono del negocio con OTP (apagado por defecto) |
| Ubicación aproximada y precisa | Declarar ambas según la precisión concedida; finalidad principal cercanía | RPC búsqueda + permisos coarse/fine y consentimiento | No marcar que la app dejó de recopilar ubicación por apagar rutas |
| HeiGIT en RC2 | Sin envío de rutas desde esta candidata | UI externa + guardas + pruebas + cadenas de binario | No extender esta afirmación a builds anteriores/backend ni reactivar sin revisión |
| Google Maps | Destino compartido al confirmar apertura externa; origen omitido por Cercly | URL api=1,destination exclusivamente | Maps puede tratar ubicación propia; excepción de acción del usuario debe evaluarse, no asumirse |
| OSM | Declarar el tratamiento pertinente de peticiones de teselas/área/IP | flutter_map, tile.openstreetmap.org | Región de mapa puede revelar ubicación aproximada; verificar caché/tráfico real |
| Fotos y contenido del negocio | Fotos y otro contenido generado por usuarios para fichas/promociones/solicitudes | Storage, modelos y pantallas de carga | Acceso público condicionado por RLS sigue siendo publicación de datos; no marcar únicamente local |
| Actividad/interacciones y búsquedas | Revisar categorías de búsquedas, preferencias y solicitudes transmitidas | RPC y servicios de filtros/sincronización | No equivalen a analítica publicitaria; conservación no demostrada |
| Datos económicos | Revisar referencia/confirmación e historial administrativo de campañas | administracion_destacadas y auditoría pagos | No hay recogida de tarjeta; no excluir todo dato financiero por ello |
| Identificadores FCM/instalación | Pendiente de tráfico real, incluidas migraciones/retirada de instalaciones previas | SDK/proveedores nativos; auto-init y analítica false; política push false | La limpieza de estados previos puede inicializar Firebase para retirar registro. No afirmar cero tráfico automático |
| ¿Se comparten datos? | No contestar No de forma global todavía | Proveedores, catálogo publicado y enlaces externos | Comprobar condición de encargado y excepciones de Play por cada flujo; no se acreditan automáticamente |
| Cifrado en tránsito | HTTPS en servicios predeterminados verificado por código; confirmar SDK y ejecución antes de respuesta global | URLs y manifiesto | No es cifrado extremo a extremo ni auditoría independiente |
| ¿Se puede solicitar eliminación? | La ruta existe; no declarar proceso integral probado | App, Edge real y web | BLOQUEADO por FK de cuota en backend desplegado; corrección local sin desplegar |
| URL de política | /privacidad solo después de servir política completa aprobada | App apunta a URL estable; nueva web local 200 | Pública todavía redirige a resumen; pendiente autorización de publicación |
| Anuncios | No marcar automáticamente No. Si destacadas son anuncios nativos vendidos, recomendar Sí; distinguir contenido comercial/emplazamiento excluido de la etiqueta | Campañas pagadas y RIIOTE; sin SDK de anuncios | Decisión del titular sobre modelo real y aplicación de política. Ausencia de SDK no resuelve la pregunta |
| UGC/moderación | Reconocer contenido aportado por negocios y procesos administrativos | Fotos, textos, correcciones, reclamaciones y moderación | No se acreditó aceptación versionada de términos antes de aportar contenido, denuncia de todo contenido ni bloqueo genérico de usuarios. Revisión de aplicabilidad/controles obligatoria |
| Público/IARC | Público de descubrimiento local y gestión de negocios; cuestionario real por completar | Funciones observadas | No asignar rating/edad como hecho. Propuesta de adultos es decisión pendiente, no exención automática |
| Categorías especiales | No se identifica función principal de noticias, salud, finanzas o apuestas | Alcance de app | Referencias administrativas no convierten la app en servicio financiero; revisar preguntas específicas |
| Acceso de revisores | Cuenta dedicada para áreas con login/rol; indicar recorrido y datos accesibles | Auth/roles y negocio | Credenciales privadas y prueba real pendientes; sin bypass de roles ni secretos en Git |
| Permisos | Ubicación foreground, notificaciones; no background location, SMS o contactos | Manifiesto final APK/AAB | Confirmar comportamiento HONOR/Android 15/16 y declaraciones asociadas |

## UGC y contenido: acciones propuestas al titular

No se infiere cumplimiento de la política UGC solo porque haya un administrador. Elegir y revisar el alcance comercial: catálogo curado con control efectivo previo, o contenido aportado con aceptación de términos, denuncias y controles exigibles. Preparar la aceptación versionada y los controles que resulten necesarios una vez aprobados términos y clasificación. No retirar silenciosamente funciones de propietarios para aparentar cumplimiento ni publicar un texto que prometa controles inexistentes.

## Fuentes oficiales

- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/9859455
- https://support.google.com/googleplay/android-developer/answer/9876937
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://firebase.google.com/docs/cloud-messaging/flutter/get-started

Los valores ya guardados en Console deben compararse con esta tabla antes de cualquier envío; no se afirma que coincidan.
