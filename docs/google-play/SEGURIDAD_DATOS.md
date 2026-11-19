# Flujo de datos y propuesta de Seguridad de los datos

Revisión de RC2 40c1f2fd5af3027ccd896e03ef1a17e848068069 y metadatos de Supabase Production, 19/11/2026. **Propuesta para revisión; no enviada.** Se distinguen datos que salen del dispositivo de datos que quedan solo locales. La clasificación de «compartido» de Play tiene excepciones para proveedores y acciones del usuario; no asumirlas sin comprobar condiciones reales.

## Inventario

| Datos y origen | Destino / finalidad | Almacenamiento / conservación acreditada | Propuesta Play |
|---|---|---|---|
| Correo, contraseña; registro/inicio | Supabase Auth, gestión de cuenta y acceso | Auth remoto; no hay plazo general documentado. Contraseña no aparece como dato de perfil | Correo e ID de usuario recopilados, gestión de cuenta; no declarar «sin datos» |
| Nombre, UUID, rol, fechas de perfil | Supabase public.usuarios, permisos y experiencia | Perfil remoto hasta proceso de supresión aplicable | Nombre/ID recopilados; revisar opcionalidad del nombre |
| Google OAuth, si se elige | Google y Supabase; autenticar | Proveedor y sesión; perfil recibido depende de configuración | Datos de cuenta; verificar consentimiento y configuración OAuth real |
| Teléfono de negocio y dirección | Supabase catálogo y ficha pública | Datos de establecimiento publicables; sin plazo general | Teléfono/dirección si identifican personas; gestionar publicación voluntaria |
| Latitud, longitud y precisión; GPS consentido | Supabase: búsqueda y orden de establecimientos/promociones | RPC recibe coordenadas; no hay prueba de borrado de logs/backups | Ubicación aproximada y precisa recopilada para funcionalidad; revisar opcionalidad global |
| Cómo llegar RC2 | Google Maps externo tras confirmación, solo destino del negocio | El botón no consulta GPS ni invoca Supabase/HeiGIT; Maps puede usar su propia ubicación | Evaluar el destino y acción iniciada por usuario, sin asumir una exención de compartición |
| Usuario, ventana y contador de rutas existentes | Tabla privada PostgreSQL de versiones anteriores | RC2 no la consume desde Cómo llegar; fila persiste, 60 s NO es TTL; eliminación desplegada bloqueada por reconocimiento de FK pendiente | Datos existentes siguen sujetos a retención y eliminación; no afirmar que desaparecieron |
| Área del mapa, IP y petición de teselas | tile.openstreetmap.org | Caché del cliente y registros del proveedor no auditados integralmente | Ubicación inferible/identificadores técnicos; revisar declaración de tercero |
| Fotos seleccionadas del negocio/promoción | Supabase Storage, publicar fichas | Objetos remotos; retención y dependencias de borrado requieren revisión | Fotos recopiladas y publicadas por decisión del aportante |
| Solicitudes de acceso, registro o corrección; mensajes/evidencias | Supabase y moderadores autorizados | Solicitudes e historiales; algunos casos bloquean supresión automática | Otro contenido generado por usuario, identificadores e interacción |
| Campañas destacadas, confirmación y referencia de pago introducida por administrador | Supabase RPC y auditoría de pagos | Referencia/fecha/actor; sin retención aprobada | Revisar historial de compras/transacciones y otra información financiera según operación real |
| Categorías, radio, prioridades y preferencias | SharedPreferences y sincronización Supabase | Local y remoto por cuenta; fallos de red pueden dejar cambios pendientes | Interacciones/personalización y datos de cuenta |
| Sesión, access/refresh tokens | SecureSessionStorage en Android; Supabase | flutter_secure_storage; migración retira copia antigua en preferencias; signout guarda tombstone | Gestión de cuenta y seguridad; no publicar tokens |
| Consentimientos, apariencia, cooldown/historial de avisos | SharedPreferences local | Persisten hasta limpieza/desinstalación/proceso aplicable | Lo exclusivamente local no se declara como recopilado; separar preferencias sincronizadas |
| Token FCM, instalación, ubicación para push | Implementación presente; FcmEnvironmentPolicy.enabled=false | No se habilita push promocional ni geofencing Production. SDK y providers nativos permanecen | No declarar envío promocional activo; falta tráfico real para determinar datos automáticos del SDK |
| Correos a soporte y navegación web | Proton, Vercel; Formspree solo en entornos donde se habilite | Distinto del AAB; condiciones y borrado por proveedor no verificados | Alinear política web y app sin atribuir un formulario de revisión al sitio público |

Código de referencia: `lib/features/auth/services/`, `lib/features/explorar/services/`, `lib/features/notificaciones/push/`, `lib/features/establecimientos/`, `lib/features/promociones/`, y `supabase/functions/`. Los IDs, nombres y referencias de pago se consideran datos aunque no haya SDK de anuncios.

## Respuestas verificadas

- La app transmite datos personales y ubicación para funciones reales. No procede marcar que no recopila datos.
- Se utiliza HTTPS para Supabase, mapas, rutas, OAuth y enlaces predeterminados. Esto no demuestra cifrado extremo a extremo ni una auditoría independiente.
- La ruta Mi cuenta → Configuración → Eliminar cuenta y el endpoint real existen, pero se confirmó un bloqueo de FK en la guarda desplegada. La corrección local no acredita eliminación operativa en Production. Véase AUDITORIA_ELIMINACION_INTEGRAL.md.
- El GPS para cercanía requiere consentimiento y permiso. En RC2 Cómo llegar confirma apertura externa, comparte solo destino y no consulta GPS ni solicita rutas internas. No eliminar por ello la declaración de ubicación usada en exploración.
- No hay permisos de contactos, SMS, micrófono, acceso amplio a fotos o background location en el manifiesto final.
- No hay SDK publicitario identificado en pubspec.lock. Esto no permite contestar automáticamente «sin anuncios»: hay promociones destacadas y patrocinio.

## Respuestas pendientes de comprobar

- Si todos los usuarios pueden usar funcionalidades suficientes sin cada dato opcional; no marcar todo opcional por tener un diálogo.
- Datos automáticos de Firebase y dependencias en una ejecución real antes/después de denegar permisos y al limpiar instalaciones previas. `firebase_messaging_auto_init_enabled=false` y analítica deshabilitada no prueban ausencia total de tráfico.
- Condiciones que permitirían aplicar excepciones de «compartido» a Supabase, OSM y autenticación externa; HeiGIT está deshabilitado para RC2. Sin prueba no declarar que no se comparte.
- Retención, regiones, subencargados, respaldos, borrado efectivo de imágenes y revisión de cuentas con dependencias.
- Clasificación exacta de referencias económicas, búsquedas y mensajes en el formulario vigente de Play; no hay una base para prometer que son datos efímeros.
- Eliminación integral autenticada, OAuth de release y alcance real de claves públicas Firebase (restricciones API/configuración).

## Decisiones del propietario

Aprobar categorías, finalidad, opcionalidad, retención y clasificación de terceros; definir la atención de derechos y público. Revisar destacadas pagadas y el modelo comercial antes de completar anuncios y políticas de pagos. No introducir números de conservación sin una decisión y un mecanismo verificable.

## Controles comprobados y límites

Consulta remota de solo lectura: 20 tablas public y una privada de rutas con RLS; 15 guardas de identidad son RESTRICTIVE. La tabla de rutas no concede uso del esquema ni SELECT a anon/authenticated; consumir_cuota_rutas comprueba auth.uid(), fija search_path vacío y usa contador atómico. es_administrador consulta el perfil controlado por servidor; con auth.uid nulo no concede rol. Dos funciones de revisión sensibles inspeccionadas exigen administrador y sesión reciente. No se acredita por ello la corrección de todas las 29 RPC SECURITY DEFINER.

Advisors: 14 avisos informativos de RLS sin políticas, 1 advertencia de RPC definer ejecutable por anon, 29 por authenticated y protección de contraseñas filtradas deshabilitada. Las tablas privadas sin política tienen denegación por defecto; las RPC deben revisarse por autorización interna. No se concedieron permisos ni se activó una función pagada. [Linter](https://supabase.com/docs/guides/database/database-linter), [contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Endpoint calcular-ruta: validación getUser, límite de payload 2.048 caracteres, perfiles permitidos, coordenadas finitas y distancia 10 m–150 km; RPC de cuota que falla cerrada, timeout proveedor 12 s y cliente 18 s. Cliente maneja 401/403, 429, 422 y 5xx con mensajes sin detalles del servidor, sin reintentos automáticos. Las pruebas no simulan éxito del servicio publicado: interceptan HTTP del entrypoint real de forma aislada.

Escaneo de APK/AAB: todas las entradas descomprimidas para claves privadas PEM, sb_secret, JWT de service_role, JSON de service account, archivos jks/keystore/.env/key.properties y contraseñas de firma conocidas. Sin hallazgos. Configuración Supabase publicable y Firebase de cliente son identificadores públicos, no prueba de autorización. No se pudo comparar la clave ORS privada del servidor con el binario; su ausencia se sustenta en el flujo del código y la compilación sin ORS_API_KEY. Un escaneo por patrones no demuestra ausencia de todo secreto u ofuscación posible.

Fuente de definiciones: [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469), [privacidad de Firebase](https://firebase.google.com/support/privacy). Véanse evidencias JSON y PRUEBAS_Y_RIESGOS.md.

## Cambio relevante de RC2

No afirmar cero tráfico del SDK: la política bloquea push promocional, pero _cleanupUnavailable puede inicializar Firebase para retirar un registro previo. El Radar inicia _radarActivo=false y preferencias de avisos/push false; los tests de regresión pasan. El manifiesto aún contiene providers y receptores protegidos de Firebase. Falta evidencia de tráfico de un dispositivo real.

La propuesta completa de respuestas, UGC/anuncios e incertidumbres está en DECLARACIONES_PLAY_RECOMENDADAS.md. No se leyeron las respuestas que el titular ya esté completando en Console.
