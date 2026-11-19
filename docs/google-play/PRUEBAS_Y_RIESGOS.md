# Pruebas, omisiones y riesgos

Fecha: 19/11/2026. Código release: c14e42d6441b09779e76d7f99404bc7dd1100f74.

## Resultados finales

| Prueba | Resultado | Alcance |
|---|---|---|
| flutter pub get | APROBADO | Lockfile sin cambios; no se actualizó Flutter ni dependencias mayores |
| Formato Dart de cambios | APROBADO | Formateados y comprobados en la rama de release |
| flutter analyze | APROBADO | Sin incidencias |
| Flutter completo de integración | APROBADO | 453 aprobadas, 21 omitidas, 0 fallidas |
| Flutter completo del código definitivo | APROBADO | 461 aprobadas, 21 omitidas, 0 fallidas |
| Nueve integraciones de lectura ejecutadas aparte | APROBADO | 9 aprobadas, 0 omitidas, 0 fallidas en Production con clave publicable y coordenadas fijas |
| Deno rutas | APROBADO | 21 aprobadas, 0 fallidas; 16 nuevas sobre entrypoint real con HTTP interceptado |
| deno check | APROBADO | Entrypoint calcular-ruta sin cambiar su contenido desplegado |
| Node seguridad | APROBADO | 5 archivos de pruebas; eliminación, sesión FCM y promoción |
| git diff --check | APROBADO | Sin errores de espacios |
| CI HEAD PR40 | APROBADO | [run 44581296984](https://github.com/Anthony8724/Cercly/actions/runs/44581296984), éxito y APK debug Staging |
| Build APK/AAB | APROBADO | Release real, firma existente, package Production, SDK 36 |
| Política web local | APROBADO | ESLint, TypeScript; 16 pruebas tras sincronización. Next compiló con Webpack y Chrome mostró política completa |
| Prueba manual Android completa | PENDIENTE | Sin dispositivo; dos arranques del AVD fallaron con salida 139 |
| Prueba remota autenticada de eliminación | PENDIENTE | No se borraron cuentas reales ni se creó una prueba destructiva sin identificar fixture autorizado |

Las pruebas HTTP locales usan datos sintéticos y servicios/pantallas reales contra un servidor interceptado o de loopback. No prueban RLS remota ni disponibilidad del proveedor. No se sustituyó la implementación Production por una simulación.

## Omisiones

Son las mismas 21 de la base. Nueve requieren Supabase configurado: cuatro del catálogo público, cuatro de promociones y una de destacadas. Las doce restantes dependen de la variante de proximidad Production que permanece bloqueada (`test/production_proximity_navigation_test.dart`, casos parametrizados). No se habilitaron flags para aparentar cobertura.

Las omisiones de una función deshabilitada son esperadas para esta variante. Las nueve de datos públicos se ejecutaron después, de forma separada, con configuración publicable Production: 9/9 aprobadas. La consulta remota adicional encontró una promoción pública vigente y ninguna tabla public sin RLS. Algunos tests permiten retornar si una búsqueda está vacía; no confundir aprobación con cobertura de todos los datos/ramas. En conjunto se ejecutaron 470 casos Flutter distintos; quedan 12 casos condicionados a proximidad deshabilitada. No ejecutar tests remotos de escritura o supresión contra usuarios reales.

## RIIOTE y goldens

El commit 7a6f919 contiene el footer, tests de apertura/error y adaptación a 260×480 y el golden Mi cuenta. Inspección visual del golden actualizado y evidencia anterior: patrocinio discreto, enlace correcto, sin recorte en la referencia. La suite definitiva conserva los goldens aprobados. El nuevo test de créditos comprueba 260 px y escala de texto 2; el test previo de Radar detectó solapamiento y se corrigió aumentando su margen inferior, sin retirar aserciones.

En el worktree original existen cuatro PNG no rastreados de fallos anteriores: masterImage, testImage, isolatedDiff y maskedDiff de Mi cuenta. Se inspeccionaron las imágenes relevantes y se conservaron intactas. No se añadieron ni se limpiaron automáticamente.

## Riesgos que impiden GO

1. **URL de política:** respuesta pública 307 a /#privacidad. El resumen de portada no reemplaza una política completa. El PR web está preparado, no publicado.
2. **Proveedor de rutas:** [términos oficiales HeiGIT](https://account.heigit.org/info/tos) restringen transmisión de datos personales y licencian resultados bajo CC BY-SA 4.0. Las coordenadas de una persona pueden ser personales aunque no se envíe su UUID. Se necesita una solución contractual o técnica y validarla; consentimiento por sí solo no demuestra compatibilidad. No se autorizó un contacto al proveedor ni se desactivaron rutas silenciosamente.
3. **Eliminación y retención:** endpoint real, no solo UI; exige getUser y RPC de sesión reciente, revoca sesiones y revalida antes de Auth.deleteUser. No hay prueba integral de esta revisión ni política general de retención aprobada. Casos con fotos/historial o negocios pueden quedar en revisión. El borrador web de 90 días para soporte es una propuesta no aprobada y no cubre la app.
4. **Console:** no contrastados versionCode 26, certificado de carga, Play App Signing, datos de cuenta y acceso a Producción. Tampoco hay evidencia de testers 12/14 si aplica.
5. **Datos y contenido:** promociones destacadas, referencias de pagos y aportes de negocios requieren cerrar clasificación de datos, anuncios, UGC, contenido y política de pagos. No hay SDK de billing ni cobro de tarjetas implementado; no inferir por ello una exención aplicable.
6. **Prueba nativa:** pendiente Android 15/16, OAuth/deep link de release, aproximada/precisa, red, permiso denegado, eliminación y rendimiento con APK real. La prueba histórica HONOR fue +25.

## Riesgos residuales

- Avisos Supabase por RPC definer y protección de contraseñas filtradas deshabilitada: controles puntuales inspeccionados, sin auditoría total ni cambio Production.
- Firebase no se activa para push promocional, pero conserva providers, receivers y permiso RECEIVE. Requiere revisar tráfico automático y restricciones de API. No se retiró un SDK sin validar el efecto en autenticación/notificaciones integradas.
- Cuota por usuario no impide abuso por múltiples cuentas ni demuestra presupuesto global del proveedor. No se cambiaron límites o plan ni se aceptó gasto.
- Caché de teselas OSM: URL y user agent identifican Cercly; la política exige caché y atribución. Verificar headers/cache efectivo del cliente antes de sostener cumplimiento integral. No hay descarga masiva implementada. [Política OSM](https://operations.osmfoundation.org/policies/tiles/).
- Build advierte uso KGP por firebase_core, opciones Java 8 antiguas y APIs obsoletas de plugins. Compila hoy; futura migración requiere revisión separada, no actualización mayor indiscriminada.
- Jarsigner valida el AAB y señala certificado autofirmado y ausencia de timestamp; no equivalen a fallo de firma Android. Persisten advertencias de entradas verificadas por JarFile/JarInputStream que deben contrastarse con validación de Play, sin borrar firmas.
- ELF64/alineación 16 KB y AAB válidos no sustituyen ejecutar en Android con páginas de 16 KB.

## Casos manuales de salida

Inicio/registro/recuperación y Google OAuth; enlaces de autenticación; búsqueda con/sin permiso y ubicación aproximada; categorías, mapa/detalle/promociones; consentimiento de rutas cancelado/aceptado; 401/403/429/5xx y offline sin reintentos en bucle; enlace externo; RIIOTE; preferencias y sesión tras reiniciar; eliminación de fixture propio sin dependencias y caso en revisión; asegurar que push/geofencing bloqueados no se activan; TalkBack, texto 200 %, navegación por teclado donde aplique, contraste y barras del sistema. Registrar dispositivo, SO, SHA de APK y resultados concretos.
