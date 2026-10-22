#!/usr/bin/env python3
"""Auditoría SQL en un contenedor NUEVO sin red. Nunca acepta una URL remota.

Requiere Podman y la imagen local fijada debajo. No descarga imágenes ni monta
el proyecto. Auth/Storage tienen un bootstrap mínimo: no es una prueba HTTP.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--postgres-17-6', action='store_true',
                        help='Usar imagen local Supabase 17.6 fijada, en contenedor nuevo')
    args = parser.parse_args()
    image = ('docker.io/supabase/postgres@sha256:5a4314708484bec672de2c09653a5c01fb1c84a998564ac231b0325e2238ed5b'
             if args.postgres_17_6 else IMAGE)
    name = 'cercly-security-' + uuid.uuid4().hex[:12]
    logs = Path(tempfile.mkdtemp(prefix='cercly-security-results-'))
    print(f'Evidencia local: {logs}', flush=True)
    # Evita conexiones a motores remotos configuradas en el entorno.
    env = {k: v for k, v in os.environ.items()
           if k not in ('CONTAINER_HOST', 'CONTAINER_CONNECTION', 'DOCKER_HOST')}
    podman = ['podman', '--remote=false']

    def command(args, data=None):
        return subprocess.run(podman + args, input=data, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, env=env, timeout=120)

    def sql(label, text, user='postgres', tap=False):
        result = command(['exec', '-i', name, 'psql', '-X', '-At', '-U', user,
                          '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], text.encode())
        output = result.stdout.decode()
        (logs / (label + '.log')).write_text(output)
        if result.returncode:
            raise RuntimeError(f'{label}: error SQL; consultar {logs}')
        if tap:
            plans = re.findall(r'^1\.\.(\d+)$', output, re.M)
            numbers = re.findall(r'^ok (\d+)\b', output, re.M)
            expected = int(plans[0]) if len(plans) == 1 else -1
            if (expected < 1
                    or re.search(r'^(not ok|Bail out!|# Looks like)', output, re.M)
                    or numbers != [str(i) for i in range(1, expected + 1)]):
                raise RuntimeError(f'{label}: fallo o plan TAP incompleto; {logs}')
            print(f'{label}: {expected}/{expected}', flush=True)
        return output

    started = False
    try:
        result = command(['run', '-d', '--rm', '--pull=never', '--name', name,
                          '--network', 'none', '-e',
                          'POSTGRES_PASSWORD=cercly-local-audit-only', image])
        if result.returncode:
            raise RuntimeError(result.stdout.decode())
        started = True
        for _ in range(60):
            result = command(['exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'])
            if result.returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError('PostgreSQL local no inició')
        sql('platform-bootstrap', (ROOT / 'scripts/sql/security_platform_bootstrap.sql').read_text(),
            user='supabase_admin')
        migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
        pending = [p for p in migrations if p.name >= '20261017233138']
        for path in migrations:
            if path not in pending:
                sql(path.stem, path.read_text())
        sql('legacy-fixtures', """
insert into auth.users(id,email,raw_user_meta_data) values
 ('b4900000-0000-0000-0000-000000000001','legacy-admin@cercly.test','{}'),
 ('b4900000-0000-0000-0000-000000000002','legacy-owner@cercly.test','{}'),
 ('b4900000-0000-0000-0000-000000000003','legacy-user@cercly.test','{}');
update public.usuarios set rol='administrador' where id='b4900000-0000-0000-0000-000000000001';
update public.usuarios set rol='propietario' where id='b4900000-0000-0000-0000-000000000002';
""")
        snapshot_query = "select jsonb_agg(to_jsonb(u) order by id) from public.usuarios u;"
        before = sql('profiles-before', snapshot_query)
        for iteration in (1, 2):
            for path in pending:
                sql(f'{path.stem}-pass-{iteration}', path.read_text())
            after = sql(f'profiles-after-{iteration}', snapshot_query)
            if before != after:
                raise RuntimeError('Las migraciones alteraron perfiles existentes')
        print('Reaplicación y conservación de perfiles: PASS', flush=True)
        # Ocho transacciones distintas compiten por el mismo perfil ausente.
        # Se usan identidades sintéticas, nunca la base restaurada del usuario.
        concurrent_id = 'b6100000-0000-0000-0000-000000000001'
        sql('concurrency-fixture', f"""
insert into auth.users(id,email,raw_user_meta_data)
values ('{concurrent_id}','concurrent@cercly.test','{{"rol":"administrador"}}');
delete from public.usuarios where id='{concurrent_id}';
""")
        def recover(index):
            output = sql(f'concurrency-{index}', f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{concurrent_id}',true);
select rol from public.recuperar_mi_perfil();
select pg_sleep(0.2);
commit;
""")
            if 'usuario' not in output.splitlines():
                raise RuntimeError('Recuperación concurrente sin rol básico')
        with ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(recover, range(8)))
        output = sql('concurrency-result', f"select count(*) from public.usuarios where id='{concurrent_id}';")
        if output.strip() != '1':
            raise RuntimeError('Resultado concurrente inválido')
        print('Recuperación concurrente: 8/8; un único perfil usuario', flush=True)
        for name_sql in ('cargar_staging', 'promover_establecimientos', 'habilitar_osm_pruebas_local'):
            content = (ROOT / f'supabase/importacion_osm_tulcan/{name_sql}.sql').read_text()
            if name_sql == 'cargar_staging':
                original = "\\copy importacion_osm_tulcan_raw from 'supabase/seed/importacion_osm_tulcan.csv' with (format csv, header true, encoding 'UTF8')"
                csv = (ROOT / 'supabase/seed/importacion_osm_tulcan.csv').read_text().rstrip('\n')
                if original not in content:
                    raise RuntimeError('Cambió el contrato del cargador CSV local')
                content = content.replace(original,
                    "copy importacion_osm_tulcan_raw from stdin with (format csv, header true, encoding 'UTF8');\n"
                    + csv + '\n\\.\n')
            sql(name_sql, content)
        for path in sorted((ROOT / 'supabase/tests').glob('*test.sql')):
            sql(path.stem, path.read_text(), tap=True)
        print('Todas las suites SQL aprobaron.', flush=True)
    finally:
        if started:
            # Solo el contenedor creado por esta ejecución; ningún volumen del usuario.
            result = command(['stop', '--time', '5', name])
            if result.returncode:
                print(f'No se pudo detener el contenedor local {name}', flush=True)


if __name__ == '__main__':
    main()
