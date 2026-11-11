#!/usr/bin/env python3
"""Diagnóstico sintético del bootstrap de roles. Sin red ni acceso a backups.

Solo crea y detiene su propio contenedor; imagen fijada, sin descargas.
No acepta URLs, contraseñas, dumps o destinos remotos.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

IMAGE = 'public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'


def main():
    os.umask(0o077)
    evidence = Path(tempfile.mkdtemp(prefix='cercly-roles-diagnostic-'))
    name = 'cercly-roles-diagnostic-' + uuid.uuid4().hex[:10]
    env = {k: v for k, v in os.environ.items() if k not in
           ('CONTAINER_HOST', 'CONTAINER_CONNECTION', 'DOCKER_HOST',
            'PGPASSWORD', 'PGSERVICE', 'PGSERVICEFILE', 'PGPASSFILE')}
    started = False
    stage = 'start'
    report = {'synthetic_only': True, 'network': 'none', 'real_backup_opened': False}

    def execute(args, data=None):
        return subprocess.run(['podman', '--remote=false', *args], input=data,
                              capture_output=True, env=env, timeout=120)

    def checked(args, data=None):
        r = execute(args, data)
        if r.returncode:
            # Solo fixtures de este script; nunca se procesan filas reales.
            raise RuntimeError(f'{stage}: exit={r.returncode}: ' + r.stderr.decode())
        return r.stdout

    def sql(text, user='cercly_restore_operator_probe', database='postgres', expect=None):
        args = ['exec', '-i', name, 'psql', '-X', '-qAt', '-h', '127.0.0.1', '-U', user, '-d', database,
                '--set=ON_ERROR_STOP=1', '--set=VERBOSITY=verbose']
        r = execute(args, text.encode())
        if expect is not None:
            assert r.returncode == expect, (r.returncode, r.stderr.decode())
            return r
        if r.returncode:
            raise RuntimeError(f'{stage}: exit={r.returncode}: ' + r.stderr.decode())
        return r.stdout.decode().strip()

    try:
        checked(['run', '-d', '--rm', '--pull=never', '--network', 'none',
                 '--log-driver=none', '--name', name,
                 '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', IMAGE, 'postgres',
                 '-c', 'cron.database_name=cercly_restore',
                 '-c', 'cron.launch_active_jobs=off', '-c', 'logging_collector=off',
                 '-c', 'log_min_error_statement=panic'])
        started = True
        for _ in range(120):
            if execute(['exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'supabase_admin']).returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('PostgreSQL local no inició')
        assert checked(['inspect', name, '--format', '{{.HostConfig.NetworkMode}}']).strip() == b'none'
        report['versions'] = checked(['exec', name, 'sh', '-c',
                                      'pg_dump --version && pg_restore --version']).decode().splitlines()
        stage = 'inspect_local_roles'
        roles = json.loads(sql("""select jsonb_agg(to_jsonb(r) order by rolname) from
          (select rolname,rolsuper,rolcreaterole,rolcreatedb,rolcanlogin,rolbypassrls
           from pg_roles where rolname in ('postgres','supabase_admin')) r;""", user='postgres'))
        report['local_roles_before'] = roles
        stage = 'reproduce_original_command'
        statement = 'create role "cercly_restore_operator_probe" login superuser;'
        original = sql(statement, user='postgres', expect=3)
        error = original.stderr.decode()
        assert '42501' in error and 'superuser' in error.lower(), error
        report['privilege_failure_after_startup'] = {
            'command': 'psql -X -qAt -U postgres -d postgres --set=ON_ERROR_STOP=1',
            'sql': statement, 'exit_code': original.returncode, 'sqlstate': '42501',
            'stderr_synthetic': error.strip(),
        }
        print('Defecto de permisos reproducido: psql exit=3, SQLSTATE=42501', flush=True)
        stage = 'corrected_bootstrap'
        assert next(x for x in roles if x['rolname']=='supabase_admin')['rolsuper']
        sql(statement, user='supabase_admin')
        assert sql('select rolsuper from pg_roles where rolname=current_user;') == 't'
        report['corrected_bootstrap_exit_code'] = 0
        report['final_server_readiness'] = 'TCP loopback 127.0.0.1 inside network=none'
        stage = 'remaining_role_preparation'
        sql('create role probe_business_owner nologin; create role probe_app_client nologin;')
        sql('create database cercly_probe_source template template0 owner postgres;')
        sql('create database cercly_restore template template0 owner postgres;')
        assert sql("select rolsuper from pg_roles where rolname='postgres';") == 'f'
        stage = 'synthetic_fixture'
        sql("""
        create schema probe authorization probe_business_owner;
        create table probe.items(id bigint generated always as identity primary key,
                                visible boolean not null, changes integer not null default 0);
        alter table probe.items owner to probe_business_owner;
        insert into probe.items(visible) values(true),(false);
        alter table probe.items enable row level security;
        create policy visible_rows on probe.items for select to probe_app_client using(visible);
        grant usage on schema probe to probe_app_client;
        grant select on probe.items to probe_app_client;
        create function probe.visible_count() returns bigint language sql security invoker
          set search_path='' as 'select count(*) from probe.items';
        alter function probe.visible_count() owner to probe_business_owner;
        create function probe.touch() returns trigger language plpgsql set search_path='' as
          'begin new.changes := old.changes + 1; return new; end';
        alter function probe.touch() owner to probe_business_owner;
        create trigger touch before update on probe.items for each row execute function probe.touch();
        """, database='cercly_probe_source')
        stage = 'synthetic_dump_restore'
        archive = checked(['exec', name, 'pg_dump', '-h', '127.0.0.1', '-U', 'cercly_restore_operator_probe',
                           '-d', 'cercly_probe_source', '-Fc', '--schema=probe'])
        checked(['exec', '-i', name, 'pg_restore', '-h', '127.0.0.1', '-U', 'cercly_restore_operator_probe',
                 '-d', 'cercly_restore', '--single-transaction', '--exit-on-error'], archive)
        stage = 'verify_ownership_rls_permissions_triggers_sequence'
        checks = {}
        checks['rows'] = sql('select count(*) from probe.items;', database='cercly_restore') == '2'
        checks['rls'] = sql('set role probe_app_client; select probe.visible_count();', database='cercly_restore') == '1'
        denied = sql('set role probe_app_client; update probe.items set visible=false;',
                     database='cercly_restore', expect=3)
        checks['unauthorized_update_denied'] = '42501' in denied.stderr.decode()
        checks['owner'] = sql("select pg_get_userbyid(relowner) from pg_class where oid='probe.items'::regclass;", database='cercly_restore') == 'probe_business_owner'
        checks['policy'] = sql("select count(*) from pg_policies where schemaname='probe' and tablename='items' and policyname='visible_rows';", database='cercly_restore') == '1'
        checks['trigger_present'] = sql("select count(*) from pg_trigger where tgrelid='probe.items'::regclass and tgname='touch' and tgenabled='O';", database='cercly_restore') == '1'
        source_seq = sql('select last_value,is_called from probe.items_id_seq;', database='cercly_probe_source')
        checks['sequence_state'] = source_seq == sql('select last_value,is_called from probe.items_id_seq;', database='cercly_restore')
        sql('update probe.items set visible=true where id=1;', database='cercly_restore')
        checks['trigger_executes'] = sql('select changes from probe.items where id=1;', database='cercly_restore') == '1'
        checks['sequence_continuity'] = sql('insert into probe.items(visible) values(true) returning id;', database='cercly_restore') == '3'
        checks['client_not_superuser'] = sql("select not rolsuper and not rolbypassrls from pg_roles where rolname='probe_app_client';") == 't'
        checks['postgres_not_elevated'] = sql("select not rolsuper from pg_roles where rolname='postgres';") == 't'
        assert all(checks.values()), checks
        report['checks'] = checks
        report['result'] = 'PASS'
        (evidence / 'result.json').write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps(report, indent=2), flush=True)
    except Exception:
        report.update({'result': 'FAILED', 'stage': stage})
        (evidence / 'result.json').write_text(json.dumps(report, indent=2)+'\n')
        raise
    finally:
        if started:
            result = execute(['stop', '--time', '2', name])
            if result.returncode:
                raise RuntimeError('No se pudo detener el contenedor propio '+name)
        print('Evidencia sintética: '+str(evidence), flush=True)


if __name__ == '__main__':
    main()
