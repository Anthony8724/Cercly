# Bloque 9 · Preparación de staging y Google Play

**Estado: preparación local; no se ha creado staging ni se ha desplegado nada.**
Fecha de comprobación: 28 de octubre de 2026.

## Entorno Supabase

La consulta de solo lectura a la cuenta conectada mostró un único proyecto,
`aimubazregckmjchnszf` (`Cercly`), estado `ACTIVE_HEALTHY`, región `us-east-2`
y PostgreSQL 17. No hay branches de desarrollo. Ese proyecto es el principal
y no se debe usar para pruebas destructivas. No se ejecutaron consultas ni
escrituras contra él.

La cotización consultada para la misma organización fue **$0 mensual** para un
proyecto nuevo y **$0.01344/hora** para una branch. La cotización puede cambiar.
Quedó pendiente autorización explícita para crear el proyecto separado en esa
organización. La opción recomendada es un proyecto `Cercly Staging` dedicado,
con región aprobada, credenciales independientes y sin importar datos ni
respaldos del proyecto principal. No hay URL, claves, contraseña de base de
datos, SMTP ni secretos de staging disponibles todavía.

La validación local de los Bloques 7 y 8 ya cubrió Postgres, Auth, PostgREST,
Storage, Edge Runtime y Mailpit con datos sintéticos. El stack local fue
detenido preservando sus volúmenes. No se repitieron las 111 aserciones pgTAP
ni los recorridos HTTP.

## Preparación reproducible después de autorizar staging

1. Crear un proyecto aislado con credenciales nuevas. Guardar contraseña de
   base, publishable key, secret/service-role key y credenciales SMTP en un
   gestor de secretos. No reutilizar valores de producción ni incluirlos en
   Git, Flutter, Next.js o logs.
2. Antes de cualquier `db push`, confirmar visualmente que el ref enlazado es
   exclusivamente el de staging. Revisar `supabase migration list` y ejecutar
   primero `supabase db push --dry-run`; aplicar luego únicamente las 19
   migraciones versionadas de `supabase/migrations/`. No usar `--include-seed`
   ni los CSV/SQL de importación geográfica como fixtures de cuentas.
3. Configurar Auth en staging: registro por correo habilitado solo si hace
   falta para la prueba; OTP de seis dígitos, expiry aprobada para test,
   plantilla `supabase/templates/magic_link_otp.html` con `{{ .Token }}` y
   SMTP de sandbox hacia buzones controlados. El valor local `otp_expiry=3600`
   es configuración del entorno local, no compromiso ni ajuste remoto.
4. Configurar Google OAuth solo con un cliente OAuth de pruebas y redirect URI
   de staging. Si no está listo, excluir OAuth de las pruebas y dejarlo
   deshabilitado en staging.
5. Crear buckets y políticas aplicando las migraciones; comprobar acceso con
   cuentas sintéticas distintas. Desplegar `eliminar-cuenta` solo al proyecto
   staging, con verificación JWT activada. Sus dependencias de runtime son
   `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`; esta
   última nunca se entrega al cliente. La publicación de la función es un paso
   futuro y requiere confirmar el ref de destino.
6. Mantener el portal web automatizado apagado hasta validar OTP, SMTP,
   Turnstile, Auth, Edge Function y Storage en staging. En Vercel, dejar
   `ACCOUNT_DELETION_ENABLED` ausente o `false` durante la preparación.
7. Crear solo usuarios, negocios, solicitudes y objetos identificados como
   sintéticos; usar buzones de prueba controlados para recibir OTP. No copiar
   usuarios, perfiles, negocios, archivos, logs ni respaldos de producción.
8. Guardar resultados sin tokens, direcciones personales ni contenido de
   solicitudes. Verificar estado final en Auth, base y Storage; luego eliminar
   las fixtures sintéticas desde las interfaces autorizadas.

La configuración de Auth/SMTP, OAuth, CAPTCHA, URL de sitio y redirects no se
despliega íntegramente por migraciones PostgreSQL: deben prepararse y revisarse
en el proyecto de staging sin copiar settings del principal. Los valores
concretos quedan pendientes hasta crear el proyecto y sus credenciales.

## Aprobación pendiente de privacidad

- [x] El titular declara el nombre Anthony Lopez, país Ecuador, proyecto
  personal Cercly y contacto `1hlopezanthony@gmail.com`; no atribuir
  responsabilidad a UPEC ni a una empresa.
- [ ] Cotejar que Anthony Lopez coincida con el nombre legal completo de la
  cuenta personal de desarrollador de Google Play y verificar que esa persona
  determina efectivamente los fines y medios del tratamiento.
- [ ] Confirmar la jurisdicción aplicable y si exige domicilio u otros datos
  identificativos. No inventarlos ni afirmar obligaciones legales cumplidas.
- [x] Contacto público autorizado: `1hlopezanthony@gmail.com`.
- [ ] Probar el enlace de contacto y el procedimiento de atención en el sitio
  que se publique.
- [ ] Identificar la base jurídica aplicable y definir el canal para ejercer
  derechos.
- [ ] Conservación aprobada por categoría: perfil, membresía, negocio,
  solicitud comercial, imágenes, auditoría, logs, correo y respaldos.
- [ ] Criterio para datos de negocios compartidos y solicitudes pendientes al
  eliminar una cuenta; responsable de revisión y reconciliación.
- [ ] Validar proveedores, región, OAuth, SMTP, mapa, CAPTCHA, logging y
  respaldos realmente activos en los entornos alojados.
- [ ] Revisar la candidata `docs/PRIVACIDAD_CANDIDATA_BLOQUE8.md` frente a esos
  hechos y retirar su aviso de borrador solo con aprobación.

Las propuestas de conservación no son prácticas implantadas ni promesas
públicas. No publicar la candidata mientras queden decisiones esenciales.

## Lista de preparación de Google Play

### Antes de enviar al canal interno

- [ ] Publicar una política de privacidad activa, accesible y coherente con el
  formulario Data safety y los tratamientos verificados; enlazarla también
  desde la app.
- [ ] Publicar una URL de eliminación funcional que identifique Cercly y
  permita iniciar la solicitud sin reinstalar la app; mantener un acceso
  intuitivo dentro de la app. El sitio consultado anteriormente devolvió 404;
  volver a comprobar las rutas públicas después de una publicación autorizada.
- [ ] Mantener el portal OTP/Turnstile apagado hasta que staging y Vercel hayan
  pasado las verificaciones; validar que la alternativa de contacto recibe y
  tramita solicitudes de forma segura.
- [ ] Completar Data safety, declaraciones de eliminación, audiencia y
  clasificación de contenido con base en SDKs, permisos, configuración remota
  y política final. No inferir respuestas desde la configuración local.
- [ ] Revisar permisos declarados y comportamiento real, incluidos ubicación
  precisa/aproximada y notificaciones. Mantener solo permisos requeridos por
  funciones vigentes y explicar ubicación antes de solicitarla.
- [ ] Proporcionar a revisión de Play instrucciones y una cuenta de prueba
  estable para funciones autenticadas, sin compartir credenciales personales;
  documentar cómo llegar a mapas, perfiles y solicitudes.
- [ ] Verificar AAB release firmado con la clave de carga privada, paquete
  `com.cercly.cercly`, versión y `targetSdk` efectivos del artefacto; conservar
  claves y bundle privados/locales hasta la autorización de subida.
- [ ] Completar ficha, icono, capturas, soporte y datos de la cuenta de
  desarrollador en Play Console. Confirmar requisitos de identidad/verificación
  que Play Console muestre para esa cuenta.

El proyecto fija `applicationId` en `com.cercly.cercly` y declara
`targetSdk = flutter.targetSdkVersion`; este archivo Gradle no fija por sí solo
el entero efectivo. Debe confirmarse en el AAB final. Google anunció que, desde
el 31 de agosto de 2026, las nuevas apps y actualizaciones deben targetear API
36 o superior. Por la fecha actual, API 36 es el mínimo aplicable para una
nueva entrega móvil estándar.

### Después del canal interno

El canal interno no equivale a producción ni sustituye pruebas cerradas que
pudieran requerirse para acceso a producción. Para cuentas personales creadas
después del 13 de noviembre de 2023, Google Play actualmente requiere al menos
12 participantes inscritos continuamente durante 14 días en una prueba
cerrada antes de solicitar acceso a producción. Confirmar la categoría y fecha
de creación de la cuenta Cercly en Play Console; no asumir que ese requisito
aplica a la cuenta sin verificarla.

## Pruebas de este bloque

- Consulta Supabase de proyectos y branches: solo lectura; un proyecto
  principal y cero branches visibles.
- Consulta de cotización de proyecto y branch: completada; sin crear recursos.
- Migraciones/OTP/Edge/Storage locales: verificadas en Bloques 7 y 8; no
  repetidas aquí.
- Flutter, lint y builds: no ejecutados en este bloque; no se modificó código
  de aplicación ni web.
- No se desplegó staging, función, web ni aplicación; no se modificó
  producción.

## Referencias oficiales revisadas

- [Requisito de target API de Google Play](https://developer.android.com/google/play/requirements/target-sdk)
- [Eliminación de cuentas de apps en Google Play](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Preparar una app para revisión](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Pruebas requeridas para nuevas cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Migraciones Supabase](https://supabase.com/docs/guides/deployment/database-migrations)
- [Flujo CLI de migraciones remotas](https://supabase.com/docs/guides/local-development/cli-workflows)
