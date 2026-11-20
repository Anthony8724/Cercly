# Contraste de formularios Play — verificable frente a decisiones

Revisión del 19/11/2026. APK existente: SHA-256 `812e72ead744d8144e029154be5cabe990c9c030e74d3805fef82a86c5b22f49`, código 40c1f2f, sin recompilar. **No hubo acceso a los valores guardados en Play Console ni se modificó un formulario.** Las respuestas propuestas deben contrastarse allí; no se declara coincidencia con respuestas que no se han visto.

## Verificado en RC2 y recomendación sustentada

| Campo / asunto | Hecho y propuesta | Evidencia concreta |
|---|---|---|
| Recopilación | Sí: datos de cuenta/perfil, ubicación para cercanía, preferencias, textos/fotos de negocios y solicitudes salen del dispositivo | Auth/perfil, RPC de exploración, servicios de preferencias y uploadBinary; SEGURIDAD_DATOS.md |
| Identidad | Declarar correo, nombre e ID según los campos utilizados y finalidad de cuenta/funcionalidad. No confundir nombre de negocio con persona en todos los casos | auth_service.dart, perfil y modelos de negocio; campos OAuth sujetos a configuración |
| Ubicación aproximada y precisa | Sigue habiendo recopilación para búsqueda por cercanía; rutas apagadas no eliminan ese tratamiento. Declarar finalidades reales por cada uso | consentimiento_ubicacion.dart, ubicacion_service.dart, exploración RPC y permisos coarse/fine del artefacto |
| Navegación externa | Cómo llegar confirma y abre URL Google Maps solo con destino, sin GPS/origen ni RPC de rutas | politica_rutas.dart, detalle_establecimiento_screen.dart, mapas_externos_service.dart y pruebas de cero invocaciones |
| OSM / Supabase / Google | Supabase recibe datos de cuenta/cercanía/contenido; OSM recibe teselas/área/IP; Maps recibe destino al confirmar y OAuth interviene si se usa | URLs/configuración y flujo de servicios. No afirmar que todo es local o efímero |
| Fotos / otro contenido de usuario | Proponer Fotos y otro CGU/textos según campos reales; finalidad de funcionalidades/publicación. El archivo seleccionado se sube a Storage | foto_establecimiento_service.dart: readAsBytes/uploadBinary; promocion_service.dart. imageQuality=85 no demuestra eliminar todo EXIF: verificar metadatos con un archivo sintético antes de prometerlo |
| Datos de pago administrativos | Hay confirmación, referencia de pago y auditoría de destacadas. No se recoge tarjeta mediante el flujo inspeccionado | administracion_destacadas_screen.dart, administracion_destacadas_service.dart y auditoria_pagos_destacadas |
| Permisos | Internet y ubicación foreground aproximada/precisa, notificaciones y componentes de FCM; sin permiso de ubicación background en RC2 | Manifiestos finales conservados en la entrega. No declarar que Radar/push se activan por defecto |
| Solicitar eliminación | Existe interfaz/handler y canal de contacto. Los casos simples/fotos sintéticos aprobaron 43 checks HTTP **locales**; Production sigue bloqueada | ELIMINACION_HTTP_LOCAL.md y diagnóstico remoto de solo lectura; no marcar proceso integral operativo todavía |
| URL de privacidad / eliminación | Usar URLs estables de Cercly solo cuando sirvan el documento completo aprobado y el mecanismo externo esté validado | Pública /privacidad 307 a portada, /eliminar-cuenta 200, /terminos 404; local 200 no demuestra publicación |

## Decisión del titular y comprobaciones técnicas pendientes

| Campo | Recomendación / alternativas para decidir | Qué falta antes de enviar |
|---|---|---|
| ¿Datos compartidos? | Revisar por flujo las excepciones de proveedor encargado, publicación voluntaria y acción iniciada por el usuario; **no marcar No global por defecto** | Condiciones reales de Supabase/SDK/terceros y alcance de todas las versiones distribuidas. La salida a Maps satisface una acción explícita, pero la excepción exacta debe validarse y no elimina la obligación de transparencia |
| Opcional/obligatorio / efímero | Evaluar por tipo y función; permisos denegables y modo invitado no justifican marcar todos como opcionales | QA real de todos los usuarios/regiones, retención/logs y SDK. Una respuesta RPC no demuestra borrado inmediato |
| Firebase / identificadores | No afirmar cero tráfico: envío promocional bloqueado, SDK incluido y retirada/desregistro posible | Medir con dispositivo autorizado en inicio, login/logout y limpieza de estado previo; consultar guía del SDK. No confundir inicialización técnica con habilitar promociones |
| Anuncios | Si destacadas son espacios nativos vendidos para promocionar negocios, la propuesta técnica es **Sí**. Confirmar modelo y alcance; RIIOTE discreto se analiza por separado | Aprobar clasificación. Google distingue anuncios nativos de determinadas inclusiones de producto; ausencia de SDK no resuelve la pregunta |
| Información financiera | Revisar historial de compras/transacciones para referencias/confirmaciones vinculables; no declarar tarjeta si no se recoge | Titular debe explicar el modelo comercial, quién paga y qué referencia se introduce. No extender la excepción de un procesador externo a datos que Cercly sí recibe |
| CGU y moderación | Las fotos/promociones/textos de propietarios son CGU visible para otros. La aprobación de un negocio no prueba moderación continua de cada aporte | Faltan controles acreditados de aceptación previa de términos, denuncia de usuarios/contenido y bloqueo aplicable a CGU público. Requieren **implementación y pruebas**, no solo aprobar una casilla. No se ofrece «catálogo curado» como exención sin demostrar control real |
| Política / retención | Aprobar propuesta por categoría y publicación; respetar los 90 días solo para soporte cerrado/incidencias resueltas | Implementación de ese plazo en Formspree/Proton, derechos/respaldos/imágenes/cuentas/auditorías, domicilio legal y transferencias pendientes |
| Público / IARC | Decidir edades por usuarios y contenido reales y responder cuestionario; adultos es solo una posible decisión de producto | No seleccionar edades para evitar requisitos ni afirmar rating concedido. Revisar contenido aportado y categorías del catálogo |
| Versiones y certificados | Comprobar code 26 frente a todos los paquetes/canales y certificado de carga | Console no accesible; si 26 está usado, nuevo código y reconstrucción. No afecta al hash de la APK conservada mientras no se reconstruya |

## Cómo completar el contraste con la cuenta legítima

Play Console → Cercly → **Monitorizar y mejorar → Política y programas → Contenido de la aplicación**. Leer Seguridad de los datos, Anuncios, Público objetivo/contenido, Clasificación, Política y Eliminación. Registrar privadamente el valor actual junto a cada fila, evidencia, cambio propuesto y aprobación. No enviar formularios desde este documento ni compartir credenciales. Ver INSTRUCCIONES_PLAY_CONSOLE.md para versión/firma y el track.

La prueba **cerrada** también requiere declaraciones y política correctas; el estado de pruebas no permite omitir estos bloqueos. No se trata de una prueba interna exenta ni de una aprobación de acceso a Producción.

Fuentes oficiales consultadas: [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=es), [CGU](https://support.google.com/googleplay/android-developer/answer/9876937?hl=es), [eliminación](https://support.google.com/googleplay/android-developer/answer/13327111?hl=es), [App content/anuncios](https://support.google.com/googleplay/android-developer/answer/9859455?hl=es). Son requisitos de referencia, no resoluciones concedidas a Cercly.
