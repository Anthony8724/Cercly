#!/usr/bin/env python3
"""Prueba la propuesta de correcciones en un contenedor NUEVO, sin red.
No acepta URLs, no descarga imágenes, no toca bases existentes ni remotas.
Reconstruye el esquema versionado; Auth/Storage usan el bootstrap mínimo local.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import uuid
from correcciones_concurrencia_local import verificar_concurrencia

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'


def main():
    name = 'cercly-correcciones-' + uuid.uuid4().hex[:12]
    logs = Path(tempfile.mkdtemp(prefix='cercly-correcciones-'))
    env = {k: v for k, v in os.environ.items()
           if k not in ('CONTAINER_HOST', 'CONTAINER_CONNECTION', 'DOCKER_HOST')}
    def run(args, data=None):
        return subprocess.run(['podman', '--remote=false', *args], input=data,
                              capture_output=True, env=env, timeout=120)
    def sql(path, user='postgres'):
        result = run(['exec', '-i', name, 'psql', '-X', '-At', '-U', user,
                      '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], path.read_bytes())
        output = (result.stdout + result.stderr).decode()
        (logs / (path.stem + '.log')).write_text(output)
        if result.returncode:
            raise RuntimeError(f'{path.name}: error; consultar {logs}')
        return output
    started = False
    print(f'Evidencias SQL: {logs}', flush=True)
    try:
        result = run(['run', '-d', '--rm', '--pull=never', '--name', name,
                      '--network', 'none', '-e', 'POSTGRES_PASSWORD=local-test-only', IMAGE])
        if result.returncode:
            raise RuntimeError(result.stderr.decode())
        started = True
        for _ in range(60):
            if run(['exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres']).returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('PostgreSQL local no inició')
        sql(ROOT / 'scripts/sql/security_platform_bootstrap.sql', 'supabase_admin')
        for path in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
            sql(path)
        for path in [ROOT / 'supabase/tests/correcciones_aplicadas_test.sql',
                     ROOT / 'supabase/tests/correcciones_casos_adicionales_test.sql',
                     ROOT / 'supabase/tests/registro_nuevo_establecimiento_test.sql',
                     ROOT / 'supabase/tests/reclamar_establecimiento_osm_test.sql']:
            output = sql(path)
            plans = re.findall(r'^1\.\.(\d+)$', output, re.M)
            passed = re.findall(r'^ok \d+', output, re.M)
            if len(plans) != 1 or len(passed) != int(plans[0]) or re.search(r'^not ok|^Bail out!', output, re.M):
                raise RuntimeError(f'{path.name}: prueba fallida; consultar {logs}')
            print(f'{path.name}: {len(passed)}/{plans[0]} PASS', flush=True)
        verificar_concurrencia(lambda query: run(['exec','-i',name,'psql','-X','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],query.encode()))
    finally:
        if started:
            result = run(['stop', '--time', '2', name])
            if result.returncode:
                raise RuntimeError(f'No se pudo detener el contenedor local {name}')

if __name__ == '__main__':
    main()
