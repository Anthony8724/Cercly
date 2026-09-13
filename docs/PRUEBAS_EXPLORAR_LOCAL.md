# Probar Explorar y Mapa con Supabase local

El estado seguro de los establecimientos OSM es `pendiente` y
`publicable = false`. La habilitación descrita aquí es temporal y funciona
solamente sobre el contenedor local de Supabase.

## Preparar los datos

Desde la raíz del proyecto, ejecutar:

```powershell
supabase db reset
powershell.exe -ExecutionPolicy Bypass -File .\scripts\cargar_osm_staging_local.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\promover_osm_establecimientos_local.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\habilitar_osm_pruebas_local.ps1
```

## Configurar Flutter

Crear `config/supabase.local.json` sin subirlo al repositorio:

```json
{
  "SUPABASE_URL": "http://10.0.2.2:54321",
  "SUPABASE_PUBLISHABLE_KEY": "CLAVE_ANON_LOCAL_DE_SUPABASE_STATUS"
}
```

La clave local se obtiene con `supabase status`. No debe utilizarse una clave
`service_role` dentro de Flutter.

## Simular la ubicación de Tulcán

1. Abrir el emulador Android.
2. Abrir **Extended controls** con el botón de tres puntos.
3. Entrar en **Location**.
4. Escribir latitud `0.8116` y longitud `-77.7172`.
5. Presionar **Set location**.

## Ejecutar la aplicación

```powershell
flutter run -d emulator-5554 `
  --dart-define-from-file=./config/supabase.local.json
```

Validar que Explorar muestre distancias coherentes, que radio/categoría/
subcategoría actualicen los resultados, que Mapa muestre los mismos negocios,
que el detalle abra y que **Cómo llegar** intente abrir una app compatible.

## Restaurar el estado seguro

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File .\scripts\habilitar_osm_pruebas_local.ps1 `
  -Restaurar
```

También puede ejecutarse `supabase db reset`, que elimina toda habilitación
temporal y reconstruye el estado canónico desde las migraciones.
