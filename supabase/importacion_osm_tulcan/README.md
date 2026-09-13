# Importación OSM de Tulcán a staging local

Este proceso carga el lote preparado de 306 objetos OSM únicamente en
`staging.importacion_establecimientos_osm`. No inserta registros en
`public.establecimientos` y no utiliza UUID fijos de categorías.

## Fuente

- Hoja del Excel: `Staging_preparado`
- Lote: `5979a1d9-2be4-42d5-a98f-4ce30c1d1b03`
- CSV derivado: `supabase/seed/importacion_osm_tulcan.csv`
- Resultado esperado: 222 válidos, 84 observados y 0 descartados
- Registros sin nombre: 50, todos observados

## Ejecución local

Desde la raíz del repositorio:

```powershell
npx.cmd supabase start
npx.cmd supabase db reset
.\scripts\cargar_osm_staging_local.ps1
npx.cmd supabase test db
```

El script detecta el contenedor `supabase_db_*`, copia temporalmente el CSV y
el SQL, ejecuta la carga con `ON_ERROR_STOP` y elimina esos archivos temporales.
El nombre del contenedor puede consultarse con:

```powershell
docker ps --format "{{.Names}}"
```

También puede ejecutarse directamente con `psql` local, siempre desde la raíz
del repositorio para que la ruta relativa del CSV sea válida:

```powershell
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" `
  -f .\supabase\importacion_osm_tulcan\cargar_staging.sql
```

## Seguridad e idempotencia

Antes del `UPSERT`, el script valida cantidad, identidad OSM, coordenadas,
estados, categorías, subcategorías y los 50 registros sin nombre. Cualquier
error detiene y revierte la transacción. La clave
`(lote_id, osm_type, osm_id)` permite repetir la carga sin duplicar filas.

Los UUID de destino se resuelven mediante los slugs del CSV contra
`public.categorias` y `public.subcategorias`. La subcategoría, cuando existe,
debe estar activa y pertenecer a la categoría indicada.

## Verificación manual

```sql
select estado_importacion, count(*)
from staging.importacion_establecimientos_osm
where lote_id = '5979a1d9-2be4-42d5-a98f-4ce30c1d1b03'
group by estado_importacion;

select count(*)
from public.establecimientos
where fuente = 'osm';
```

El segundo resultado debe ser `0` en esta fase.
