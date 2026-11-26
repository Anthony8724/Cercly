# Publicación legal: ramas, efecto público y controles

**Preparado; no ejecutar sin autorización.** Consulta de GitHub/Vercel del 19/11/2026. Proyecto Vercel `cercly`, repositorio `Anthony8724/cercly-web`, dominio `cercly-web.vercel.app`.

## Estado comprobado

- PR #15: `compliance/play-privacy-routes-20261119` → `compliance/play-readiness`, borrador abierto. Contiene las páginas corregidas y la base del PR #16.
- PR #16 ya fue fusionado por el titular en `compliance/play-readiness`, commit `deeb4d654f37b25a692dce58377567994be68504`. La aprobación parcial de 90 días se conserva.
- PR #6: `compliance/play-readiness` → `main`, borrador abierto. Incluye **más cambios que las tres páginas legales**: portada, soporte, navegación, SEO y formularios condicionados.
- `main` permanece en `52556072b7e1b3572fc7ec3a712dc7727e65fed4`.
- El deployment que sirve el dominio público es Vercel `dpl_9Fb4tXLjcDqFK4iTDKrzcK9pDeqL`, READY, target `production`, source `git`, rama `main` y ese SHA. No se leyó/modificó ningún secreto de Vercel.
- Publicación actual: `/privacidad` redirige a `/#privacidad`, `/eliminar-cuenta` responde 200 y `/terminos` devuelve 404. La candidata local responde 200 en las tres.

## Camino principal, cuando exista autorización explícita

1. Revisar y aprobar el texto de `propuesta-politicas-rc2-titular.md`, los tres HTML y los controles pendientes. No presentar el actual borrador como cumplimiento completo. Mantener formularios/portal deshabilitados mientras su operación no esté acreditada.
2. Reconsultar HEAD, base, comentarios y checks de #15/#6. Si hay cambios concurrentes, integrarlos sin sobrescribirlos y repetir solo los controles afectados. Verificar el diff acumulado de #6 frente a `main`.
3. Con autorización específica de integración, fusionar **#15 hacia `compliance/play-readiness`**. Esa operación no actualiza por sí sola la rama pública `main`; la integración Git puede crear una Preview. No promoverla automáticamente.
4. Revisar la Preview resultante con sesión Vercel autorizada, sin desactivar SSO. Comprobar `/privacidad`, `/eliminar-cuenta`, `/terminos`, contacto y que no se habilitaron formularios/OTP por variables del entorno. La configuración de Production debe revisarse sin revelar sus valores.
5. Obtener autorización separada para **#6 hacia `main`** y para la publicación. Es la operación que previsiblemente dispara el despliegue Git de Producción y cambia el sitio público completo incluido en ese PR. Reconfirmar en Vercel Settings → Environments/Production y Git que `main` sigue siendo la rama de Production antes de ejecutarla; el deployment observado demuestra el origen actual, no una garantía de configuración futura.
6. Tras el merge autorizado, esperar READY del deployment **del SHA nuevo** y verificar que el dominio público apunta a ese deployment. No usar `vercel --prod`, promover una Preview ni cambiar DNS como atajo.
7. Comprobar desde una sesión sin login: HTTPS 200 sin redirección a portada, contenido completo de Cercly, fecha, contacto, enlaces y vista móvil de las tres páginas. Revalidar también los enlaces desde la APK. Guardar SHA/URL/fecha y evidencia saneada.

## Si solo se autorizan las páginas legales

No fusionar #6 completo bajo esa autorización. Preparar una rama nueva desde el `main` entonces vigente, trasladar los cambios y dependencias mínimos de las páginas, abrir un PR acotado y validar su árbol exacto. Esto puede incluir layout, estilos, contacto y dependencias; no asumir que basta con copiar tres TSX. Aprobar ese diff y su publicación por separado. No se creó ahora otra implementación ni se modificó `main`.

## Efectos que NO produce la publicación de la web

No aplica la migración de eliminación, no cambia el APK RC2, no habilita de forma probada el portal, no envía declaraciones de Play ni sustituye la prueba cerrada. Los enlaces de correo requieren que el usuario envíe el mensaje; una aceptación Formspree no demuestra atención o eliminación.

Fuente de comportamiento Git/Preview: https://vercel.com/docs/git. Evidencia del deployment público: `docs/google-play/evidencias/publicacion-web-origen.json` en el repositorio Android de preparación.
