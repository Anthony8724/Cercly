# Política de privacidad de Cercly — propuesta formal para revisión

Última revisión: 19 de noviembre de 2026. Este contenido está preparado para revisión del responsable. **No se ha publicado ni debe presentarse como una política definitiva aprobada.** Los puntos de conservación y proveedores señalados deben resolverse antes de la distribución.

## 1. Responsable y contacto

Cercly permite descubrir establecimientos, consultar promociones, gestionar negocios y calcular rutas. El responsable declarado es Anthony Miguel López Revelo, persona natural, con referencia pública Tulcán, Carchi, Ecuador. Estos datos proceden de la rama web que registra las declaraciones del titular. El domicilio legal completo de contacto está pendiente de confirmación; no se atribuye la app a una sociedad.

Privacidad, soporte y solicitudes sobre datos: soporte.cercly@proton.me. El teléfono público declarado en el sitio de revisión es +593 963848440. No envíes contraseñas, códigos OTP ni tokens al solicitar asistencia.

## 2. Datos que utilizamos

**Cuenta.** Al registrarte o iniciar sesión se transmiten a Supabase Auth el correo y la contraseña necesarios para autenticarte. El perfil contiene identificador, nombre, rol y fechas de cuenta. Se usan para gestionar acceso y permisos. Si eliges Google y está configurado, Google y Supabase intervienen en la autenticación; la información recibida depende del proveedor y del consentimiento. Los métodos Microsoft, Facebook y OTP telefónico están desactivados por defecto en esta candidata.

**Ubicación y exploración.** Con tu consentimiento y el permiso de Android, Cercly obtiene coordenadas y precisión para buscar lugares y promociones. Las consultas de cercanía envían latitud y longitud, filtros, radio y búsquedas a Supabase. La función no se limita al dispositivo. Puedes revocar el permiso o proporcionar solo ubicación aproximada desde Android; la precisión y disponibilidad de resultados pueden reducirse. No se solicita ubicación en segundo plano en esta variante de Producción.

**Rutas.** Al seleccionar Cómo llegar aparece un aviso adicional. Si aceptas, se envían origen, destino y modo de desplazamiento a una función autenticada de Supabase, que remite las coordenadas a HeiGIT/OpenRouteService. El resultado muestra recorrido, distancia y tiempo estimados; no es navegación paso a paso. Cancelar evita esa petición. La petición del servidor al proveedor no incluye nombre, correo, UUID ni token del usuario, pero las coordenadas pueden seguir siendo datos personales. La función no las inserta en una tabla ni las imprime en registros de aplicación; no se promete que los servicios descarten sus registros técnicos al responder. Las condiciones de uso de este tratamiento siguen pendientes de resolución antes de publicación.

**Mapas y apps externas.** Visualizar un mapa solicita teselas de OpenStreetMap; el servicio recibe información técnica de conexión e índices que corresponden al área visualizada. Elegir mapas externos abre un enlace con el destino; el enlace de Cercly no añade la coordenada de origen. El servicio elegido aplica sus propias prácticas.

**Negocios, promociones e imágenes.** Puedes aportar nombre, descripción, dirección, coordenadas, teléfono, categorías y horarios del negocio. Las fotos e imágenes seleccionadas se suben a Supabase Storage para presentarlas con el establecimiento o promoción. El contenido publicado puede verse en el catálogo. Las solicitudes de registro, acceso, reclamación o corrección y sus evidencias se vinculan a tu usuario y a su revisión. Los administradores pueden registrar confirmaciones y referencias de pagos de campañas destacadas; esta función no cobra ni recoge tarjetas dentro de Cercly. No aportes datos de terceros sin estar autorizado.

**Preferencias y avisos.** Las categorías, radio y prioridades se guardan localmente y se sincronizan por cuenta con Supabase. La apariencia, consentimientos y control de repetición de avisos utilizan almacenamiento local. Puede haber cambios pendientes de sincronización sin red. El Radar funciona en primer plano cuando está activo. Push promocional y geofencing en segundo plano permanecen deshabilitados en Producción; la presencia de bibliotecas Firebase requiere comprobar también sus datos técnicos automáticos antes de completar declaraciones definitivas.

## 3. Destinatarios y servicios

Supabase presta autenticación, base de datos, funciones de servidor y almacenamiento. HeiGIT/OpenRouteService recibe las coordenadas de las rutas solicitadas. OpenStreetMap sirve mapas; Google interviene al elegir autenticación o mapas externos. Los datos de fichas y promociones publicados son accesibles a quienes consultan el catálogo; administradores autorizados revisan solicitudes y dependencias.

El sitio informativo usa Vercel. Los correos que envíes llegan al servicio de Proton. La rama web de revisión contiene formularios con Formspree que tratan correo, mensaje y tipo de consulta donde estén habilitados; no se afirma que formen parte del sitio público actual. La aceptación de un formulario no confirma eliminación de cuenta.

No se han verificado todas las regiones de alojamiento, subencargados ni condiciones de transferencias internacionales. No se afirma que los datos permanezcan en Ecuador ni que los proveedores carezcan de registros.

## 4. Permisos y medidas de protección

La variante revisada utiliza Internet, ubicación aproximada/precisa, notificaciones y vibración; bibliotecas nativas añaden acceso a estado de red, wake lock y recepción de mensajería. Puedes revisar permisos en Android. El selector de imágenes accede a los archivos que seleccionas, sin un permiso general de biblioteca en el manifiesto revisado. No se solicitan contactos, SMS o micrófono.

En Android la sesión se almacena mediante almacenamiento seguro y se retira la copia anterior al migrarla. La comunicación de servicios predeterminados usa HTTPS. La base incorpora controles de identidad, roles y RLS. No se afirma cifrado de extremo a extremo, protección absoluta o certificación de Cercly.

## 5. Conservación

Las cuentas, preferencias, imágenes y solicitudes persisten según la funcionalidad y los procesos de eliminación aplicables. No existe todavía un calendario de conservación aprobado y verificado para todas las categorías, respaldos, mensajes de soporte e historiales de moderación.

El control de abuso de rutas guarda un UUID, una fecha de ventana y contador. Su ventana de 60 segundos limita frecuencia; no elimina automáticamente el registro. La fila se actualiza y su relación con Auth permite borrarla al eliminar la identidad. Las rutas no generan por sí mismas un historial de coordenadas en el código inspeccionado. No se acredita una retención equivalente en registros o respaldos de los proveedores.

No se adoptan como compromiso público los plazos de los borradores internos de atención. El responsable debe aprobar y verificar criterios de supresión y excepciones antes de publicar esta política como definitiva.

## 6. Solicitudes y eliminación

Puedes iniciar el proceso en Mi cuenta → Configuración → Eliminar cuenta. Requiere sesión válida y puede pedir autenticación reciente. La función real verifica al usuario, revisa dependencias y revoca sesiones antes de intentar eliminar Auth. Si hay establecimientos, imágenes compartidas o historiales que requieren revisión, la solicitud queda pendiente o en revisión; no significa eliminación confirmada.

La URL prevista para solicitarlo sin reinstalar es https://cercly-web.vercel.app/eliminar-cuenta. Permite contactar por correo. La recepción, verificación de titularidad, eliminación y confirmación por este canal requieren validación integral; no se promete un plazo que no se haya implantado. Para acceso, rectificación, eliminación parcial u otras consultas, escribe al contacto de privacidad. El responsable debe verificar de forma segura la titularidad antes de actuar.

Desinstalar la app, cerrar sesión o revocar permisos no elimina la cuenta remota. Eliminar una foto o preferencia tampoco equivale al borrado de cuenta. No se garantiza la supresión de datos compartidos, auditorías o respaldos fuera del alcance comprobado.

## 7. Cambios y publicación

Las nuevas funciones o proveedores requieren revisar esta política. La fecha identifica esta propuesta. URL estable prevista: https://cercly-web.vercel.app/privacidad, enlazada desde Configuración. Actualmente redirige a un resumen de la portada y debe corregirse antes de enviar la app. El borrador web completo está en el PR #15 de cercly-web; ni la existencia del documento ni su prueba local acreditan que esté publicado.
