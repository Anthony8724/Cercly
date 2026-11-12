#!/usr/bin/env python3
"""Regresiones focales del arnés: PostgreSQL nuevo sin red, sin URL remota.

No ejecuta suites de recuperación/privacidad anteriores. Instala el esquema
necesario y prueba la transacción de una fixture sintética local.
"""
from collections import Counter
from dataclasses import replace
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from uuid import uuid4

from qa_privacidad_fixture import (
    APPLIED_MARKER, PUBLISHED_MARKER, Fixture, Identity, actor_sql,
    literal, prepare_history_sql,
)
from sql_local_session import ReadSession, clean_environment
from test_correcciones_local import IMAGE, ROOT

MIGRATION = '20261109005658_supresion_revisada_historial_minimo.sql'
EXPECTED_SHA = '3d401c727f55e76098704c8466be5dfac5eba4f6c2754c50418098b172b9dfe2'


def main():
    os.umask(0o077)
    evidence = Path(tempfile.mkdtemp(prefix='cercly-fixture-privacy-local-'))
    name = 'cercly-fixture-privacy-' + uuid4().hex[:10]
    env = clean_environment()
    checks, started, controller, writer = [], False, None, None

    def check(condition, label):
        checks.append({'test': label, 'passed': bool(condition)})
        if not condition:
            raise RuntimeError('LOCAL_FIXTURE_CHECK_FAILED:' + label)

    def pod(args, data=None):
        return subprocess.run(['podman', '--remote=false', *args], input=data,
                              capture_output=True, env=env, timeout=180)

    def command(user='postgres', application='fixture_local_reader'):
        return ['podman', '--remote=false', 'exec', '-i', '-e',
                'PGAPPNAME=' + application, name, 'psql', '-X', '-qAt',
                '-U', user, '-d', 'postgres', '-v', 'ON_ERROR_STOP=1',
                '-v', 'VERBOSITY=verbose']

    def sql(query, label, user='postgres', allow_error=False):
        result = subprocess.run(command(user), input=query.encode(),
                                capture_output=True, env=env, timeout=120)
        (evidence / (label + '.log')).write_bytes(result.stdout + result.stderr)
        if result.returncode and not allow_error:
            raise RuntimeError('LOCAL_FIXTURE_SQL_FAILED:' + label +
                               ':exit=' + str(result.returncode))
        return result

    def rows(query, label):
        return json.loads(sql(query, label).stdout)

    def state(f):
        b = literal(f.business_id)
        return rows(f"""select jsonb_build_object(
          'private',(select not publicable from public.establecimientos where id={b}),
          'name',(select nombre from public.establecimientos where id={b}),
          'requests',(select count(*) from public.solicitudes_establecimientos where establecimiento_id={b}),
          'applied',(select count(*) from public.solicitudes_establecimientos where establecimiento_id={b} and estado='aprobada'),
          'pending',(select count(*) from public.solicitudes_establecimientos where establecimiento_id={b} and estado='pendiente'),
          'audits',(select count(*) from public.correcciones_aplicadas where establecimiento_id={b}),
          'moderations',(select count(*) from public.auditoria_moderacion_establecimientos where establecimiento_id={b}),
          'correct_audit',(select bool_and(solicitante_id={literal(f.holder.id)} and revisado_por={literal(f.reviewer.id)}
           and antes=jsonb_build_object('nombre',{literal(f.original_name)})
           and despues=jsonb_build_object('nombre',{literal(f.corrected_name)}))
           from public.correcciones_aplicadas where establecimiento_id={b}));""", 'state-' + f.business_id)

    def seed_business(f):
        sql(f"""insert into public.establecimientos
          (id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable)
          select {literal(f.business_id)},{literal(f.reviewer.id)},id,{literal(f.original_name)},
          'Dirección sintética',0.80525,-77.73434,'aprobado',false
          from public.categorias where activa order by id limit 1;
          insert into public.miembros_establecimiento(establecimiento_id,usuario_id,rol,activo)
          values({literal(f.business_id)},{literal(f.holder.id)},'editor',true);""", 'seed-' + f.business_id)

    try:
        stamp = datetime.now(timezone.utc).isoformat()
        ids = [Identity(str(uuid4()), stamp) for _ in range(3)]
        f = Fixture(str(uuid4()), str(uuid4()), *ids,
                    '[QA PRIVACIDAD] Regresión de publicación')
        try:
            prepare_history_sql(f)
            check(False, 'authorization_required_before_sql_generation')
        except PermissionError:
            check(True, 'authorization_required_before_sql_generation')
        try:
            replace(f, context='remote-project')
            check(False, 'remote_context_rejected')
        except ValueError:
            check(True, 'remote_context_rejected')
        try:
            replace(f, holder=Identity(f.reviewer.id.upper(), stamp))
            check(False, 'duplicate_identity_case_variant_rejected')
        except ValueError:
            check(True, 'duplicate_identity_case_variant_rejected')
        check(f.applied_request == replace(f).applied_request and
              f.applied_request != f.pending_request, 'deterministic_distinct_request_ids')
        check(hashlib.sha256((ROOT / 'supabase/migrations' / MIGRATION).read_bytes()).hexdigest()
              == EXPECTED_SHA, 'server_sql_unchanged')
        result = pod(['run', '-d', '--rm', '--pull=never', '--network', 'none',
                      '--log-driver=none', '--name', name,
                      '-e', 'POSTGRES_PASSWORD=local-test-only', IMAGE])
        if result.returncode:
            raise RuntimeError('LOCAL_FIXTURE_START_FAILED:' + str(result.returncode))
        started = True
        for _ in range(120):
            if pod(['exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres']).returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('LOCAL_FIXTURE_START_TIMEOUT')
        check(pod(['inspect', name, '--format', '{{.HostConfig.NetworkMode}}']).stdout.strip() == b'none',
              'network_none')
        check(pod(['inspect', name, '--format', '{{json .HostConfig.PortBindings}}']).stdout.strip()
              in (b'null', b'{}'), 'no_published_ports')
        sql((ROOT / 'scripts/sql/security_platform_bootstrap.sql').read_text(), 'platform', 'supabase_admin')
        sql('grant select,insert on auth.sessions to postgres; '
            'alter table auth.users add column if not exists banned_until timestamptz;',
            'platform-test-capabilities', 'supabase_admin')
        for path in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
            if path.name <= MIGRATION:
                sql(path.read_text(), path.stem)
        users = ','.join(f"({literal(x.id)},'local-privacy-{i}@cercly.test','{{}}',"
                         f"{literal(stamp)},jsonb_build_object('cercly_qa_privacidad',"
                         f"jsonb_build_object('autorizada',true,'ensayo_id',{literal(f.run_id)})))"
                         for i, x in enumerate(ids))
        sql(f"""insert into auth.users(id,email,raw_user_meta_data,created_at,raw_app_meta_data) values {users};
          update public.usuarios set rol='administrador' where id={literal(f.reviewer.id)};
          insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado)
          select id,{literal(f.run_id)},created_at,clock_timestamp()+interval '1 hour',true
          from auth.users where id in ({','.join(literal(x.id) for x in ids)});
          insert into auth.sessions(id,user_id) select gen_random_uuid(),id from auth.users
          where id in ({','.join(literal(x.id) for x in ids)});""", 'three-local-identities')
        seed_business(f)
        proposal = f"""insert into public.solicitudes_establecimientos
          (id,solicitante_id,establecimiento_id,tipo,mensaje,datos_propuestos)
          values({literal(f.applied_request)},{literal(f.holder.id)},{literal(f.business_id)},'correccion','',
          jsonb_build_object('cambios',jsonb_build_object('nombre',jsonb_build_object(
           'anterior',{literal(f.original_name)},'nuevo',{literal(f.corrected_name)}))));"""
        rejected = sql('begin;\n' + actor_sql(f.holder) + proposal + '\ncommit;',
                       'reproduce-original-private-proposal', allow_error=True)
        check(rejected.returncode != 0 and b'P0001' in rejected.stderr and
              b'El establecimiento no est' in rejected.stderr, 'private_proposal_still_rejected')
        check(state(f)['requests'] == 0 and state(f)['moderations'] == 0,
              'failed_original_insert_left_no_partial_history')
        rejected = sql('begin;\n' + actor_sql(f.holder) +
                       f"select public.moderar_estado_establecimiento({literal(f.business_id)},'aprobado',true);commit;",
                       'holder-cannot-publish', allow_error=True)
        check(rejected.returncode != 0 and b'42501' in rejected.stderr,
              'publication_still_requires_authorized_admin')
        generated = prepare_history_sql(f, temporary_publication_authorized=True)
        # A second connection owns this local lock. Writer blocks AFTER publishing,
        # allowing a deterministic MVCC/RLS observation without arbitrary sleeps.
        controller = ReadSession(command(), env, evidence / 'controller.stderr')
        key = 712300000 + int(uuid4().hex[:6], 16)
        controller.query(f'select pg_advisory_lock({key});')
        paused = generated.replace(PUBLISHED_MARKER,
                                   PUBLISHED_MARKER + f'\nselect pg_advisory_xact_lock({key});')
        writer = subprocess.Popen(command(application='fixture_local_writer'),
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, env=env)
        writer.stdin.write(paused.encode())
        writer.stdin.close()
        for _ in range(150):
            waiting = controller.query("select exists(select 1 from pg_stat_activity "
                                       "where application_name='fixture_local_writer' and wait_event='advisory');")
            if waiting == 't':
                break
            if writer.poll() is not None:
                raise RuntimeError('LOCAL_WRITER_STOPPED_BEFORE_VISIBILITY_CHECK')
            time.sleep(.05)
        else:
            raise RuntimeError('LOCAL_WRITER_DID_NOT_REACH_PUBLICATION')
        check(True, 'writer_reached_transactional_publication')
        check(controller.query('select not publicable from public.establecimientos where id=' +
                               literal(f.business_id) + ';') == 't', 'other_connection_still_reads_private')
        visible = controller.query('set role anon;select count(*) from public.establecimientos where id=' +
                                   literal(f.business_id) + ';reset role;')
        check(visible == '0', 'anonymous_cannot_see_uncommitted_publication')
        controller.query(f'select pg_advisory_unlock({key});')
        writer.wait(timeout=40)
        output, errors = writer.stdout.read(), writer.stderr.read()
        (evidence / 'prepare-history.log').write_bytes(output + errors)
        check(writer.returncode == 0, 'corrected_history_transaction_succeeds')
        writer.stdout.close()
        writer.stderr.close()
        writer = None
        actual = state(f)
        check(actual['private'] and actual['name'] == f.corrected_name, 'fixture_private_again_at_commit')
        check(actual['requests'] == 2 and actual['applied'] == 1 and actual['pending'] == 1,
              'one_applied_and_one_pending_request')
        check(actual['audits'] == 1 and actual['correct_audit'], 'exact_authorized_correction_audit')
        check(actual['moderations'] == 2, 'publication_and_withdrawal_both_audited')
        duplicate = sql(generated, 'repeat-history-denied', allow_error=True)
        check(duplicate.returncode != 0, 'history_cannot_be_prepared_twice')
        check(state(f) == actual, 'duplicate_attempt_preserves_history_and_audits')
        rollback = replace(f, business_id=str(uuid4()))
        seed_business(rollback)
        broken = prepare_history_sql(rollback, temporary_publication_authorized=True).replace(
            APPLIED_MARKER, APPLIED_MARKER + '\nselect 1/0;')
        failed = sql(broken, 'injected-failure-after-application', allow_error=True)
        check(failed.returncode != 0 and b'22012' in failed.stderr, 'post_application_failure_detected')
        reverted = state(rollback)
        check(reverted['private'] and reverted['name'] == rollback.original_name,
              'error_rolls_back_publication_and_applied_name')
        check(reverted['requests'] == reverted['audits'] == reverted['moderations'] == 0,
              'error_leaves_no_partial_requests_or_audits')
        for field, update, restore in (
            ('enrollment_disabled', 'habilitado=false', 'habilitado=true'),
            ('enrollment_expired', "vence_en=clock_timestamp()-interval '1 second'",
             "vence_en=clock_timestamp()+interval '1 hour'"),
        ):
            sql(f'update cercly_account_private.sujetos_qa_supresion set {update} '
                f'where usuario_id={literal(f.holder.id)};', field)
            denied = sql(prepare_history_sql(rollback, temporary_publication_authorized=True),
                         field + '-prepare-denied', allow_error=True)
            check(denied.returncode != 0 and b'QA_FIXTURE_SUBJECT_ATTESTATION_FAILED' in denied.stderr,
                  field + '_denied_before_publication')
            sql(f'update cercly_account_private.sujetos_qa_supresion set {restore} '
                f'where usuario_id={literal(f.holder.id)};', field + '-restore')
        wrong_stamp = replace(rollback, holder=Identity(f.holder.id, '2020-01-01T00:00:00+00:00'))
        denied = sql(prepare_history_sql(wrong_stamp, temporary_publication_authorized=True),
                     'wrong-identity-timestamp', allow_error=True)
        check(denied.returncode != 0 and b'QA_FIXTURE_SUBJECT_ATTESTATION_FAILED' in denied.stderr,
              'server_identity_timestamp_mismatch_denied')
        sql('update public.usuarios set rol=\'usuario\' where id=' + literal(f.reviewer.id) + ';',
            'revoke-local-reviewer')
        denied = sql(prepare_history_sql(rollback, temporary_publication_authorized=True),
                     'reviewer-not-admin', allow_error=True)
        check(denied.returncode != 0 and b'QA_FIXTURE_ROLES_NOT_READY' in denied.stderr,
              'unprivileged_reviewer_denied')
        check(state(rollback) == reverted and state(f) == actual, 'negative_cases_leave_both_fixtures_intact')
        check(rows('select count(*) from auth.users;', 'local-auth-count') == 3,
              'only_three_synthetic_local_accounts')
        report = {'scope': 'fixture history only, disposable local PostgreSQL',
                  'network': 'none', 'ports': False, 'remote_connections': False,
                  'passed': len(checks), 'failed': 0, 'checks': checks,
                  'migration_sha256_unchanged': EXPECTED_SHA,
                  'modules_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in (ROOT / 'scripts/qa_privacidad_fixture.py', Path(__file__).resolve())},
                  'evidence_dir': str(evidence), 'real_auth_edge_storage_test': False}
        (evidence / 'report.json').write_text(
            json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)
    finally:
        if controller is not None:
            controller.close()
        if writer is not None:
            writer.wait(timeout=15)
            writer.stdout.close()
            writer.stderr.close()
        if started:
            result = pod(['stop', '--time', '2', name])
            if result.returncode:
                raise RuntimeError('LOCAL_FIXTURE_CLEANUP_FAILED:' + name)


if __name__ == '__main__':
    main()
