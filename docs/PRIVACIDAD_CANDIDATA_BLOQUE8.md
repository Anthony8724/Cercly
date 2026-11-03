# Política de privacidad candidata · Cercly

**Estado: borrador interno; no vigente ni publicable.** Preparado el 28 de
octubre de 2026 a partir del código local y de pruebas sintéticas en Supabase
local. Las pruebas locales no demuestran la configuración ni el tratamiento
de producción.

## Texto candidato basado en prácticas comprobadas localmente

Cercly es una aplicación para consultar y administrar establecimientos y
promociones y se publicará como proyecto personal. El titular identifica a
**Anthony Lopez**, en **Ecuador**, como responsable previsto del proyecto y del
tratamiento de datos personales, sujeto a confirmar que ese nombre coincide
con el nombre legal de la cuenta personal de desarrollador de Google Play y
que esa persona determina efectivamente los fines y medios del tratamiento.
Cercly no atribuye esa responsabilidad a la UPEC ni a una empresa.

No se han proporcionado domicilio, identificación tributaria ni otros datos
legales; no se inventan ni se afirma que una obligación legal esté cumplida.
Antes de publicar, confirmar si corresponde incluir datos adicionales según
la jurisdicción aplicable. Hasta cotejar la identidad y verificar la
responsabilidad efectiva, esta política sigue siendo un borrador.

### Datos y finalidades

El código contempla cuentas autenticadas, perfiles y roles; nombres,
direcciones, coordenadas y otra información de establecimientos; membresías de
responsables; solicitudes comerciales; promociones; e imágenes asociadas. Estos
datos permiten iniciar sesión, mostrar establecimientos, administrar
responsables y tramitar solicitudes. La información destinada a fichas públicas
puede mostrarse a otras personas usuarias.

La aplicación puede obtener ubicación precisa en primer plano, después de una
acción y explicación en la interfaz. La usa para centrar el mapa, buscar
establecimientos cercanos y calcular proximidad. La consulta de cercanía envía
coordenadas a Supabase. Los mosaicos del mapa se solicitan a OpenStreetMap; si
la persona solicita indicaciones, Google Maps recibe las coordenadas de destino
del establecimiento. No se encontró permiso Android para ubicación en segundo
plano.

El código admite inicio con correo y contraseña y contiene integración Google
OAuth, pero la configuración efectiva de los proveedores de producción no se
ha comprobado. Las pruebas de este bloque usaron Supabase local, usuarios
sintéticos, Mailpit y las claves oficiales de prueba de Turnstile; Mailpit y
esas claves son elementos de prueba, no proveedores de producción confirmados.

### Eliminación y datos compartidos

En el entorno local, una cuenta autenticada sin dependencias se eliminó de
Auth y su perfil; la sesión anterior dejó de ser válida. Una solicitud
repetida mantuvo una sola fila. Cuando la cuenta poseía un establecimiento, el
borrado se detuvo para revisión. Un administrador autenticado pudo transferir
la propiedad a una persona responsable activa y aprobar la solicitud; después,
el titular autenticado completó la eliminación y el establecimiento permaneció
bajo el nuevo titular. Al eliminar una cuenta miembro, se retiró su membresía
y se conservó el negocio compartido.

Las solicitudes comerciales pendientes requieren revisión y permanecieron
intactas durante la prueba. Los archivos no se borran automáticamente por
SQL: una imagen sintética eliminada por su titular desapareció de Storage; un
intento ajeno devolvió HTTP 200, pero no alteró la fila ni el archivo. Estos
resultados describen el entorno local; la integración alojada aún requiere
verificación.

La auditoría local de revisión conservó identificadores UUID de sujeto y actor,
acciones, establecimiento y fecha después de eliminar Auth. No se verificó una
caducidad automática ni un plazo de conservación para esos registros. Un fallo
simulado tras eliminar Auth puede dejar pendiente la limpieza de la fila de
solicitud; el código lo comunica para reconciliación.

### Contacto

Para consultas de privacidad, soporte o eliminación: **1hlopezanthony@gmail.com**.
El titular autoriza este correo como contacto público y confirma que recibe
correos regularmente en ese buzón. La recepción de correo no se ha probado
desde el enlace público del sitio; además, el remitente de un correo no
verifica por sí solo la titularidad de una cuenta. Nunca se deben enviar
contraseñas ni códigos OTP por correo.

## Decisiones y verificaciones pendientes

- Cotejar que Anthony Lopez sea el nombre legal completo asociado a la cuenta
  personal de desarrollador de Google Play y verificar que efectivamente
  determina los fines y medios del tratamiento. El titular confirma que será
  un proyecto personal; no se debe identificar a la UPEC ni a una empresa.
- El país declarado es Ecuador; confirmar la jurisdicción aplicable y si exige
  publicar domicilio u otros datos identificativos. No añadir datos no
  confirmados ni inventados.
- Confirmar qué proveedores de Auth están activos en producción, incluyendo
  Google OAuth, sus consentimientos, redirects y datos compartidos.
- Identificar proyecto/región de Supabase, proveedor SMTP, condiciones,
  subencargados, registros y retención del entorno alojado.
- Confirmar el proveedor y las condiciones del servidor de mosaicos usado por
  la app, y la configuración real de Google Maps.
- Aprobar finalidades y plazos de conservación para perfiles, negocios,
  membresías, solicitudes comerciales, evidencias, archivos, auditoría,
  registros técnicos, correos y respaldos.
- Definir qué se elimina, anonimiza o conserva al cerrar solicitudes
  pendientes y al transferir negocios compartidos; verificar que los respaldos
  permitan cumplir cualquier plazo que se publique.
- Verificar en staging alojado Auth, plantilla OTP, SMTP, Turnstile, Edge
  Function, Storage, RLS, registros y eliminación; no se consultó ni modificó
  Supabase remoto.
- Confirmar la configuración del entorno Vercel. El dominio público consultado
  devolvió 404 para `/privacidad`, `/eliminar-cuenta` y la ruta de configuración
  del portal; el estado de sus variables no pudo verificarse.

Hasta resolver estos puntos, mantener el aviso de borrador, no declarar la
política vigente y no usar este texto como política de Google Play.
