# Consolidación local de Cercly

Base: develop 9aa7f7b8. No se cambia main, develop, servicios remotos ni migraciones.
PR #38 (mapa/rutas), #35 (estadísticas) y #37 (Sky/promociones/FCM/geofencing)
ya están integrados; no se vuelven a fusionar.

## Cambios preparados

- Preflight: incluir config y plantillas Auth declaradas; rechazar archivos
  ausentes, rutas externas y config enlazada; preservar alias internos.
  Este script conserva su manifiesto histórico de 26 migraciones: debe denegar
  el árbol actual ampliado. No es una autorización ni una preparación vigente
  para desplegar Staging. Actualizar su manifiesto exige revisión independiente.
- Pruebas SQL: rechazar orden inverso y verificar rollback de catálogo;
  conservar suites FCM actuales y usar entorno local con variables permitidas.
- Geofencing de producción: deshabilitado incluso con la antigua bandera privada,
  con rechazo explícito de Gradle. Staging conserva su implementación.
- Notificaciones: consumir también identificadores de texto al arrancar en frío,
  coherentemente con la ruta existente de apertura en caliente.
- Texto de privacidad: quitar promesas de aviso/plazos no validados.

## Validación y límites

Flutter analyze sin incidencias. Suite general: 444 aprobadas y 12 omitidas.
Staging: 18 aprobadas, incluida navegación fría/caliente con Supabase/FCM
simulados. Producción: 6 pruebas de cierre de banderas aprobadas.
Preflight: 6 pruebas; manifiesto histórico denegado antes de crear destino.
SQL aislado, sin red: 251 aserciones focales y 787 de seguridad, además de
concurrencia y reaplicación. No se modificó la base remota.
Gradle rechazó la antigua activación privada; no se construyó APK.

No se acredita entrega FCM real, geofencing Android real, permisos de segundo
plano, compatibilidad con el estado remoto de Staging ni operación en producción.
Requieren dispositivos y un entorno autorizado. FCM permanece bloqueado en
producción por las protecciones existentes; ninguna bandera lo habilita.

## Trabajo original preservado

Los cambios originales y los documentos de diagnóstico permanecen intactos.
No copiar íntegramente harness antiguos: algunos omiten migraciones recientes,
límites de host o comprobaciones FCM. La propuesta antigua de privacidad queda
como antecedente; no se añade otra migración sobre implementaciones posteriores.
Los exportadores/restauradores y evidencias operativas se mantienen privados,
pendientes de revisión específica, sin ejecutarlos sobre servicios remotos.

Revisar estos cambios mediante PR contra develop antes de incorporarlos.
