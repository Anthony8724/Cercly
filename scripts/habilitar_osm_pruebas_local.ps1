param(
    [switch]$Restaurar
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sqlPath = Join-Path $repositoryRoot `
    "supabase\importacion_osm_tulcan\habilitar_osm_pruebas_local.sql"
$containerWorkdir = "/tmp/cercly-osm-pruebas"
$habilitar = if ($Restaurar) { "false" } else { "true" }

if (-not (Test-Path $sqlPath)) {
    throw "No se encontro el SQL local: $sqlPath"
}

$databaseContainers = @(
    docker ps --format "{{.Names}}" |
        Where-Object { $_ -like "supabase_db_*" }
)

if ($databaseContainers.Count -eq 0) {
    throw "No se encontro Supabase local. Ejecuta npx.cmd supabase start."
}

if ($databaseContainers.Count -gt 1) {
    throw "Hay varios contenedores supabase_db_*. Deja activo solo el de Cercly."
}

$databaseContainer = $databaseContainers[0]

try {
    docker exec $databaseContainer mkdir -p `
        "$containerWorkdir/supabase/importacion_osm_tulcan"

    docker cp $sqlPath `
        "${databaseContainer}:$containerWorkdir/supabase/importacion_osm_tulcan/habilitar_osm_pruebas_local.sql"

    docker exec -w $containerWorkdir $databaseContainer `
        psql -v ON_ERROR_STOP=1 -v "habilitar=$habilitar" `
        -U postgres -d postgres `
        -f "supabase/importacion_osm_tulcan/habilitar_osm_pruebas_local.sql"

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo configurar el modo local de pruebas"
    }
}
finally {
    docker exec $databaseContainer rm -rf $containerWorkdir 2>$null
}
