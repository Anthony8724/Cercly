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
from correcciones_concurrencia_local import verificar_concurrencia, verificar_concurrencia_moderacion
from fcm_concurrencia_local import verificar_concurrencia_fcm
from cercly_backup_catalog import QUERIES, wrapped
from sql_local_session import clean_environment

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'


def main():
    name = 'cercly-correcciones-' + uuid.uuid4().hex[:12]
    logs = Path(tempfile.mkdtemp(prefix='cercly-correcciones-'))
    env = clean_environment()
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
    def catalog_fingerprint():
        query="begin read only; set local search_path=pg_catalog; select md5(concat_ws('|',"+','.join('('+wrapped(QUERIES[key]).rstrip(';')+')::text' for key in ('relations','columns','policies','functions','triggers','relation_acl','column_acl','roles','memberships'))+")); commit;"
        result=run(['exec','-i',name,'psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],query.encode())
        if result.returncode:raise RuntimeError('No se obtuvo la huella de catálogo de la fixture')
        return result.stdout.strip()
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
            if path.name=='20261106034310_aplicar_correcciones_estructuradas.sql':
                before=catalog_fingerprint()
                second=ROOT/'supabase/migrations/20261107121537_cerrar_actualizacion_administrativa_directa.sql'
                result=run(['exec','-i',name,'psql','-X','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],second.read_bytes())
                (logs/'dependency-order.log').write_bytes(result.stdout+result.stderr)
                if result.returncode==0 or b'42883' not in result.stderr or before!=catalog_fingerprint():
                    raise RuntimeError('La segunda migración no rechazó la dependencia o dejó cambios parciales')
                print('Orden inverso rechazado y rollback de catálogo completo: PASS',flush=True)
            if path.name=='20261107121537_cerrar_actualizacion_administrativa_directa.sql':
                before=catalog_fingerprint()
                third=ROOT/'supabase/migrations/20261108165118_compatibilidad_moderacion_y_privacidad.sql'
                result=run(['exec','-i',name,'psql','-X','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],third.read_bytes())
                (logs/'moderation-dependency-order.log').write_bytes(result.stdout+result.stderr)
                if result.returncode==0 or b'42883' not in result.stderr or before!=catalog_fingerprint():
                    raise RuntimeError('La tercera migración no rechazó la dependencia o dejó cambios parciales')
                print('Moderación sin segunda migración rechazada y catálogo intacto: PASS',flush=True)
            sql(path)
        for path in [ROOT / 'supabase/tests/correcciones_aplicadas_test.sql',
                     ROOT / 'supabase/tests/correcciones_casos_adicionales_test.sql',
                     ROOT / 'supabase/tests/correcciones_compat_cliente_test.sql',
                     ROOT / 'supabase/tests/moderacion_privacidad_test.sql',
                     ROOT / 'supabase/tests/registro_nuevo_establecimiento_test.sql',
                     ROOT / 'supabase/tests/reclamar_establecimiento_osm_test.sql',
                     ROOT / 'supabase/tests/fcm_promotions_rules_test.sql',
                     ROOT / 'supabase/tests/fcm_promotions_security_test.sql',
                     ROOT / 'supabase/tests/geofencing_shared_test.sql']:
            output = sql(path)
            plans = re.findall(r'^1\.\.(\d+)$', output, re.M)
            passed = re.findall(r'^ok \d+', output, re.M)
            if len(plans) != 1 or len(passed) != int(plans[0]) or re.search(r'^not ok|^Bail out!', output, re.M):
                raise RuntimeError(f'{path.name}: prueba fallida; consultar {logs}')
            print(f'{path.name}: {len(passed)}/{plans[0]} PASS', flush=True)
        verificar_concurrencia(lambda query: run(['exec','-i',name,'psql','-X','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],query.encode()))
        verificar_concurrencia_moderacion(lambda query: run(['exec','-i',name,'psql','-X','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],query.encode()))
        verificar_concurrencia_fcm(lambda query: run(['exec','-i',name,'psql','-X','-At','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],query.encode()))
    finally:
        if started:
            result = run(['stop', '--time', '2', name])
            if result.returncode:
                raise RuntimeError(f'No se pudo detener el contenedor local {name}')

if __name__ == '__main__':
    main()
