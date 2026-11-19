# Pendientes indispensables — RC2

La salida externa de rutas está implementada y probada; no hace falta resolver un contrato HeiGIT para mantener desactivado ese proveedor en RC2. La reactivación interna es un trabajo separado. No se fusionaron #41/#15 ni se publicó nada.

| Pendiente | Acción concreta | Evidencia necesaria |
|---|---|---|
| Corrección de eliminación | Revisar migración 20261119231916, autorizar prueba alojada y posteriormente despliegue separado | Solicitud/eliminación simple y casos con dependencias en Staging, sin usuarios reales |
| Supresión integral | Probar Auth/Postgres/Storage/sesiones y canal externo con fixtures designados | Confirmación verificable de qué se borró/conservó; no basta UI o SQL local |
| Publicar documentos | Revisar PR #15 y autorizar integración/despliegue web | /privacidad completo y estable, /eliminar-cuenta y /terminos públicos accesibles |
| Decisiones del titular | Resolver DECISIONES_TITULAR.md | Retención por categoría, respaldo, atención, UGC, anuncios, público y términos aprobados |
| Respuestas de Console | Facilitar o revisar lo ya marcado y contrastar la tabla propuesta | No se accedió a respuestas reales ni se enviaron formularios |
| VersionCode/firma | Seguir INSTRUCCIONES_PLAY_CONSOLE.md | Máximo código <26 y certificado de carga coincidente; si no, nueva build con código superior |
| HONOR y capturas | Ejecutar QA_HONOR_RC2.md en dispositivo autorizado | Resultados reales/saneados, Android 15/16 y APK/hash final |
| Cuenta/prueba cerrada | Confirmar tipo, fecha y requisitos de la cuenta; autorizar track | PLAN_12_TESTERS_14_DIAS.md ejecutado si aplica; no hay participantes/continuidad acreditados |
| Revisión y envío | Revisar #41 y autorizar carga/envío por separado después de cerrar bloqueos | No publicar ni enviar la candidata actual como aprobada |

No se requiere un nuevo proyecto ni sustituir Supabase. No se compraron recursos ni se aceptaron contratos. Los artefactos +25 y la candidata +26 anterior quedan conservados.
