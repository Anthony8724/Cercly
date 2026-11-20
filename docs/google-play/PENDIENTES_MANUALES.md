# Pendientes indispensables — RC2

La salida externa de rutas está implementada y probada; no hace falta resolver un contrato HeiGIT para mantener desactivado ese proveedor en RC2. La reactivación interna es un trabajo separado. No se fusionaron #41/#15 ni se publicó nada.

| Pendiente | Acción concreta | Evidencia necesaria |
|---|---|---|
| Corrección de eliminación | Revisar migración 20261119231916, autorizar prueba alojada y posteriormente despliegue separado | Solicitud/eliminación simple y casos con dependencias en Staging, sin usuarios reales |
| Supresión integral alojada | Reproducir el ensayo local aprobado de 43 checks en configuración alojada y probar canal externo/respaldos | Confirmación verificable de qué se borró/conservó; caso con negocio/historial requiere decisión específica |
| Publicar documentos | Autorizar primero push/Preview web y revisar PUBLICACION_WEB_LEGAL.md: #15 → compliance/play-readiness, después #6 → main | Segundo PR incluye más sitio; autorización de fusión/publicación separada y tres URL públicas completas |
| Decisiones del titular | Resolver DECISIONES_TITULAR.md | Retención por categoría, respaldo, atención, UGC, anuncios, público y términos aprobados |
| Respuestas de Console | Facilitar o revisar lo ya marcado y contrastar la tabla propuesta | No se accedió a respuestas reales ni se enviaron formularios |
| VersionCode/firma | Seguir INSTRUCCIONES_PLAY_CONSOLE.md | Máximo código <26 y certificado de carga coincidente; si no, nueva build con código superior |
| HONOR y capturas | Ejecutar HONOR_GUIA_CORTA_RC2.md y completar PASS/FAIL | Resultados reales/saneados, modelo/SO y APK/hash conservados |
| CGU | Aprobar términos y completar controles efectivos de aceptación, denuncia y bloqueo aplicables | Una decisión de público o un texto de política no sustituye implementación/pruebas |
| Cuenta/prueba cerrada | Confirmar tipo, fecha y requisitos de la cuenta; autorizar track | PLAN_12_TESTERS_14_DIAS.md ejecutado si aplica; no hay participantes/continuidad acreditados |
| Revisión y envío | Revisar #41 y autorizar carga/envío por separado después de cerrar bloqueos | No publicar ni enviar la candidata actual como aprobada |

No se requiere un nuevo proyecto ni sustituir Supabase. No se compraron recursos ni se aceptaron contratos. Los artefactos +25 y la candidata +26 anterior quedan conservados.
