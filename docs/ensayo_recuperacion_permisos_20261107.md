# Ensayo local del respaldo existente — 7 de noviembre de 2026

Intento: `20261107T173236Z-80c424ec`.

Se utilizó exclusivamente el respaldo cifrado existente de STAGING
(`dlajxviqhkdcqnmczhvr`), sin conexiones a Supabase ni nuevas exportaciones.
La instancia PostgreSQL 17.11 fue nueva y su aislamiento `network=none`
se comprobó antes de restaurar. No se aplicaron migraciones.

## Resultado

`pg_restore` terminó con código 0 y completó su transacción. El verificador
posterior terminó con código 1: 18 controles aprobados y uno fallido.

- Atributos de roles y grafo completo de membresías: coincidencia con el
  inventario original antes de recuperar las ACL. Se conservaron las
  membresías internas de PostgreSQL.
- Recuperación de las ocho concesiones USAGE archivadas de `graphql` y
  `graphql_public`: comprobación exacta aprobada, incluidos destinatarios,
  grantor `supabase_admin` y WITH GRANT OPTION de `postgres`.
- Catálogo de esquemas: equivalencia de nombres, propietarios y ACL aprobada,
  sin concesiones adicionales en esos esquemas.
- Catálogo de extensiones: coincidencia aprobada.
- Catálogo de relaciones: **diferente del inventario original**. Se detuvo el
  ensayo inmediatamente; no se ha determinado aún el atributo concreto que
  difiere ni se ha descartado una diferencia real de seguridad.

Etapa: `catalog_verification`.
Categoría: `CATALOG_MISMATCH_RELATIONS`.
El fallo procede de una comparación, no de una instrucción SQL fallida;
no existe SQLSTATE asociado a este fallo.

Los controles posteriores de datos, funciones, triggers, RLS, otros permisos,
secuencias y migraciones no se ejecutaron. La importación de los objetos no
equivale a su verificación. Las 24 migraciones comprobadas en ensayos previos
no se presentan como una comprobación completada en este intento.

## Evidencia y protección

Directorio privado, fuera de Git:
`/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107/`.

- `restore-attempt-20261107T173236Z-80c424ec.json`: informe y ledger de controles.
- `restore-diagnostic-20261107T173236Z-80c424ec-schemas.gpg`: comparación cifrada
  de esquemas y contexto de roles.
- `restore-diagnostic-20261107T173236Z-80c424ec.gpg`: diferencia cifrada del
  catálogo de relaciones, sin publicar su contenido.

Para este resultado deben usarse los controles del ledger del intento.
Los indicadores resumidos heredados de informes anteriores no sustituyen
esos controles: la ruta de error del script recarga el informe previo.

El respaldo original conserva su SHA-256:
`f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297`.
Archivo 0600 y directorio 0700. Al terminar se comprobó que no quedaban
temporales descifrados del ensayo, socket del agente ni contenedores de
restauración activos.

## Pendientes y veredicto

La evidencia local examinada previamente no registra el propietario original,
ACL ni configuración de la base: no aparecen en el inventario ni en entradas
DATABASE del TOC. El propietario local elegido para el ensayo no demuestra
el propietario original. Este pendiente afecta la evaluación del contexto de
`pg_database_owner` y no se marca como aprobado.

Siguiente paso propuesto: inspeccionar exclusivamente la diferencia cifrada
del catálogo de relaciones mediante diálogo privado, identificar el atributo
concreto y validar cualquier corrección con datos sintéticos antes de otro
ensayo real. No repetir la exportación ni consultar proyectos remotos.

**NO-GO para despliegue de migraciones.** La recuperación de ACL y membresías
está demostrada; la recuperabilidad integral del respaldo sigue sin quedar
demostrada. Storage binario, configuraciones externas, contraseñas de roles
y dependencias de claves de plataforma continúan fuera de esta validación.
