# Recuperación: trabajo conservado al cerrar correcciones — 8 de noviembre

Este documento indexa el trabajo de respaldo/restauración que estaba local y
sin seguimiento. Se conserva en un commit independiente del cambio funcional
de solicitudes. Los 19 archivos previos de recuperación/documentación se
compararon con un inventario SHA-256 creado al retomar y no se alteraron.

## Informes y evidencia técnica saneada

- `diagnostico_restauracion_roles_local_20261107.md`.
- `diagnostico_esquemas_restauracion_20261107.md`.
- `acl_dump_recuperacion_20261107.md`.
- `ensayo_recuperacion_permisos_20261107.md`.
- `diagnostico_relaciones_restauracion_20261107.md`.
- `evidencia_relaciones_restauracion_20261107.json`.
- `evidencia_prueba_propietarios_sintetica_20261107.json`.
- `plan_actualizacion_production_20261107.md`: plan histórico previo a la rama
  compatible 0.1.7+10; no describe la última APK como si siguiera en preparación.

## Scripts conservados

- `cercly_backup_catalog.py`, `comparar_esquemas_respaldo.py`.
- `diagnosticar_roles_restauracion_local.py`.
- `diagnosticar_relaciones_respaldo_local.py`, `inspeccionar_acl_dump_local.py`.
- `recuperar_acl_esquemas_local.py`, `recuperar_propietarios_relaciones_local.py`.
- `restaurar_respaldo_staging_local.py`.
- `test_comparador_esquemas_local.py`, `test_recuperacion_acl_local.py`,
  `test_propietarios_relaciones_local.py`.

Los informes originales distinguen datos observados de hipótesis y resultados
sintéticos de restauración real. No se incluye el respaldo, sus catálogos con
datos, credenciales, frases de cifrado ni diagnósticos descifrados en Git.

## Estado pendiente, sin reinterpretar resultados

El último ensayo real de recuperación terminó en una diferencia de propietarios
de siete relaciones de extensiones. El dump se importó correctamente, y las
ACL de esquemas y membresías se verificaron; no se completaron los controles
posteriores de datos, funciones, triggers, RLS, otras ACL y secuencias.

El plan limitado de recuperación de esos propietarios tiene 30 pruebas
sintéticas aprobadas según la evidencia conservada. No se repitió el ensayo
real ni esas pruebas sintéticas durante el cierre de correcciones del día 8.
La sintaxis Python fue comprobada al revisar los archivos.

Faltan metadatos fiables de propiedad/ACL/configuración originales de la base
y propietarios de extensiones. No se infieren ni se eliminan verificaciones.
Un nuevo ensayo real requiere autorización específica y diálogo privado para
la frase; los agentes privados de cifrado no se ejecutaron en esta tarea.

**NO-GO para desplegar migraciones por este trabajo de recuperación.**
El GO local de las correcciones estructuradas no cambia ese bloqueo.

La APK privada 0.1.7+10 conserva SHA-256
`80e5b059f7311bd690f2dac0e696acb34759f92d08558a37663dba7df0bf3dee`
y la rama compatible conserva `94c31054644ef2ee05d604eda17b890057b4331c`.
No se hizo push, merge, exportación, migración remota ni una APK nueva.
