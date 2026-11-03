# Bloque 10 · Estado de Supabase Staging

**Staging:** `dlajxviqhkdcqnmczhvr` · `Cercly Staging` · `us-east-2`
**Estado al 28 de octubre de 2026:** proyecto alojado activo; validación parcial.

Producción (`aimubazregckmjchnszf`) no se consultó ni modificó durante la
aplicación de cambios, pruebas o configuración de este bloque.

## Proyecto y migraciones

- La sesión conectada enumeró Staging y el proyecto Cercly principal; la
  conexión de escritura utilizada en esta fase fue exclusivamente al ref de
  Staging. PostgreSQL alojado reporta versión 17.11.
- El repositorio contiene 19 migraciones. Se aplicaron en orden al proyecto
  nuevo. PostGIS 3.3.7, pgcrypto y uuid-ossp están instaladas. Quedaron las
  14 categorías y 57 subcategorías previstas; no se cargaron cuentas ni datos
  geográficos de producción.
- El conector de migraciones inicialmente asignó versiones basadas en la hora
  de aplicación. Se alinearon las 19 versiones de
  `supabase_migrations.schema_migrations` con los prefijos originales de los
  archivos. Verificación posterior: 19/19 coinciden, 0 divergencias.
- En el examen estático no había `DROP TABLE`, `DROP SCHEMA` ni `TRUNCATE` en
  las migraciones. Los `DROP POLICY` y `DROP TRIGGER` observados reemplazan
  objetos identificados por nombre.
- Las migraciones configuran buckets privados y políticas; no configuran por
  sí mismas SMTP, credenciales OAuth, CAPTCHA ni URLs de redirect.

El CLI local es 2.119.0 y puede listar proyectos, pero el repositorio no tiene
`supabase/.temp/project-ref` y `SUPABASE_DB_PASSWORD` no está disponible.
Por eso no se ejecutó `supabase db push --dry-run`; las migraciones se
aplicaron mediante la conexión Supabase administrada y el historial quedó
alineado con los archivos locales.

## Configuración local separada

Se creó `config/supabase.staging.local.json`, ignorado por Git, con solo
`SUPABASE_URL` y la clave publicable de staging. Se decodificó la referencia
del JWT publicable sin mostrar la clave y coincide con
`dlajxviqhkdcqnmczhvr`. No contiene contraseña, service-role key ni secretos.
Para una ejecución Flutter explícita de staging se puede usar:

```sh
flutter run --dart-define-from-file=config/supabase.staging.local.json
```

La app y `config/supabase.local.json` no se cambiaron para usar staging por
defecto.

## Auth, Storage y Edge Function

- Auth HTTP `/auth/v1/settings`: **200**. Correo habilitado, teléfono
  deshabilitado, Google OAuth deshabilitado y `mailer_autoconfirm=false` (la
  cuenta debe confirmar correo).
- No se obtuvo evidencia de SMTP configurado ni de la plantilla OTP alojada.
  No se solicitó ni validó un OTP; el HTML `{{ .Token }}` sigue comprobado solo
  en el repositorio/local. Falta SMTP sandbox y un buzón sintético controlado.
- Storage tiene los buckets privados `establecimientos-imagenes` y
  `promociones-imagenes`; las ocho tablas internas de Storage tienen RLS.
  No hay objetos cargados. La lista HTTP anónima de un bucket devolvió **200**
  con cero objetos.
- Edge Function `eliminar-cuenta`: versión 1, estado `ACTIVE`, desplegada solo
  en Staging con `verify_jwt=true`. POST sin sesión: **401**. Esto comprueba el
  control de entrada; no valida la ejecución con JWT ni la disponibilidad de
  sus secretos de runtime.
- El proveedor Google está apagado. Para probar Google Sign-In hará falta un
  cliente OAuth separado para Staging; no reutilizar credenciales productivas.

## Verificaciones reales

- 19 migraciones aplicadas y con historial alineado; 11 tablas públicas tienen
  RLS habilitado. Las dos tablas administrativas privadas también tienen RLS.
- Un bloque SQL con errores explícitos verificó: `anon` no lee ni escribe
  perfiles, no tiene `TRUNCATE` en las cinco tablas sensibles, no accede a los
  esquemas privados ni a RPCs de eliminación sensibles; `authenticated` solo
  puede actualizar la columna `nombre` del perfil. No lanzó excepción.
- En una transacción con cuentas y negocio sintéticos, simulando claims de dos
  usuarios: el titular vio perfil y negocio y `puede_gestionar_establecimiento`
  devolvió `true`; el atacante vio cero filas y su UPDATE afectó cero filas.
  El nombre original permaneció y `ROLLBACK` eliminó todas las fixtures.
- HTTP con clave publicable de Staging: GET de perfiles anónimo **401**;
  intento anónimo de insertar categoría sintética **401**; RPC anónima
  `es_administrador()` **200 / false**. La fila centinela no quedó creada.
- La verificación final encontró cero usuarios Auth, perfiles, negocios,
  solicitudes comerciales y objetos Storage. Hay dos buckets; pgTAP fue
  temporalmente instalado para una exploración de salida del runner y se
  retiró. No quedaron fixtures ni la extensión de prueba.

El asesor de seguridad de Supabase reporta advertencias sobre funciones
`SECURITY DEFINER` invocables por `anon`/`authenticated`; la única llamada
anónima probada, `es_administrador()`, devolvió `false`. También marca como
informativas tablas privadas con RLS y sin políticas, coherentes con que no se
les conceda acceso cliente. Los grants de tabla de `anon` son más amplios que
los de columna/filas permitidos por RLS en algunas tablas; las pruebas HTTP
anteriores fueron denegadas, pero conviene revisar este mínimo de privilegios
y los avisos de funciones antes de producción.

El test pgTAP `auth_final_permissions_test.sql` se envió al ejecutor SQL, pero
la interfaz solo expuso su última aserción y no el resumen TAP completo; no se
cuenta como suite remota aprobada. Las 111 aserciones pgTAP de Bloques 7/8
siguen siendo evidencia local, no staging.

## Prueba Auth que no pudo completarse

Para evitar enviar correo real se creó temporalmente un registro de Auth
sintético por SQL, con identidad y contraseña no reutilizables. El password
grant HTTP respondió **500 `Database error querying schema`**. Este fixture
manual no equivale a un registro normal de GoTrue y no demuestra un fallo de
registro ni de SMTP. La cuenta fue eliminada; la consulta final confirmó cero
usuarios Auth. No se obtuvo sesión real, por lo que tampoco se probaron OTP,
subida/borrado de archivos ni eliminación/transporte mediante Edge Function
con identidad autenticada.

## Bloqueos y pasos siguientes

1. Configurar en el Dashboard de **Staging**, sin pegar secretos en Git/chat,
   SMTP sandbox (host, puerto, usuario, contraseña, remitente) y un buzón de
   prueba controlado. Revisar plantilla numérica `{{ .Token }}`, vigencia y
   límites de envío; luego ejecutar signup y verificar el OTP recibido.
2. Con una sesión Auth real sintética, probar perfiles/RLS por PostgREST,
   creación/revisión de negocio, subida/borrado Storage y eliminación completa
   por Edge con estado comprobado en Auth, SQL y Storage.
3. Si se prueba Google OAuth, crear cliente y redirects exclusivos de Staging.
4. Revisar advertencias `SECURITY DEFINER` y grants anónimos antes de trasladar
   el esquema a producción.
5. Para Play siguen pendientes política aprobada/publicada, `/eliminar-cuenta`
   público funcional, Data safety y comprobación del `targetSdk` del AAB. No
   se desplegó Vercel ni se modificó o regeneró el AAB.

## Archivos y Git

- `.gitignore`: se añadió la regla para ignorar la configuración local de
  Staging.
- `config/supabase.staging.local.json`: archivo local ignorado; no aparece en
  Git.
- No se cambiaron fuentes Flutter ni migraciones. No se creó commit, push ni
  merge. Se conservaron los cambios preexistentes en `supabase/config.toml` y
  documentos de los Bloques 8/9.
