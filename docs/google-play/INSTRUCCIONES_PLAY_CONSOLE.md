# Pasos exactos para completar la revisión de Play Console

Documento de trabajo, sin guardar ni enviar formularios en nombre del titular.

## 1. Confirmar cuenta y permisos

Entrar en la cuenta legítima, seleccionar Cercly y comprobar que el package es com.cercly.cercly. En Developer account / Cuenta de desarrollador revisar tipo personal/organización y datos de registro; en Users and permissions / Usuarios y permisos comprobar quién puede administrar firma, pruebas y releases. Si la fecha de creación no se muestra, usar la confirmación de registro o soporte de Google; no inferirla por GitHub o el certificado.

## 2. VersionCode 26

Ruta oficial actual en inglés: **Test and release → Latest releases and bundles → All app versions → App bundle explorer** (Prueba y lanzamiento → últimas versiones y paquetes → todas las versiones → explorador). Revisar el filtro de versiones y todos los tracks, incluidos borradores/paquetes ya registrados.

Registrar fuera de Git una evidencia del máximo versionCode utilizado. Si cualquier código utilizado es >=26, el próximo será un entero superior a ese máximo, por ejemplo max+1. Cambiar pubspec/build number, reconstruir APK y AAB, verificar firma/manifiesto y regenerar inventario/hashes. No reutilizar 26 ni renombrar un archivo como sustituto. La información disponible aquí no demuestra que 26 esté libre.

Fuente: https://support.google.com/googleplay/android-developer/answer/9844279

## 3. Firma

Abrir la página **App signing / Firma de aplicaciones** de la app (según interfaz puede figurar bajo configuración/integridad). Localizar **Upload key certificate / Certificado de clave de carga** y su SHA-256. No copiar la sección App signing key certificate como si fuera la clave de carga.

Huella de carga esperada: f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5. Comprobar inscripción Play App Signing y compatibilidad de OAuth/API con el certificado de distribución de Play, que puede ser distinto. No restablecer/generar claves ni aceptar un cambio de firma para continuar.

Fuente: https://support.google.com/googleplay/android-developer/answer/9842756

## 4. Contenido de la aplicación

Ruta oficial actual: **Monitor and improve → Policy and programs → App content**. En la interfaz española puede mostrarse como supervisión/mejora → políticas/programas → contenido de la aplicación.

Preparar, revisar con el titular y solo guardar/enviar cuando lo autorice:

1. Seguridad de los datos: contrastar DECLARACIONES_PLAY_RECOMENDADAS.md y SEGURIDAD_DATOS.md con respuestas actuales; incluir SDK/terceros/versiones y retención.
2. Política: URL pública completa y accesible sin login. No utilizar el resumen de portada actual como evidencia.
3. Eliminación: URL externa y flujo real probado. No marcar una supresión integral por tener un botón o correo.
4. Acceso: credenciales dedicadas fuera de Git y pasos para usuario/negocio. Indicar cualquier OTP/permiso y cómo acceder sin barreras innecesarias; no desactivar seguridad.
5. Anuncios: decidir con el modelo de destacadas/RIIOTE, no solo con la lista de SDK.
6. Público y clasificación: completar IARC y selección de edades según contenido real; revisar UGC y controles. No enviar categorías especiales que no apliquen.

Fuente: https://support.google.com/googleplay/android-developer/answer/9859455

## 5. Ficha y recursos

Main store listing / Ficha principal: Cercly, textos actuales de FICHA_GOOGLE_PLAY.md, contacto público y enlaces aprobados; icono y gráfico preparados. Sustituir capturas antiguas de rutas internas por capturas del APK RC2 real y de la salida externa, sin datos personales. Revisar preview de todas las imágenes. No subir pantallas de evaluación como Producción.

## 6. Track y revisión

No cargar todavía una candidata como lista para revisión: falta corrección/validación de eliminación, publicación de política y decisiones/QA. Después de autorización, elegir el track correspondiente y seguir PLAN_12_TESTERS_14_DIAS.md si aplica. La distribución de una prueba también requiere permiso del titular y declaraciones correctas. No pulsar Send for review / Enviar a revisión ni Start rollout / Iniciar lanzamiento sin autorización separada.

Para cuenta personal posterior al 13/11/2023, confirmar en Dashboard los requisitos de prueba cerrada y acceso a Producción. No se acredita cumplimiento ni aprobación en este trabajo.
