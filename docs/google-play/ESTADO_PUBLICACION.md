# Estado de preparación de Cercly para Google Play

Revisión: 19 de noviembre de 2026. **Recomendación: NO-GO para subir como versión lista para revisión o publicación.** Se prepararon artefactos candidatos; no se publicó ni se enviaron declaraciones definitivas.

## Integración y código

- PR [#40](https://github.com/Anthony8724/Cercly/pull/40) fusionado mediante merge con comprobación de HEAD: `7a6f919df8f81c06e35008aa1a4cc708bb79e9e5`.
- `origin/develop`: `3ef19a820263c2add7db27a78d43570dd5f52cfd`. Padres: `455d3bb8e1966c7146ec4f0aa05b85cf860fd191` y `7a6f919df8f81c06e35008aa1a4cc708bb79e9e5`. Incluye RIIOTE y el golden actualizado.
- Candidata: `release/play-store-0.1.9-26`, worktree `/tmp/cercly-release-play-01926`; código de compilación `c14e42d6441b09779e76d7f99404bc7dd1100f74`.
- El código del release añade atribuciones enlazadas, espacio para no cubrirlas con el Radar, mensajes de error y pruebas del endpoint; fija `0.1.9+26`. Estas mejoras quedan en la rama de revisión y no se fusionaron automáticamente a develop.
- Web: [PR #15](https://github.com/Anthony8724/cercly-web/pull/15), hacia `compliance/play-readiness`. La rama de revisión conserva los cambios concurrentes del titular y el borrador de retención. No se modificó main ni el sitio público.

## Matriz de salida

| Control | Estado | Evidencia / condición |
|---|---|---|
| Fusión PR #40 y RIIOTE en develop | APROBADO | Merge y ascendencia comprobados |
| CI del HEAD integrado | APROBADO | [44581296984](https://github.com/Anthony8724/Cercly/actions/runs/44581296984), success |
| CI del merge en develop | APROBADO | [44582709183](https://github.com/Anthony8724/Cercly/actions/runs/44582709183), success para 3ef19a8 |
| CI del release | APROBADO | [44632085504](https://github.com/Anthony8724/Cercly/actions/runs/44632085504), success para a77c3a6; mismo código que los binarios c14e42d |
| Regresión release | APROBADO | Suite: 461 Flutter, 21 omitidas, 0 fallidas; además 9/9 lecturas remotas; 21 Deno; analyze sin incidencias |
| VersionName / package / SDK | APROBADO | APK y manifiesto AAB: 0.1.9, com.cercly.cercly, compile/target 36, min 24 |
| Firma local de carga | APROBADO | RSA 4096, huella histórica coincidente; APK y AAB verificados |
| Contraste de firma y versionCode en Play | PENDIENTE | Sin evidencia de Console; 26 es provisional |
| Estructura del AAB y alineación 16 KB | APROBADO | bundletool validate, PAGE_ALIGNMENT_16K, ELF64 y zipalign |
| Secretos privados en artefactos | APROBADO | Búsqueda definida en SEGURIDAD_DATOS, sin hallazgos; no es garantía exhaustiva |
| Rutas apuntan a Producción | APROBADO | Host Production en ambos artefactos, Staging ausente; endpoint intacto |
| Geofencing/push promocional bloqueados | APROBADO | Política enabled=false; receivers de proximidad deshabilitados; sin background location |
| Política completa en URL pública | BLOQUEADO | /privacidad responde 307 a /#privacidad y muestra portada/resumen |
| Compatibilidad contractual de coordenadas con HeiGIT | BLOQUEADO | Términos prohíben transmisión de datos personales; uso requiere resolución documentada |
| Eliminación real y canal externo | PENDIENTE | Función real desplegada, pruebas locales y rechazo 401; falta ensayo integral autorizado |
| Retención y respaldos | PENDIENTE | Borrador de soporte web no aprobado; no cubre toda la app |
| Data safety, anuncios, IARC y público | PENDIENTE | Propuestas fundamentadas; no se enviaron formularios |
| Cuenta Play / acceso a Producción / testers | PENDIENTE | Sin acceso o evidencia de tipo, antigüedad y requisitos cumplidos |
| Capturas y QA Android 15/16 | PENDIENTE | Sin dispositivo; AVD falló con salida 139 en dos configuraciones |
| Icono y feature graphic | APROBADO | PNG 512×512 y 1024×500 revisados visualmente; aprobación comercial pendiente |

## Bloques y commits

| Bloque | Resultado | Commit |
|---|---|---|
| Integración | Merge autorizado, seis commits conservados | 3ef19a8 |
| Release Android/rutas | Código y pruebas, sin cambio de backend | c14e42d |
| Política web | Flujo real y límites de conservación; en borrador | 2ac03dd |
| Sincronización web | Conserva borrador concurrente de retención | a903288 |
| Cierre de inventario web | Incluye referencias económicas sin publicar | f21b059 |
| Documentación | Ocho documentos, evidencias y fuentes gráficas | Consultar git log de esta rama; no modifica código del AAB |

No se ejecutaron migraciones ni despliegues Supabase, no se borraron cuentas reales y los artefactos +25 se conservaron. Los otros worktrees conservan sus ramas y cambios. La carpeta original test/failures/ queda intacta y fuera de Git.

Los criterios de salida son resolver todos los controles obligatorios pendientes/bloqueados, revisar el resultado con el titular y obtener su autorización de envío. El cumplimiento técnico de SDK o firma no acredita aprobación legal ni de Google.

## Revisión para el titular

[PR #41 de release](https://github.com/Anthony8724/Cercly/pull/41) y [PR #15 web](https://github.com/Anthony8724/cercly-web/pull/15): abiertos, fusionables y en borrador al cierre. El PR #40 permanece fusionado. El código del AAB se conserva sin cambios después de c14e42d; las actualizaciones posteriores contienen documentación y evidencias. La copia en Descargas incluye el inventario y SHA256SUMS verificados.
