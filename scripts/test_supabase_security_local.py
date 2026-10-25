#!/usr/bin/env python3
"""Auditoría SQL en un contenedor NUEVO sin red. Nunca acepta una URL remota.

Requiere Podman y la imagen local fijada debajo. No descarga imágenes ni monta
el proyecto. Por defecto reconstruye Auth/Storage con bootstrap mínimo. La opción
--restored-verification copia la base local existente a un contenedor nuevo y
guarda un dump sensible en /tmp (directorio 700, archivo 600). No prueba HTTP.
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
    parser.add_argument('--restored-verification', action='store_true',
                        help='Copiar cercly_verificacion del contenedor local restaurado; nunca migrar el original')
    parser.add_argument('--legacy-acl-drift', action='store_true',
                        help='Inyectar grants heredados en la copia para probar su eliminación')
    parser.add_argument('--lock-contention', action='store_true',
                        help='Probar rollback por lock_timeout en las tres migraciones')
    parser.add_argument('--diagnose-auth', action='store_true',
                        help='Comparar catálogos y reproducir la falta de USAGE sin conceder permisos')
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
    database = 'cercly_audit' if args.restored_verification else 'postgres'

    def command(args, data=None):
        return subprocess.run(podman + args, input=data, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, env=env, timeout=120)

    def sql(label, text, user=None, tap=False, expected_error=None):
        # El respaldo disponible fue restaurado con propietario supabase_admin.
        # Conservarlo; no falsear equivalencia con el ejecutor remoto postgres.
        user = user or ('supabase_admin' if args.restored_verification else 'postgres')
        result = command(['exec', '-i', name, 'psql', '-X', '-At', '-U', user,
                          '-d', database, '-v', 'ON_ERROR_STOP=1',
                          '-v', 'VERBOSITY=verbose'], text.encode())
        output = result.stdout.decode()
        (logs / (label + '.log')).write_text(output)
        if expected_error:
            if result.returncode == 0 or expected_error not in output:
                raise RuntimeError(f'{label}: no se produjo el rechazo esperado; {logs}')
            print(f'{label}: rechazo esperado PASS', flush=True)
            return output
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
        if args.restored_verification:
            source = 'cercly-restore-supabase'
            network = command(['inspect', source, '--format', '{{.HostConfig.NetworkMode}}'])
            if network.returncode or network.stdout.strip() != b'none':
                raise RuntimeError('La fuente restaurada debe estar sin red')
            # Copia protegida fuera de Git; conserva ACL y propietarios del respaldo.
            dump_path = logs / 'restored-verification.dump'
            with dump_path.open('xb') as dump:
                os.chmod(dump_path, 0o600)
                result = subprocess.run(podman + ['exec', source, 'pg_dump', '-U',
                    'supabase_admin', '-d', 'cercly_verificacion', '-Fc'],
                    stdout=dump, stderr=subprocess.PIPE, env=env, timeout=120)
            if result.returncode:
                raise RuntimeError('No se pudo copiar la base restaurada local')
            result = command(['exec', name, 'createdb', '-U', 'supabase_admin',
                              '-T', 'template0', database])
            if result.returncode:
                raise RuntimeError('No se pudo crear la base destino vacía')
            result = command(['exec', '-i', name, 'pg_restore', '-U', 'supabase_admin',
                              '-d', database, '--exit-on-error'], dump_path.read_bytes())
            (logs / 'restore.log').write_bytes(result.stdout)
            if result.returncode:
                raise RuntimeError(f'Restauración fallida; consultar {logs}')
            sql('pgtap-local', 'create extension if not exists pgtap with schema extensions;',
                user='supabase_admin')
            print('Copia restaurada en contenedor nuevo sin red: PASS', flush=True)
        else:
            sql('platform-bootstrap', (ROOT / 'scripts/sql/security_platform_bootstrap.sql').read_text(),
                user='supabase_admin')
        migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
        pending_names = (
            '20261017233138_fortalecer_acceso_perfiles.sql',
            '20261018000337_validar_seguridad_acceso.sql',
            '20261022033531_recuperar_perfil_autenticado.sql',
        )
        pending = [ROOT / 'supabase/migrations' / n for n in pending_names]
        if any(p.name > pending_names[-1] for p in migrations):
            raise RuntimeError('Hay migraciones posteriores: revisar el alcance del arnés')
        for path in migrations:
            if path not in pending and not args.restored_verification:
                sql(path.stem, path.read_text())
        if args.diagnose_auth:
            catalog_audit = (ROOT / 'scripts/sql/auth_catalog_audit.sql').read_text()
            sql('auth-catalog-before', catalog_audit)
        # No se almacenan filas reales en logs. La huella incluye todas las tablas
        # públicas y Auth; detecta cambios de datos, roles, propiedad o membresía.
        integrity_query = """
create or replace function pg_temp.data_fingerprint() returns text language plpgsql as $$
declare t record; h text; result text := '';
begin
  for t in select schemaname,tablename from pg_tables
    where schemaname in ('public','auth') order by schemaname,tablename
  loop
    execute format('select md5(coalesce(string_agg(row_data, chr(10) order by row_data), '''')) from (select to_jsonb(x)::text row_data from %I.%I x) s', t.schemaname,t.tablename) into h;
    result := result || t.schemaname || '.' || t.tablename || ':' || h;
  end loop;
  return md5(result);
end; $$;
select pg_temp.data_fingerprint();
"""
        source_before = None
        if args.restored_verification:
            result = command(['exec', '-i', source, 'psql', '-X', '-At', '-U',
                              'supabase_admin', '-d', 'cercly_verificacion',
                              '-v', 'ON_ERROR_STOP=1'], integrity_query.encode())
            if result.returncode:
                raise RuntimeError('No se pudo verificar integridad de la fuente local')
            source_before = result.stdout.decode()
            if source_before != sql('restored-data-integrity', integrity_query):
                raise RuntimeError('La copia restaurada difiere de la fuente en datos')
            print('Huella de datos Auth/public original = copia: PASS', flush=True)
        if args.legacy_acl_drift:
            sql('legacy-acl-drift', """
grant select, insert on public.usuarios to public;
grant select (nombre), insert (id,nombre,rol), update (nombre) on public.usuarios to anon;
grant insert (id,nombre,rol), references (id) on public.usuarios to authenticated;
""")
        sql('legacy-fixtures', """
insert into auth.users(id,email,raw_user_meta_data) values
 ('b4900000-0000-0000-0000-000000000001','legacy-admin@cercly.test','{}'),
 ('b4900000-0000-0000-0000-000000000002','legacy-owner@cercly.test','{}'),
 ('b4900000-0000-0000-0000-000000000003','legacy-user@cercly.test','{}');
update public.usuarios set rol='administrador' where id='b4900000-0000-0000-0000-000000000001';
update public.usuarios set rol='propietario' where id='b4900000-0000-0000-0000-000000000002';
""", user='supabase_admin')
        snapshot_query = integrity_query
        before = sql('profiles-before', snapshot_query)
        sql('recovery-before-security', pending[-1].read_text(),
            expected_error='Aplicar primero las migraciones de seguridad revisadas')
        for iteration in (1, 2):
            for path in pending:
                sql(f'{path.stem}-pass-{iteration}', path.read_text())
                if iteration == 1 and path == pending[0]:
                    sql('recovery-before-second-migration', pending[-1].read_text(),
                        expected_error='Aplicar primero las migraciones de seguridad revisadas')
                if iteration == 1 and path == pending[1]:
                    sql('column-insert-drift', 'grant insert (id) on public.usuarios to authenticated;')
                    sql('recovery-rejects-column-insert', pending[-1].read_text(),
                        expected_error='Aplicar primero las migraciones de seguridad revisadas')
                    sql('undo-column-insert-drift', 'revoke insert (id) on public.usuarios from authenticated;')
            after = sql(f'profiles-after-{iteration}', snapshot_query)
            if before != after:
                raise RuntimeError('Las migraciones alteraron datos existentes de Auth/public')
        print('Reaplicación y conservación de datos Auth/public: PASS', flush=True)
        if args.diagnose_auth:
            sql('auth-catalog-after', catalog_audit)
            if not args.restored_verification:
                migration_body = pending[-1].read_text().replace('begin;\n', '', 1)
                migration_body = migration_body.rstrip().removesuffix('commit;')
                for label, revoke in (
                    ('usage', 'revoke usage on schema auth from authenticated;'),
                    ('execute', 'revoke execute on function auth.uid() from public, anon, authenticated;'),
                ):
                    sql('preflight-rejects-missing-' + label,
                        'begin;\n' + revoke + '\n' + migration_body + '\nrollback;',
                        user='supabase_admin',
                        expected_error='Prerrequisitos Auth incompletos: verificar restauración de permisos')
                # No GRANT sobre auth: el cierre por error revierte este REVOKE.
                sql('reproduce-restored-missing-usage', """
begin;
revoke usage on schema auth from authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4900000-0000-0000-0000-000000000003',true);
select * from public.recuperar_mi_perfil();
rollback;
""", user='supabase_admin', expected_error='permission denied for schema auth')
                recovered = sql('recovery-after-rollback', """
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','b4900000-0000-0000-0000-000000000003',true);
select rol from public.recuperar_mi_perfil();
rollback;
""")
                if 'usuario' not in recovered.splitlines():
                    raise RuntimeError('La recuperación no volvió a funcionar tras rollback')
                print('Causa de ACL reproducida y recuperación tras rollback: PASS', flush=True)
        if args.lock_contention:
            catalog_query = """
select md5(string_agg(row_data, chr(10) order by row_data)) from (
 select jsonb_build_array(c.oid,relname,relowner,relacl,relrowsecurity,relforcerowsecurity)::text row_data from pg_class c
  where relnamespace in ('public'::regnamespace,'auth'::regnamespace)
 union all select jsonb_build_array(attrelid,attnum,attacl)::text from pg_attribute
  where attrelid in (select oid from pg_class where relnamespace in ('public'::regnamespace,'auth'::regnamespace))
 union all select to_jsonb(p)::text from pg_proc p
  where pronamespace in ('public'::regnamespace,'cercly_auth_private'::regnamespace)
 union all select to_jsonb(p)::text from pg_policy p
 union all select to_jsonb(t)::text from pg_trigger t where not tgisinternal
) s;
"""
            for path, table in zip(pending, ('public.usuarios', 'public.establecimientos', 'auth.users')):
                catalog_before = sql('catalog-before-lock-' + path.stem, catalog_query)
                with ThreadPoolExecutor(max_workers=1) as pool:
                    holder = pool.submit(sql, 'lock-holder-' + path.stem,
                        f'begin; lock table {table} in access exclusive mode; select pg_sleep(8); rollback;',
                        user='supabase_admin')
                    for attempt in range(100):
                        locked = sql('lock-ready-' + path.stem,
                            f"select exists(select 1 from pg_locks where relation='{table}'::regclass and mode='AccessExclusiveLock' and granted);")
                        if locked.strip() == 't':
                            break
                        time.sleep(0.05)
                    else:
                        raise RuntimeError('No se obtuvo bloqueo de prueba')
                    sql('lock-timeout-' + path.stem, path.read_text(), expected_error='55P03')
                    holder.result()
                if catalog_before != sql('catalog-after-lock-' + path.stem, catalog_query):
                    raise RuntimeError('Un fallo de migración dejó cambios parciales en catálogos')
            print('Rollback de las tres migraciones bajo contención: PASS', flush=True)
        # Ocho transacciones distintas compiten por el mismo perfil ausente.
        # Se usan identidades sintéticas, nunca la base restaurada del usuario.
        concurrent_id = 'b6100000-0000-0000-0000-000000000001'
        sql('concurrency-fixture', f"""
insert into auth.users(id,email,raw_user_meta_data)
values ('{concurrent_id}','concurrent@cercly.test','{{"rol":"administrador"}}');
delete from public.usuarios where id='{concurrent_id}';
""", user='supabase_admin')
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
            if args.restored_verification:
                continue
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
        before_suites = sql('data-before-suites', integrity_query)
        for path in sorted((ROOT / 'supabase/tests').glob('*test.sql')):
            if args.restored_verification and path.name not in (
                    'auth_access_test.sql', 'security_access_test.sql',
                    'profile_recovery_test.sql', 'auth_final_permissions_test.sql'):
                continue
            sql(path.stem, path.read_text(), tap=True, user='supabase_admin')
        if before_suites != sql('data-after-suites', integrity_query):
            raise RuntimeError('Una suite modificó datos fuera de rollback')
        print('Todas las suites SQL aprobaron.', flush=True)
    finally:
        if args.restored_verification and 'source_before' in locals() and source_before:
            result = command(['exec', '-i', source, 'psql', '-X', '-At', '-U',
                              'supabase_admin', '-d', 'cercly_verificacion',
                              '-v', 'ON_ERROR_STOP=1'], integrity_query.encode())
            if result.returncode or result.stdout.decode() != source_before:
                print('ALERTA: no se pudo acreditar conservación de la fuente', flush=True)
            else:
                print('Fuente restaurada original sin cambios de datos: PASS', flush=True)
        if started:
            # Solo el contenedor creado por esta ejecución; ningún volumen del usuario.
            result = command(['stop', '--time', '5', name])
            if result.returncode:
                print(f'No se pudo detener el contenedor local {name}', flush=True)


if __name__ == '__main__':
    main()
