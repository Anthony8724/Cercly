# Continuación RC2: estado exacto para prueba cerrada

19/11/2026, hora Ecuador. **NO-GO para enviar a revisión/distribuir la prueba cerrada de Google Play.** No se subió AAB, fusionó PR, desplegó web/Production ni eliminó una cuenta real.

## Resuelto en esta continuación

| Control | Estado | Evidencia |
|---|---|---|
| Alcance de corrección SQL | APROBADO | Migración 20261119231916 sin cambios respecto a 40c1f2f; solo firma exacta de FK. Propietario/ACL/configuración y huella de datos preexistentes conservados |
| Eliminación HTTP real local | APROBADO | 43/43; GoTrue/PostgREST/Storage/handler y SDK reales, sin dobles; [detalle](ELIMINACION_HTTP_LOCAL.md) |
| Protección de datos ajenos | APROBADO | Identidad/perfil/negocio/promoción/relación de foto/cuota y bytes de foto ajenos iguales antes/después de los casos de borrado |
| Prueba de fotos | APROBADO | Foto existente bloquea; retirada explícita por API comprobada; revisión no se aprueba sola; aprobación administrativa sintética y borrado posterior |
| Sesiones/tokens locales | APROBADO | Sesiones/refresh desaparecen, Auth rechaza JWT antiguo y refresh no sirve; no se recrea cuota |
| Web legal local | APROBADO | 32 pruebas, build Webpack, lint/tipos, cinco rutas HTTPS 200; nueve vistas de las tres páginas, móvil 390/tablet 768/escritorio 1280, sin infracciones axe/errores/overflow; capturas móviles inspeccionadas |
| Respeto de aprobación parcial | APROBADO | PR #16 preservado; 90 días solo para soporte ordinario cerrado/incidencias resueltas. No se aplica ni anuncia para otras categorías |
| APK/AAB conservados | APROBADO | Hashes nuevamente comprobados; lib/android/lockfiles/handler/migración sin cambios. No se recompiló ni se atribuyó CI nuevo al código de QA |

Dos expectativas del arnés HTTP se corrigieron tras observar la respuesta real de GoTrue; historial y resultado final quedan documentados. No se modificó el servidor para superar una prueba. El stack nuevo fue detenido sin borrar volúmenes ni tocar otros contenedores.

## Bloqueos y pendientes

| Control | Estado | Lo que falta |
|---|---|---|
| Eliminación desplegada | BLOQUEADO | Nueva lectura Production confirma cuota no reconocida, bloqueo global y migración sin registrar. La corrección requiere despliegue autorizado; el APK no la aplica |
| Proceso alojado y canal externo | PENDIENTE | Configuración/versión alojada, gateway Edge y flujo correo/portal → titularidad → actuación → confirmación. No se acreditan backups ni borrado forense con Storage API |
| Política pública | BLOQUEADO | /privacidad 307 a portada, /terminos 404. /eliminar-cuenta 200 no demuestra operación integral. Commit web nuevo local sin push/Preview |
| Retención y texto legal final | PENDIENTE | Aprobar por categoría, implantar 90 días en soporte, inventariar backups/logs y decidir tratamiento de imágenes, derechos, cuentas compartidas e historiales |
| Controles CGU | BLOQUEADO | Aceptación previa de términos, denuncia de usuarios/contenido y bloqueo aplicable no acreditados. Hace falta implementación/pruebas además de aprobación legal |
| Declaraciones reales Play | PENDIENTE | No hay acceso a los valores guardados. Tabla de hechos/recomendaciones/decisiones en CONTRASTE_FORMULARIOS_RC2.md |
| Anuncios/pagos/público | PENDIENTE | Modelo comercial de destacadas, clasificación de referencias de pago, edades/IARC y comportamiento técnico de SDK en dispositivo |
| HONOR | PENDIENTE | Sin dispositivo conectado. [Guía corta y hoja PASS/FAIL](HONOR_GUIA_CORTA_RC2.md), sin resultados atribuidos al teléfono |
| Console / 26 / firma / 12×14 | PENDIENTE | Código usado, certificado de carga, cuenta y prueba cerrada sin evidencia nueva. Plan preparado, no iniciado |

## Código, ramas y límites de publicación

- `origin/develop`: 3ef19a820263c2add7db27a78d43570dd5f52cfd; sin cambios. PR #40 ya fusionado.
- Android: `release/play-store-0.1.9-26`, PR #41 en borrador. Nuevo commit de pruebas `188354cfe9a7251ac16311b5a5b47f9f867964ed`; cierre documental posterior en el mismo historial. Código del APK sigue siendo 40c1f2f.
- Web: `compliance/play-privacy-routes-20261119`, **HEAD local a7cb59b86ef98c0c6221bd663aebed6236701f08**. Remoto/PR #15 sigue en **1cd56445268f2afecfa793c73312a120f7afbf39**. No se hace push para evitar Preview no autorizada. Base `compliance/play-readiness` permanece deeb4d6 con PR #16 incluido.
- Publicación preparada: #15 hacia `compliance/play-readiness`, después #6 hacia `main`. #6 también cambia portada/soporte/navegación: no autorizarlo como si solo cambiara textos legales. [Procedimiento exacto](PUBLICACION_WEB_LEGAL.md). Ninguna integración ejecutada.
- APK `Cercly-Produccion-0.1.9+26-RC2.apk`: 812e72ead744d8144e029154be5cabe990c9c030e74d3805fef82a86c5b22f49. AAB: 36fb9c545aebda8e0ea254766b8b36407229b46b2054a9660eafd151234079f5. Directorio existente: /home/Anthony/Descargas/Cercly-Produccion-0.1.9+26-RC2-CANDIDATA-20261119/.

## Decisiones y autorizaciones separadas de los controles aprobados

1. **Backend alojado:** concretar entorno/cuentas sintéticas/permisos para reproducir el ensayo; Production requiere autorización expresa antes de aplicar la migración. No borrar cuentas reales como prueba.
2. **Políticas:** revisar [propuesta concreta](PROPUESTA_POLITICAS_TITULAR.md), aprobar reglas por categoría y definir responsables/procesos. No extender los 90 días ni declarar ejecución no verificada.
3. **Web:** autorizar push/Preview del commit a7cb59b, revisión y posterior integración/publicación por separado. Si solo se autorizan páginas legales, preparar un PR acotado desde main; no fusionar #6 completo.
4. **Producto/declaraciones:** confirmar destacadas/anuncios, pagos y público; aprobar términos y desarrollar controles CGU pendientes. [Contraste](CONTRASTE_FORMULARIOS_RC2.md). No enviar formularios automáticamente.
5. **HONOR/Play:** ejecutar guía y aportar evidencia; contrastar 26/firma y cuenta. Autorizar distribución de la prueba solo cuando se cierren los bloqueos. El plan 12/14 no está ejecutado.

Las exigencias de declaración también alcanzan pruebas cerradas: https://support.google.com/googleplay/android-developer/answer/10787469?hl=es. No se declara GO por tener un AAB válido o un ensayo local aprobado.
