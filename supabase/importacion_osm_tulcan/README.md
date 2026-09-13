# Importación y promoción local de OSM de Tulcán

Este proceso carga el lote preparado de 306 objetos OSM únicamente en
`staging.importacion_establecimientos_osm`. No inserta registros en
`public.establecimientos` y no utiliza UUID fijos de categorías.

## Fuente

- Hoja del Excel: `Staging_preparado`
- Lote: `5979a1d9-2be4-42d5-a98f-4ce30c1d1b03`
- CSV derivado: `supabase/seed/importacion_osm_tulcan.csv`
- Resultado refinado: 254 válidos, 52 observados y 0 descartados
- Registros sin nombre: 50, todos observados

Las decisiones de refinamiento pueden reaplicarse de forma idempotente antes
de la carga:

```powershell
python .\scripts\refinar_taxonomia_osm.py
```

Los únicos registros con nombre que permanecen observados son `EMELNORTE` y
`Centro de Faenamiento de Tulcán`.

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

El segundo resultado debe ser `0` antes de ejecutar la promoción.

## Flujo completo

```text
Excel / CSV
  -> staging
  -> refinamiento taxonómico
  -> promoción de registros válidos
  -> revisión y aprobación posterior
```

La promoción no equivale a publicación. Los 254 establecimientos válidos se
crean con `estado = pendiente`, `publicable = false` y
`estado_reclamo = no_reclamado`. Los 52 observados permanecen únicamente en
staging.

## Promoción local de los 254 registros válidos

Después de cargar staging, ejecutar desde la raíz:

```powershell
.\scripts\promover_osm_establecimientos_local.ps1
npx.cmd supabase test db
```

El script detecta un único contenedor `supabase_db_*`, copia temporalmente el
SQL, lo ejecuta con `ON_ERROR_STOP` y siempre limpia el directorio temporal.
La función interna usa un bloqueo transaccional y la identidad
`osm_type + osm_id`, por lo que puede repetirse sin crear duplicados.

En una repetición solo se actualizan nombre, dirección, categoría,
coordenadas y territorio de establecimientos OSM que continúen sin reclamar.
Nunca se alteran establecimientos creados en Cercly ni datos administrativos
de establecimientos OSM reclamados. `datos_osm` se conserva desde la creación
y tampoco se reemplaza después de un reclamo.

La promoción puede comprobarse manualmente con:

```sql
select fuente, estado, publicable, count(*)
from public.establecimientos
where fuente = 'osm'
group by fuente, estado, publicable;
```

El resultado esperado es `osm | pendiente | false | 254`. La aprobación y
publicación se realizarán en una fase posterior y controlada.

## Consulta PostGIS desde Flutter

El servicio público usa `buscar_establecimientos_cercanos` para aplicar en
PostgreSQL el radio, categoría, subcategorías, promociones, límite,
desplazamiento y orden por distancia. Flutter carga después los detalles de
los IDs devueltos, sin descargar todos los establecimientos para calcular el
filtro principal en el dispositivo.

Flujo local completo:

```powershell
npx.cmd supabase start
npx.cmd supabase db reset
.\scripts\cargar_osm_staging_local.ps1
.\scripts\promover_osm_establecimientos_local.ps1
.\scripts\habilitar_osm_pruebas_local.ps1
npx.cmd supabase test db
```

Crear `config/supabase.local.json` localmente, sin subirlo al repositorio:

```json
{
  "SUPABASE_URL": "http://10.0.2.2:54321",
  "SUPABASE_PUBLISHABLE_KEY": "ANON_KEY_MOSTRADA_POR_SUPABASE_STATUS"
}
```

En Android Emulator, `10.0.2.2` apunta al equipo anfitrión. La aplicación usa
exclusivamente la clave pública/anon; nunca necesita `service_role`.

Ejecutar Flutter:

```powershell
flutter run --dart-define-from-file=config\supabase.local.json
```

Punto sugerido para probar Tulcán: latitud `0.8116`, longitud `-77.7172`.
La cantidad devuelta dependerá del radio, filtros, límite y paginación.

Para regresar sin reiniciar la base al estado seguro:

```powershell
.\scripts\habilitar_osm_pruebas_local.ps1 -Restaurar
```

También se puede ejecutar `npx.cmd supabase db reset`, que elimina la
habilitación temporal. Después del reset se deben repetir carga y promoción
si se desea reconstruir el escenario local.
