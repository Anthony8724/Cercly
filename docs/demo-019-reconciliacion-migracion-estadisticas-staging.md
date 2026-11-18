# Reconciliación de la migración de estadísticas en Staging

Fecha de observación: 2026-11-16. Proyecto: `dlajxviqhkdcqnmczhvr`.

## Estado observado (solo lectura)

- `origin/develop` incluye el merge del PR #35 (`32c1088b4fda685e6b6666c0cf7d470870587653`) y la migración `20261115120000_estadisticas_administrador_lectura.sql`.
- El historial remoto de Supabase Staging no contiene la versión `20261115120000`.
- Las funciones `public.admin_estadisticas_resumen(integer)` y
  `public.admin_estadisticas_registros(date,date,text)` sí existen. Sus
  definiciones observadas corresponden al SQL de la migración: agregan conteos,
  validan `public.es_administrador()`, y limitan rangos/parámetros.
- Ambas funciones son `SECURITY DEFINER`; `anon` no tiene `EXECUTE`,
  `authenticated` sí y `service_role` no. El cuerpo vuelve a comprobar el rol
  administrador. La pantalla de estadísticas se abrió en la app Staging y
  devolvió valores, por lo que el flujo funcional se probó en modo lectura.
- Los logs de PostgreSQL del 2026-11-15 a las 19:45:39Z y 19:45:54Z registran
  el bloque SQL de la migración con `source: dashboard`, incluido `BEGIN` y
  `COMMIT`. La explicación respaldada por logs es que el SQL se ejecutó desde
  el Dashboard y no mediante el ejecutor de migraciones; esa ejecución no
  insertó la versión en `supabase_migrations.schema_migrations`.

No se guardan aquí identificadores de sesión, datos de usuarios ni contenido
de autenticación. Los catálogos no permiten atribuir la acción a una persona.

## Reconciliación segura propuesta

1. Mantener la migración fusionada y el historial remoto sin cambios mientras
   no exista autorización expresa para modificar metadatos de Staging.
2. Antes de reconciliar, comparar en solo lectura la firma, definición,
   propietario y ACL de ambas funciones con el archivo fusionado; comprobar
   además que la versión siga ausente y que no haya una versión posterior que
   cambie esos objetos.
3. Obtener respaldo de Staging y aprobación explícita del responsable del
   proyecto para registrar la versión como aplicada mediante la operación
   oficial de reparación de historial (`supabase migration repair --status
   applied 20261115120000`). No volver a ejecutar el DDL si la comparación
   confirma que los objetos ya coinciden.
4. Verificar después, con consultas de solo lectura, que la versión aparece una
   sola vez, las definiciones/ACL siguen iguales y la pantalla conserva sus
   resultados. Si hay cualquier divergencia, detenerse y preparar una
   migración correctiva nueva en vez de marcarla aplicada.

Este procedimiento es una propuesta. En esta fase no se ejecutó `migration
repair`, SQL remoto ni cambios de datos/esquema.
