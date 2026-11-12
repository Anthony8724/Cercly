#!/usr/bin/env python3
"""PT409 focal: PostgreSQL + PostgREST 14 locales, sin red externa ni URLs remotas."""
import base64
from collections import Counter
from datetime import datetime, timezone
import hashlib
import hmac
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
from uuid import uuid4

from qa_privacidad_fixture import Fixture, Identity, actor_sql, literal, prepare_history_sql
from sql_local_session import ReadSession, clean_environment, BackupStopped
from test_correcciones_local import IMAGE, ROOT

BASELINE = '20261109005658_supresion_revisada_historial_minimo.sql'
PATCH = '20261109033653_conflictos_rpc_no_reintentables.sql'
API_IMAGE = 'public.ecr.aws/supabase/postgrest:v14.18'


def main():
    env = clean_environment()
    work = Path(tempfile.mkdtemp(prefix='cercly-rpc-conflicts-'))
    pg, api = 'cercly-rpc-pg-' + uuid4().hex[:8], 'cercly-rpc-api-' + uuid4().hex[:8]
    started, checks, sessions = [], [], []

    def check(value, label):
        checks.append({'test': label, 'passed': bool(value)})
        if not value:
            raise RuntimeError('LOCAL_RPC_CHECK_FAILED:' + label + '; evidence=' + str(work))

    def pod(args, data=None, timeout=120):
        return subprocess.run(['podman', '--remote=false', *args], input=data,
                              capture_output=True, env=env, timeout=timeout)

    def sql_command():
        return ['podman', '--remote=false', 'exec', '-i', pg, 'psql', '-X', '-qAt',
                '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose']

    def sql(query, label, user='postgres', allow_error=False):
        cmd = sql_command()
        cmd[cmd.index('-U') + 1] = user
        r = subprocess.run(cmd, input=query.encode(), capture_output=True, env=env, timeout=120)
        (work / (label + '.log')).write_bytes(r.stdout + r.stderr)
        if r.returncode and not allow_error:
            raise RuntimeError('LOCAL_RPC_SQL_FAILED:' + label + '; evidence=' + str(work))
        return r

    def data(query, label):
        return json.loads(sql(query, label).stdout)

    def source_state():
        return data("select jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,"
                    "'owner',proowner,'definer',prosecdef,'config',proconfig,'acl',proacl::text,"
                    "'body',prosrc) order by p.oid::regprocedure::text) from pg_proc p join pg_namespace n "
                    "on n.oid=p.pronamespace where n.nspname in ('public','cercly_account_private');", 'functions')

    def log_counts():
        r = pod(['logs', pg])
        return Counter(re.findall(rb'ERROR:\s+([A-Z0-9]{5}):', r.stdout + r.stderr))

    try:
        r = pod(['run', '-d', '--rm', '--pull=never', '--network', 'none', '--name', pg,
                 '-e', 'POSTGRES_PASSWORD=local-test-only', IMAGE, 'postgres', '-D', '/etc/postgresql',
                 '-c', 'logging_collector=off', '-c', 'log_error_verbosity=verbose',
                 '-c', 'log_min_error_statement=panic', '-c', 'cron.launch_active_jobs=off'])
        if r.returncode:
            raise RuntimeError('LOCAL_PG_START_FAILED')
        started.append(pg)
        for _ in range(120):
            if pod(['exec', pg, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres']).returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('LOCAL_PG_START_TIMEOUT')
        check(pod(['inspect', pg, '--format', '{{.HostConfig.NetworkMode}}']).stdout.strip() == b'none', 'postgres_network_none')
        check(pod(['inspect', pg, '--format', '{{json .HostConfig.PortBindings}}']).stdout.strip() in (b'null', b'{}'), 'no_host_ports')
        sql((ROOT / 'scripts/sql/security_platform_bootstrap.sql').read_text(), 'bootstrap', 'supabase_admin')
        sql("grant select,insert on auth.sessions to postgres; alter table auth.users add column if not exists banned_until timestamptz; "
            "alter role authenticator login password 'local-test-only'; grant anon,authenticated to authenticator;", 'local_platform', 'supabase_admin')
        for p in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
            if p.name <= BASELINE:
                sql(p.read_text(), p.stem)
        before = source_state()
        sql((ROOT / 'supabase/migrations' / PATCH).read_text(), 'incremental_patch')
        after = source_state()
        check(len(before) == len(after), 'no_functions_added_or_removed')
        changed = []
        for old, new in zip(before, after):
            check({k: v for k, v in old.items() if k != 'body'} ==
                  {k: v for k, v in new.items() if k != 'body'}, 'security_unchanged_' + old['signature'])
            if old['body'] != new['body']:
                changed.append(old['signature'])
                check(new['body'] == old['body'].replace("errcode='40001'", "errcode='PT409'")
                      .replace("errcode = '40001'", "errcode = 'PT409'"), 'only_literal_business_error_changed_' + old['signature'])
        check(len(changed) == 2, 'exactly_two_rpc_bodies_changed')
        check(not any('40001' in x['body'] for x in after), 'no_business_40001_left_in_active_application_functions')
        stamp = datetime.now(timezone.utc).isoformat()
        identities = [Identity(str(uuid4()), stamp) for _ in range(3)]
        f = Fixture(str(uuid4()), str(uuid4()), *identities, '[QA PRIVACIDAD] Conflictos RPC')
        values = ','.join(f"({literal(x.id)},'local-rpc-{i}@cercly.test','{{}}',{literal(stamp)},"
                          f"jsonb_build_object('cercly_qa_privacidad',jsonb_build_object('autorizada',true,'ensayo_id',{literal(f.run_id)})))"
                          for i, x in enumerate(identities))
        sql(f"""insert into auth.users(id,email,raw_user_meta_data,created_at,raw_app_meta_data) values {values};
          update public.usuarios set rol='administrador' where id={literal(f.reviewer.id)};
          insert into auth.sessions(id,user_id) select gen_random_uuid(),id from auth.users;
          insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado)
          select id,{literal(f.run_id)},created_at,now()+interval '1 hour',true from auth.users;
          insert into cercly_account_private.politicas_supresion values('QA_RPC_POLICY','LOCAL_SYNTHETIC_TEST',true,{literal(f.run_id)});
          insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
          select {literal(f.business_id)},{literal(f.reviewer.id)},id,{literal(f.original_name)},'Dirección ficticia',0.8,-77.7,'aprobado',false
          from public.categorias where activa order by id limit 1;
          insert into public.miembros_establecimiento(establecimiento_id,usuario_id,rol,activo)
          values({literal(f.business_id)},{literal(f.holder.id)},'editor',true);""", 'synthetic_identities')
        sql(prepare_history_sql(f, temporary_publication_authorized=True), 'history')
        sql('begin;' + actor_sql(f.holder) + 'select public.solicitar_eliminacion_cuenta_qa();commit;', 'privacy_case')
        check(pod(['exec', pg, 'test', '-x', '/usr/bin/curl']).returncode == 0, 'local_curl_available')
        secret = 'local-only-synthetic-jwt-secret-for-rpc-test'

        def jwt(identity):
            session = sql('select id from auth.sessions where user_id=' + literal(identity.id) + ';', 'session-' + identity.id).stdout.decode().strip()
            enc = lambda value: base64.urlsafe_b64encode(json.dumps(value, separators=(',', ':')).encode()).decode().rstrip('=')
            body = enc({'alg': 'HS256', 'typ': 'JWT'}) + '.' + enc({'role': 'authenticated', 'sub': identity.id,
                    'session_id': session, 'exp': int(time.time()) + 3600})
            return body + '.' + base64.urlsafe_b64encode(hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()).decode().rstrip('=')

        r = pod(['run', '-d', '--rm', '--pull=never', '--network', 'container:' + pg, '--name', api,
                 '-e', 'PGRST_DB_URI=postgresql://authenticator:local-test-only@127.0.0.1:5432/postgres',
                 '-e', 'PGRST_DB_SCHEMAS=public', '-e', 'PGRST_DB_ANON_ROLE=anon',
                 '-e', 'PGRST_JWT_SECRET=' + secret, API_IMAGE])
        if r.returncode:
            raise RuntimeError('LOCAL_API_START_FAILED')
        started.append(api)
        mode = pod(['inspect', api, '--format', '{{.HostConfig.NetworkMode}}']).stdout.strip()
        check(mode.startswith(b'container:'), 'postgrest_shares_only_isolated_postgres_network_namespace')
        for _ in range(60):
            r = pod(['exec', pg, 'curl', '-s', '--max-time', '1', '-o', '/dev/null', '-w', '%{http_code}', 'http://127.0.0.1:3000/'])
            if r.returncode == 0 and r.stdout == b'200':
                break
            time.sleep(.2)
        else:
            (work / 'api-start.log').write_bytes(pod(['logs', api]).stderr)
            raise RuntimeError('LOCAL_API_READY_TIMEOUT; evidence=' + str(work))
        tokens = {x.id: jwt(x) for x in identities}
        http_results = []

        def http_rpc(identity, function, args, status, error=None):
            counts = log_counts()
            start = time.monotonic()
            response = pod(['exec', pg, 'curl', '-sS', '--max-time', '8', '-w', '\n%{http_code}',
                            '-H', 'Content-Type: application/json', '-H', 'Authorization: Bearer ' + tokens[identity.id],
                            '--data', json.dumps(args), 'http://127.0.0.1:3000/rpc/' + function])
            elapsed = round((time.monotonic() - start) * 1000)
            check(response.returncode == 0, 'http_returns_without_timeout_' + function + '_' + str(len(http_results)))
            payload, code = response.stdout.rsplit(b'\n', 1)
            result = json.loads(payload or b'null')
            (work / ('http-' + str(len(http_results)) + '.json')).write_text(json.dumps({
                'function': function, 'status': int(code),
                'error_code': result.get('code') if isinstance(result, dict) else None,
                'empty_or_null_body': result is None,
            }))
            check(int(code) == status and (not error or result.get('code') == error),
                  'http_expected_result_' + function + '_' + str(len(http_results)))
            # PG logs have one error per executed transaction. No wrapper/mock
            # replaces the RPC: request passes through the installed PostgREST 14.
            if error == 'PT409':
                delta = log_counts()[b'PT409'] - counts[b'PT409']
                check(delta == 1, 'one_server_error_no_retry_' + function + '_' + str(len(http_results)))
                check(log_counts()[b'40001'] == counts[b'40001'], 'no_serialization_loop_' + function + '_' + str(len(http_results)))
            http_results.append({'function': function, 'http': int(code), 'code': error, 'elapsed_ms': elapsed, 'requests': 1})
            return result

        privacy_args = {'p_usuario_id': f.holder.id, 'p_huella': '0' * 64,
                        'p_politica': 'QA_RPC_POLICY', 'p_revision_externa_confirmada': True}
        http_rpc(f.reviewer, 'autorizar_supresion_revisada_qa', privacy_args, 409, 'PT409')
        check(data('select count(*) from cercly_account_private.planes_supresion;', 'no-plan') == 0,
              'stale_privacy_approval_creates_no_plan')
        prefs = {'p_categorias_ids': [], 'p_radio_metros': 5000, 'p_priorizar_promociones': False, 'p_revision_esperada': 9}
        http_rpc(f.holder, 'guardar_preferencias_usuario', prefs, 409, 'PT409')
        check(data('select count(*) from public.preferencias_usuario;', 'no-first-write') == 0,
              'stale_first_preferences_insert_is_rolled_back')
        prefs['p_revision_esperada'] = 0
        check(http_rpc(f.holder, 'guardar_preferencias_usuario', prefs, 200) == 1, 'valid_preferences_save_preserved')
        prefs['p_revision_esperada'] = 0
        http_rpc(f.holder, 'guardar_preferencias_usuario', prefs, 409, 'PT409')
        check(data('select revision from public.preferencias_usuario where usuario_id=' + literal(f.holder.id) + ';', 'revision') == 1,
              'stale_update_does_not_change_revision')
        http_rpc(f.simple_holder, 'autorizar_supresion_revisada_qa', privacy_args, 403, '42501')
        current = data('select to_jsonb(cercly_account_private.huella_supresion(' + literal(f.holder.id) + '));', 'current-hash')
        privacy_args['p_huella'] = current
        http_rpc(f.reviewer, 'autorizar_supresion_revisada_qa', privacy_args, 204)
        check(data('select count(*) from cercly_account_private.planes_supresion;', 'one-plan') == 1,
              'valid_approval_unchanged_one_plan')
        # A REAL serialization conflict still produces PostgreSQL 40001.
        one = ReadSession(sql_command(), env, work / 'serial-one.stderr')
        two = ReadSession(sql_command(), env, work / 'serial-two.stderr')
        sessions.extend([one, two])
        for session in (one, two):
            session.query('begin isolation level serializable;' + actor_sql(f.holder) +
                          'select revision from public.preferencias_usuario where usuario_id=' + literal(f.holder.id) + ';')
        one.query('select public.guardar_preferencias_usuario(array[]::uuid[],5000,false,1);commit;')
        try:
            two.query('select public.guardar_preferencias_usuario(array[]::uuid[],5000,false,1);commit;')
            check(False, 'real_serialization_still_40001')
        except BackupStopped as error:
            check(error.sqlstate == '40001' or b'40001' in (error.private_error or b''), 'real_serialization_still_40001')
        check(data('select revision from public.preferencias_usuario where usuario_id=' + literal(f.holder.id) + ';', 'after-concurrency') == 2,
              'concurrent_save_committed_only_once')
        report = {'network': 'PostgreSQL none; PostgREST shares that namespace, no external route', 'ports': False,
                  'baseline_migrations': 28, 'incremental': PATCH, 'postgrest_image': API_IMAGE,
                  'passed': len(checks), 'failed': 0, 'checks': checks, 'http': http_results,
                  'changed_function_bodies': changed, 'security_metadata_unchanged': True,
                  'genuine_serialization_preserved': True, 'remote_writes': 0, 'evidence_dir': str(work),
                  'migration_sha256': hashlib.sha256((ROOT / 'supabase/migrations' / PATCH).read_bytes()).hexdigest()}
        (work / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({k: report[k] for k in ('passed', 'failed', 'http', 'changed_function_bodies', 'evidence_dir')}), flush=True)
    finally:
        for session in sessions:
            session.close()
        for container in reversed(started):
            pod(['stop', '--time', '2', container])


if __name__ == '__main__':
    main()
