# Ficha de Google Play — propuesta en español

Estado: textos preparados, no enviados. No se promete navegación paso a paso, alertas en segundo plano ni cobertura universal.

## Datos de ficha

| Campo | Propuesta | Estado |
|---|---|---|
| Nombre | Cercly | Verificado, 6 caracteres |
| Tipo | Aplicación | Verificado |
| Categoría | Estilo de vida | Recomendación por descubrimiento local; decidir en Console |
| Etiquetas | Elegir entre etiquetas vigentes de negocios locales y descubrimiento que Console ofrezca | Pendiente |
| Precio y países | Definir por el titular | Pendiente; no se acepta gasto |
| Público | Personas que buscan lugares locales y responsables de establecimientos | Sustentado por funciones |
| Edad | Propuesta inicial 18+ para revisión del titular | Decisión pendiente, no equivale a rating IARC |
| Soporte | soporte.cercly@proton.me | Contacto público declarado; operación integral pendiente |
| Web | https://cercly-web.vercel.app/ | Pública |
| Política | https://cercly-web.vercel.app/privacidad | Bloqueada hasta servir política completa |
| Eliminación | https://cercly-web.vercel.app/eliminar-cuenta | Página pública; operación integral pendiente |

## Descripción corta

Descubre establecimientos, promociones y rutas cerca de ti con Cercly.

## Descripción completa

Cercly te ayuda a descubrir establecimientos y promociones de tu entorno. Explora lugares cercanos, consulta sus fichas y encuentra opciones para llegar a ellos.

EXPLORA A TU ALREDEDOR
Busca establecimientos por categorías y consulta los resultados en una lista o en el mapa. Con el permiso de ubicación puedes ordenar opciones por cercanía y ajustar tu radio de búsqueda.

CONOCE CADA LUGAR
Consulta los datos disponibles de cada establecimiento: descripción, ubicación, horarios, contacto e imágenes. Revisa promociones vigentes y descubre propuestas de los negocios locales.

PLANIFICA CÓMO LLEGAR
Solicita un recorrido a pie o en auto desde Cercly o abre otra aplicación de mapas. Antes de calcular una ruta interna, Cercly te informa del envío de origen y destino a Supabase y HeiGIT/OpenRouteService. Las rutas muestran una distancia y un tiempo estimados; no ofrecen navegación paso a paso.

TU CUENTA Y TUS PREFERENCIAS
Mantén tus categorías y preferencias vinculadas a tu cuenta. Gestiona los permisos y ajustes de privacidad y solicita la eliminación de tu cuenta desde Configuración.

UN ESPACIO PARA LOS NEGOCIOS
Los responsables de establecimientos pueden solicitar el registro o acceso a su negocio, mantener su información y gestionar promociones según los permisos de su cuenta y los procesos de revisión.

Cercly utiliza mapas y datos de OpenStreetMap. La información de los lugares y los recorridos puede cambiar; comprueba los detalles importantes antes de desplazarte. La disponibilidad depende de los establecimientos, la ubicación, la conexión y los servicios utilizados.

## Novedades de 0.1.9

• Consulta rutas internas a pie o en auto, con distancia y tiempo estimados.
• Revisa el aviso sobre el uso de coordenadas antes de solicitar una ruta.
• Encuentra un reconocimiento discreto a RIIOTE en Mi cuenta.
• Mejoramos los mensajes de error y los créditos de mapas y rutas.

No usar el texto de rutas como descripción de una versión publicable hasta resolver el bloqueo contractual del proveedor. Si el alcance cambia, actualizar la ficha y generar artefactos consistentes.

## Recursos gráficos

Fuentes reproducibles en recursos/. Archivos PNG fuera de Git, en la carpeta candidata de Descargas:

- icono-play-512.png: 512×512, RGBA, 33.251 bytes; fondo cuadrado opaco y marca Cercly Sky, sin esquinas prerrecortadas.
- grafico-promocional-1024x500.png: 1024×500, fondo opaco, 50.937 bytes; marca y descripción de funcionalidad real. Sin pantallas inventadas ni reclamos de premios.
- RIIOTE no se añadió al gráfico ni al icono; se mantiene discretamente en Mi cuenta.

## Capturas pendientes

Obtener al menos: Explorar/lista, mapa, detalle con promoción vigente, ruta real después del consentimiento y Mi cuenta con RIIOTE. Añadir Configuración/privacidad si aporta valor. Usar APK 26 real, no goldens ni evaluation. Preferir 1080×1920 o formato que cumpla la relación máxima 2:1 de Play. El AVD existente usa 1080×2400 y requeriría una configuración de pantalla de 1080×1920 antes de capturar; no estirar imágenes.

1. Instalar la candidata en un dispositivo autorizado; no reemplazar versiones de terceros sin comprobar firma y sincronización.
2. Usar una cuenta dedicada sin datos personales y establecimientos aptos para mostrar públicamente. No usar el GPS real para una captura compartida; elegir un área pública autorizada.
3. Capturar con `adb exec-out screencap -p` y revisar cada imagen completa: correos, notificaciones, nombres privados y coordenadas sensibles.
4. Si se ocultan datos, documentar la edición y mantener intacta la funcionalidad visible. No componer pantallas que la app no ofrece.
5. Conservar capturas originales en almacenamiento privado y publicar solo recursos aprobados por el titular.

El emulador falló con salida 139 en modo normal y software sin cámaras. No se produjeron capturas actuales del APK 26 ni se afirma la prueba HONOR de esta candidata; la evidencia previa corresponde a +25.
