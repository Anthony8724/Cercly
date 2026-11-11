# Diagnóstico exacto de relaciones — 7 de noviembre de 2026

Se examinó offline el diagnóstico cifrado del intento
`20261107T173236Z-80c424ec`, y el TOC y DDL del respaldo original. No se
repitió la restauración real ni se consultó ningún proyecto Supabase.

## Diferencias comprobadas

Ambos catálogos contienen 73 relaciones. Coinciden 66; difieren 7. No hay
objetos faltantes ni adicionales. El único atributo distinto de estas siete
relaciones es `owner`: todos quedaron a nombre del administrador temporal
`cercly_restore_operator_7362510a`.

| Relación | Tipo | Propietario original | Extensión |
| --- | --- | --- | --- |
| extensions.geography_columns | Vista | supabase_admin | postgis |
| extensions.geometry_columns | Vista | supabase_admin | postgis |
| extensions.spatial_ref_sys | Tabla | supabase_admin | postgis |
| extensions.pg_stat_statements | Vista | postgres | pg_stat_statements |
| extensions.pg_stat_statements_info | Vista | postgres | pg_stat_statements |
| vault.decrypted_secrets | Vista | supabase_admin | supabase_vault |
| vault.secrets | Tabla | supabase_admin | supabase_vault |

Clasificación: propietario diferente y objeto gestionado por extensión de
PostgreSQL/Supabase. No es una diferencia de representación.

Los atributos `schema`, `name`, `relkind`, `relrowsecurity` y
`relforcerowsecurity` coinciden; ambos indicadores RLS son false en estas
siete relaciones. El inventario original no registra políticas ni triggers
de usuario asociados a ellas. Sí registra ACL explícitas: 17 entradas por
objeto de PostGIS/pg_stat_statements y 14 por objeto de Vault.

El diagnóstico cifrado del error contiene solo las listas de relaciones;
no incluye las ACL ni las políticas del destino. Por eso NO se afirma que
los privilegios del destino coincidan con los originales. Esa comprobación
debe ejecutarse después de restaurar los propietarios. Tampoco se infiere
igualdad de definiciones de vistas a partir de estos seis atributos.

## Causa

El dump contiene CREATE EXTENSION de `postgis`, `pg_stat_statements` y
`supabase_vault`, sin propietario de extensión en el TOC. No contiene
definiciones individuales ni ALTER OWNER de las siete relaciones. Las
entradas TABLE DATA de `spatial_ref_sys` y `vault.secrets` no reconstruyen
la propiedad de sus tablas.

Al ejecutarse pg_restore con el administrador temporal, los scripts de
extensión crean estos objetos a nombre de ese administrador. Se reprodujo
exactamente el patrón de cinco propietarios originales supabase_admin y dos
postgres en una prueba sintética, con las mismas extensiones de la imagen
PostgreSQL 17.11 instalada.

El procedimiento dependía exclusivamente del dump nativo para la propiedad
de los miembros de extensiones. El inventario archivado sí contiene los
propietarios originales de las relaciones y permite reconstruirlos. El
comparador detectó correctamente una diferencia real.

Documentación primaria:

- [Objetos miembros de extensiones y pg_dump](https://www.postgresql.org/docs/17/extend-extensions.html).
- [CREATE EXTENSION y propiedad de los objetos](https://www.postgresql.org/docs/17/sql-createextension.html).

## Riesgo

La propiedad determina quién puede administrar un objeto y puede afectar
los controles de acceso de vistas. Un administrador temporal superusuario
no equivale al propietario original; no debe ignorarse la discrepancia.
Vault requiere especial cautela. No se consultó contenido de secretos ni
datos personales para este diagnóstico.

## Corrección local preparada

`scripts/recuperar_propietarios_relaciones_local.py` genera una transacción
limitada a los siete objetos revisados, utilizando exclusivamente los
propietarios del inventario original. Exige:

- Identidades, tipos y RLS sin diferencias adicionales.
- Propietario actual igual al administrador temporal de ese destino.
- Propietario archivado postgres o supabase_admin.
- Catálogos de extensiones iguales, incluidas versiones y esquemas.
- Membresía real del objeto en la extensión esperada, comprobada en el
  destino mediante pg_depend.

Rechaza cambios fuera del alcance, propietarios inesperados, objetos
faltantes/adicionales, duplicados y diferencias de RLS. No usa REASSIGN OWNED,
no modifica tablas del sistema y no emite GRANT ni REVOKE.

El procedimiento de restauración incorpora el flag opcional
`--recuperar-propietarios-archivados`, desactivado por defecto. Después de
aplicar el plan exige igualdad estricta del catálogo completo de relaciones,
ACL de relaciones, ACL de columnas y políticas. ALTER OWNER puede cambiar
referencias en ACL: no se presume equivalencia ni se corrigen concesiones
desconocidas para obtener un aprobado.

También se mejoró el diagnóstico cifrado de futuras diferencias de
relaciones para conservar ACL y políticas de ambos lados. Se corrigió la
persistencia del informe en la ruta de error: conserva los indicadores del
intento actual, sin recargar indicadores antiguos.

Estos cambios no se han ejecutado sobre una restauración real en esta tarea.

## Pruebas

`python3 scripts/test_propietarios_relaciones_local.py`: **30 aprobadas,
0 fallidas**, exclusivamente sintéticas, en contenedor nuevo `network=none`.

Se verificaron reproducción exacta de los siete propietarios distintos,
recuperación de propietarios y ACL, políticas, conservación de membresías,
datos de prueba, visibilidad RLS, operaciones no autorizadas denegadas,
rechazo de diferencias inesperadas, detección de un privilegio adicional,
idempotencia y rollback total ante error dentro de la transacción.

Evidencia saneada persistida:

- `docs/evidencia_relaciones_restauracion_20261107.json`.
- `docs/evidencia_prueba_propietarios_sintetica_20261107.json`.

Informe original sintético:
`/tmp/cercly-relation-owner-test-7wdcl6z5/result.json`.

Sintaxis Python comprobada y git diff --check correcto. No se modificaron
Flutter, geofencing, migraciones ni datos remotos. No hay commits ni push.

## Evidencia pendiente y siguiente ensayo

El inventario no contiene propietario, ACL ni configuración originales de
la base; el TOC tampoco incluye entradas DATABASE. No puede inferirse ese
propietario de los de sus esquemas, tablas o de la cuenta de conexión.
El inventario de extensiones registra nombre, versión y esquema, pero no
su propietario original: este contexto también queda explícitamente
pendiente. No se inventa un propietario para eludir el control.

Es razonable autorizar otro ensayo local con los flags de recuperación de
ACL y propietarios archivados para comprobar el resultado sobre el respaldo
real y continuar los controles de datos, funciones, triggers, RLS, secuencias
y 24 migraciones. Debe detenerse ante cualquier discrepancia nueva.

**GO únicamente para solicitar ese ensayo local; NO-GO para desplegar
migraciones.** La validación sintética no acredita recuperación completa del
respaldo real. Aun si pasan los controles archivados, faltará acreditar el
contexto original de base y extensiones y las limitaciones externas de
Storage/Auth/Vault ya documentadas.

El respaldo original conserva SHA-256
`f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297`.
El agente de cifrado de esta inspección fue cerrado; los temporales
descifrados fueron eliminados. No se ejecutó ninguna restauración real.
