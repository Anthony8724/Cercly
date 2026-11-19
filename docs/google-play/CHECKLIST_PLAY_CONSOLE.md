# Checklist Play Console — RC2

La comprobación actual está en [ESTADO_PUBLICACION.md](ESTADO_PUBLICACION.md), con [respuestas recomendadas](DECLARACIONES_PLAY_RECOMENDADAS.md) y [pasos exactos](INSTRUCCIONES_PLAY_CONSOLE.md). El listado siguiente conserva fuentes y requisitos de preparación de la revisión anterior; ninguna aprobación histórica de eliminación o rutas internas debe trasladarse a RC2 sin esos documentos.


Consulta oficial: 19/11/2026. La app móvil se prepara con target 36. No se enviaron formularios.

| Requisito | Estado | Evidencia / acción |
|---|---|---|
| API objetivo vigente para nuevas apps/actualizaciones | APROBADO | APK y AAB target 36; la regla vigente desde 31/08/2026 exige API 36 |
| Compilación y dependencias | APROBADO | compile 36, Flutter 3.47.5, AGP 9.1.0; lockfiles intactos, sin actualizaciones mayores |
| Compatibilidad del sistema | PENDIENTE | Probar Android 15/16, barras, teclado, back, tamaño de fuente, ubicación aproximada y notificaciones |
| Edge-to-edge | PENDIENTE | Android 16 ya no permite optar por excluirlo; pruebas widget no sustituyen prueba nativa |
| AAB válido | APROBADO | bundletool 1.18.3 validate, firma JAR verificada |
| 64 bits y 16 KB | APROBADO | arm64-v8a y x86_64 presentes; ELF64, zipalign y bundle config correctos |
| applicationId | APROBADO | com.cercly.cercly; no sufijo staging/evaluation/demo |
| versionCode no reutilizado | PENDIENTE | Verificar App Bundle Explorer en todos los tracks; 26 no está contrastado |
| Certificado de carga correcto para Play | PENDIENTE | Comparar SHA-256 en Configuración → Integridad de la aplicación; no confundir certificado de firma de Play con carga |
| Play App Signing | PENDIENTE | Verificar inscripción y propiedad; no generar ni cambiar claves |
| Política pública completa y accesible desde app | BLOQUEADO | Enlace de la app correcto; destino público redirige a resumen |
| Ruta externa de eliminación e información de retención | PENDIENTE | La página existe; validación operativa integral pendiente |
| Seguridad de los datos | PENDIENTE | Matriz en SEGURIDAD_DATOS.md; contratos y SDK necesitan revisión |
| Acceso de revisores | PENDIENTE | Credenciales dedicadas fuera de Git y pasos comprobados, incluidas áreas de negocio |
| Anuncios, público e IARC | PENDIENTE | Evaluar destacadas, aceptación/denuncia/bloqueo UGC y decisiones del titular |
| Icono y gráfico promocional | APROBADO | PNG preparados; revisar en preview antes de guardar |
| Capturas actuales | PENDIENTE | Capturar APK 26 real; no subir goldens o pantallas de evaluación como si fueran Producción |
| Verificación de desarrollador y registro del package | PENDIENTE | Atender lo que Console exija para esta cuenta y región |
| Ensayo cerrado si aplica | PENDIENTE | No hay evidencia del tipo o fecha de la cuenta ni historial de testers |

## Cuenta y prueba cerrada

No se obtuvo acceso autenticado de Google Play Console. No inferir su tipo a partir de GitHub, correo, Firebase o certificado.

Para cuentas personales creadas después del 13/11/2023, Google exige prueba cerrada con al menos 12 testers inscritos de forma continua durante 14 días antes de solicitar acceso a Producción. La solicitud también incluye preguntas sobre la app y la calidad de las pruebas. No equivale a aprobación automática ni basta con instalar APK por fuera de Play. Conservar evidencia de inscripción continua, retroalimentación, correcciones y decisión de Google. Confirmar aplicabilidad para la cuenta concreta.

## Recursos y ficha

Nombre máximo 30 caracteres, descripción corta máxima 80 y completa máxima 4.000; textos preparados en FICHA_GOOGLE_PLAY.md. Icono PNG 32 bits 512×512, máximo 1.024 KB, cuadrado sin máscara de esquinas aplicada. Feature graphic 1024×500 PNG/JPEG sin transparencia. Capturas: mínimo dos, JPEG o PNG 24 bits sin alfa, lados entre 320 y 3.840 px y lado mayor no superior al doble del menor. Para la ficha de teléfono se proponen 1080×1920 reales, al menos cuatro pantallas útiles. Validar las condiciones que muestre Console para otros formatos.

## Fuentes oficiales

- [API objetivo](https://support.google.com/googleplay/android-developer/answer/11926878).
- [Pruebas de cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465).
- [Contenido y acceso para revisión](https://support.google.com/googleplay/android-developer/answer/9859455).
- [Recursos de ficha](https://support.google.com/googleplay/android-developer/answer/9866151).
- [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469).
- [Eliminación](https://support.google.com/googleplay/android-developer/answer/13327111).
- [Android 16](https://developer.android.com/about/versions/16/behavior-changes-16).
- [Páginas de memoria 16 KB](https://developer.android.com/guide/practices/page-sizes).
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

Revisar avisos de Console al momento del envío: la documentación no sustituye las restricciones específicas de la cuenta.

## Propuesta de declaraciones por grupo

| Declaración | Verificado | Pendiente de comprobar | Decisión del propietario |
|---|---|---|---|
| Seguridad de los datos | Cuenta, ubicación y contenido salen del dispositivo | SDK/terceros, retención, opcionalidad y compartición exacta | Aprobar respuestas finales |
| Política y eliminación | App enlaza ambas URL, función real activa | URL de política completa y supresión integral | Aprobar texto y procedimiento |
| Acceso a la app | Existen áreas con login y roles | Credenciales dedicadas y recorrido de revisor | Autorizar cuenta y permisos adecuados |
| Ubicación | Cercanía/rutas en primer plano; sin permiso background | Precisa/aproximada y flujo nativo completo | Confirmar explicación pública y finalidades |
| Anuncios | Hay promociones, destacadas pagadas y footer RIIOTE; no SDK publicitario | Evaluar formato comercial real según política de anuncios | Determinar declaración sin asumir que ausencia de SDK implica ausencia de anuncios |
| Clasificación de contenido | Existen imágenes y contenido aportado por establecimientos y moderación | Recorrido IARC, controles y contenido visible | Completar cuestionario; no se asignó rating |
| Público objetivo | Descubrimiento local y gestión de negocios | Adecuación por edades y contenido comercial | Elegir edades/países y aceptar obligaciones aplicables |
| Categorías especiales | Funcionalidad principal no es noticias, salud, finanzas, juego o apuestas | Confirmar preguntas concretas de Console y catálogo público | No declarar una categoría especial sin función real |
| Experiencia mínima | App real con catálogo, mapa, promociones y rutas; builds/pruebas correctos | QA nativa, fallos de red y acceso de revisión | Autorizar envío solo tras cerrar bloqueos |
| Pagos | Administración registra referencias externas; no hay SDK Billing identificado | Aplicabilidad de política al modelo de destacadas | Definir modelo antes de alegar exenciones |

[Política de pagos](https://support.google.com/googleplay/android-developer/answer/10281818), [anuncios y declaraciones](https://support.google.com/googleplay/android-developer/answer/9859455). No se envió ningún cuestionario.
