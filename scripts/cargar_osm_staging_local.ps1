$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $repositoryRoot "supabase\seed\importacion_osm_tulcan.csv"
$sqlPath = Join-Path $repositoryRoot "supabase\importacion_osm_tulcan\cargar_staging.sql"
$containerWorkdir = "/tmp/cercly-osm-import"

if (-not (Test-Path $csvPath)) {
    throw "No se encontro el CSV: $csvPath"
}

if (-not (Test-Path $sqlPath)) {
    throw "No se encontro el importador SQL: $sqlPath"
}

$databaseContainer = docker ps --format "{{.Names}}" |
    Where-Object { $_ -like "supabase_db_*" } |
    Select-Object -First 1

if (-not $databaseContainer) {
    throw "No se encontro el contenedor local de PostgreSQL de Supabase. Ejecuta npx.cmd supabase start."
}

try {
    docker exec $databaseContainer mkdir -p `
        "$containerWorkdir/supabase/seed" `
        "$containerWorkdir/supabase/importacion_osm_tulcan"

    docker cp $csvPath `
        "${databaseContainer}:$containerWorkdir/supabase/seed/importacion_osm_tulcan.csv"
    docker cp $sqlPath `
        "${databaseContainer}:$containerWorkdir/supabase/importacion_osm_tulcan/cargar_staging.sql"

    docker exec -w $containerWorkdir $databaseContainer `
        psql -v ON_ERROR_STOP=1 -U postgres -d postgres `
        -f "supabase/importacion_osm_tulcan/cargar_staging.sql"

    if ($LASTEXITCODE -ne 0) {
        throw "La carga staging fallo con codigo $LASTEXITCODE"
    }
}
finally {
    docker exec $databaseContainer rm -rf $containerWorkdir 2>$null
}
