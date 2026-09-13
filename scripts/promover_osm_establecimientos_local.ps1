$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sqlPath = Join-Path $repositoryRoot `
    "supabase\importacion_osm_tulcan\promover_establecimientos.sql"
$containerWorkdir = "/tmp/cercly-osm-promocion"

if (-not (Test-Path $sqlPath)) {
    throw "No se encontro el SQL de promocion: $sqlPath"
}

$databaseContainers = @(
    docker ps --format "{{.Names}}" |
        Where-Object { $_ -like "supabase_db_*" }
)

if ($databaseContainers.Count -eq 0) {
    throw "No se encontro PostgreSQL local de Supabase. Ejecuta npx.cmd supabase start."
}

if ($databaseContainers.Count -gt 1) {
    throw "Se encontraron varios contenedores supabase_db_*. Deja activo solo el de Cercly."
}

$databaseContainer = $databaseContainers[0]

try {
    docker exec $databaseContainer mkdir -p `
        "$containerWorkdir/supabase/importacion_osm_tulcan"

    docker cp $sqlPath `
        "${databaseContainer}:$containerWorkdir/supabase/importacion_osm_tulcan/promover_establecimientos.sql"

    docker exec -w $containerWorkdir $databaseContainer `
        psql -v ON_ERROR_STOP=1 -U postgres -d postgres `
        -f "supabase/importacion_osm_tulcan/promover_establecimientos.sql"

    if ($LASTEXITCODE -ne 0) {
        throw "La promocion OSM fallo con codigo $LASTEXITCODE"
    }
}
finally {
    docker exec $databaseContainer rm -rf $containerWorkdir 2>$null
}
