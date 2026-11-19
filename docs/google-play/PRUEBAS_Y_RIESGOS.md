# Pruebas y riesgos — RC2

Código compilado `40c1f2fd5af3027ccd896e03ef1a17e848068069`, web `a1f721bc8ba6f02d489fe02cc3b45281872783c2`. Revisión del 19/11/2026.

| Control | Resultado | Alcance |
|---|---|---|
| Flutter completo | 468 aprobadas, 21 omitidas, 0 fallidas | Incluye RIIOTE, goldens, Radar y barreras de rutas |
| Lecturas remotas separadas | 9 aprobadas, 0 omitidas/fallidas | Catálogo/promociones Production, clave publicable, datos públicos fijos; sin escrituras |
| Flujos enfocados de rutas | 59/59 y 11/11 con flags hostiles | Cero consultas GPS/servicio interno; cancelar/confirmar/error; `.test` solo para protocolo aislado |
| Deno | 21/21, deno check aprobado | Endpoint real con HTTP interceptado; no se invoca HeiGIT |
| Node | 37/37 | Eliminación, sesiones FCM y promociones con dobles |
| SQL | 802/802, 30 suites | Contenedor nuevo sin red, fixtures/rollback; 15 regresiones nuevas de cuota/eliminación |
| Gradle negativo | 3/3 rechazos esperados | ORS_API_KEY, service_role y rutas simuladas públicas; no es fallo de la build candidata |
| Web | 32/32, lint/TypeScript/build Webpack aprobados | Cinco rutas HTTPS 200; 15 vistas con axe/teclado/sin recorte del selector |
| APK/AAB | Compilados y verificados | Firma histórica, SDK 36, bundletool/zipalign/ELF64 y escaneo definido |
| HONOR/Android nativo | PENDIENTE | No hay dispositivo conectado; no presentar la prueba histórica +25 como RC2 |
| Eliminación GoTrue/Storage HTTP | PENDIENTE | SQL y dobles no acreditan bytes de Storage, correo ni JWT real tras eliminación |
| CI RC2 | APROBADO | Android 44639065759 en 48257b8; web quality 44638985403 en a1f721b. Posteriores documentos y prueba de retención revalidados localmente |

Los 21 omitidos de la suite sin defines son los mismos nueve de integración pública, ejecutados aparte, y doce de proximidad Production bloqueada. En conjunto: **477 casos Flutter distintos ejecutados, 12 condicionados a función deshabilitada**. Algunos tests públicos permiten datos vacíos; no confundir su aprobación con cobertura completa del catálogo.

## Fallos detectados y corregidos

- Cuota de rutas introdujo FK que la guarda global de eliminación no reconocía. Diagnóstico remoto de solo lectura confirmado; corrección exacta y 15 regresiones pasan localmente. Production sigue BLOQUEADA hasta autorización, despliegue y ensayo de fixture.
- Cómo llegar enviaba coordenadas a un proveedor sin autorización acreditada. La nueva candidata abre Maps con solo destino tras confirmación; servicios reales fallan antes de red. No se sustituyó por una simulación.
- Webpack compilaba sin utilidades Tailwind por configuración exclusiva de Turbopack. La inspección visual mostró recorte del selector que axe no detectó. Se añadió únicamente @tailwindcss/postcss 4.3.3 y configuración oficial para ambos motores; sin cambios mayores de framework. Se añadió una comprobación real de dimensiones y se repitió la auditoría.

## Riesgos y límites restantes

1. Política pública aún requiere publicación autorizada; revalidar /privacidad tras integrar/desplegar, no confundir HTTP local 200 con web pública.
2. Eliminación: backend desplegado conserva el fallo de FK, Storage bloquea casos con objetos; no hay retención general ni canal externo integral acreditados.
3. Data safety: no se leyeron respuestas actuales de Console; SDK nativo Firebase permanece. Con estados previos, la retirada puede inicializarlo para revocar instalaciones. No afirmar ausencia total de tráfico automático.
4. UGC/anuncios/pagos/público: controles y alcance por revisar; no se acredita aceptación versionada de términos, denuncia/bloqueo genéricos ni una exención automática.
5. Cuenta Play, código 26 y upload certificate pendientes de contraste; prueba 12/14 solo si aplica y sin evidencia de cumplimiento.
6. SDK/ELF estáticos correctos no sustituyen ejecutar Android 15/16, HONOR, OAuth/deep links, red/permisos ni 16 KB reales.
7. Términos HeiGIT no se revalidaron exitosamente en esta nueva consulta (503). No se activa por una presunta excepción; versiones/backend anteriores siguen sin cambios.
8. Avisos Supabase de RPC definer y protección de contraseñas filtradas siguen sujetos a revisión; no se activaron servicios pagados ni se modificaron privilegios reales.
9. Warnings de firebase_core/KGP, opciones Java antiguas y certificado autofirmado/sin timestamp se documentan. Firma/bundletool verifican hoy; revisar compatibilidad futura por separado.

## Evidencias e historia

Registros de esta ejecución: /tmp/cercly-play-close-20261119 y la carpeta RC2 de Descargas. JSON saneados en evidencias/. Las capturas web son de páginas locales reales, no de Android. Las capturas de Play siguen pendientes.

La carpeta test/failures/ original (cuatro PNG previos de Mi cuenta) se conserva sin seguimiento. Los goldens actuales pasan; RIIOTE continúa visible y enlazado. La candidata anterior tuvo 461 pruebas, pero sus binarios/hashes son históricos y no corresponden a RC2.

La base web recibió concurrentemente PR #16 (deeb4d6), aprobación parcial de retención. Se integró sin conflictos y se repitió verify completo: 32/32 y 15 vistas sin infracciones/errores. No cambió código de páginas, configuración ni lockfile respecto de a1f721b; no requiere nuevos binarios Android. El primer intento de verificación fue impedido por permisos locales de sockets; la ejecución autorizada posterior terminó correctamente.
