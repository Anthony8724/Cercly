#!/usr/bin/env python3
"""Ensayo focal sintético. Solo contenedor nuevo sin red; no acepta URL remota."""
import json
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from test_correcciones_local import IMAGE, ROOT
from sql_local_session import clean_environment

MIGRATION = '20261109005658_supresion_revisada_historial_minimo.sql'

def main():
    name = 'cercly-supresion-' + uuid.uuid4().hex[:10]
    evidence = Path(tempfile.mkdtemp(prefix='cercly-supresion-'))
    env = clean_environment()
    def run(args, data=None):
        return subprocess.run(['podman', '--remote=false', *args], input=data,
                              capture_output=True, env=env, timeout=180)
    def sql(path, user='postgres'):
        r = run(['exec', '-i', name, 'psql', '-X', '-At', '-U', user, '-d', 'postgres',
                 '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose'], path.read_bytes())
        (evidence / (path.stem + '.log')).write_bytes(r.stdout+r.stderr)
        if r.returncode:
            raise RuntimeError(f'LOCAL_SQL_FAILED:{path.name}:exit={r.returncode}; evidence={evidence}')
        return r.stdout.decode()
    started = False
    try:
        r=run(['run','-d','--rm','--pull=never','--network','none','--name',name,
               '-e','POSTGRES_PASSWORD=local-test-only',IMAGE])
        if r.returncode:
            raise RuntimeError('LOCAL_START_FAILED:'+str(r.returncode))
        started=True
        for _ in range(120):
            if run(['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres']).returncode==0: break
            time.sleep(.5)
        else: raise RuntimeError('LOCAL_START_TIMEOUT')
        if run(['inspect',name,'--format','{{.HostConfig.NetworkMode}}']).stdout.strip()!=b'none':
            raise RuntimeError('ISOLATION_FAILED')
        if run(['inspect',name,'--format','{{json .HostConfig.PortBindings}}']).stdout.strip() not in (b'null',b'{}'):
            raise RuntimeError('PORT_ISOLATION_FAILED')
        sql(ROOT/'scripts/sql/security_platform_bootstrap.sql','supabase_admin')
        r=run(['exec','-i',name,'psql','-X','-U','supabase_admin','-d','postgres','-v','ON_ERROR_STOP=1'],
              b'grant select,insert on auth.sessions to postgres;')
        if r.returncode: raise RuntimeError('LOCAL_AUTH_FIXTURE_FAILED')
        for path in sorted((ROOT/'supabase/migrations').glob('*.sql')):
            sql(path)
        results=[]
        for filename in ['privacidad_revision_focal_test.sql','supresion_revisada_test.sql','guarda_sujetos_qa_test.sql','aislamiento_eliminacion_normal_qa_test.sql']:
            out=sql(ROOT/'supabase/tests'/filename)
            plans=re.findall(r'^1\.\.(\d+)$',out,re.M)
            passes=re.findall(r'^ok \d+',out,re.M)
            failures=re.findall(r'^not ok.*|^Bail out!.*',out,re.M)
            if len(plans)!=1 or len(passes)!=int(plans[0]) or failures:
                print(json.dumps({'test':filename,'failures':failures,'evidence_dir':str(evidence)}))
                raise RuntimeError('LOCAL_ASSERTIONS_FAILED')
            results.append({'test':filename,'passed':len(passes),'failed':0})
        def execute(query):
            return run(['exec', '-i', name, 'psql', '-X', '-qAt', '-U', 'postgres',
                        '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=sqlstate'], query.encode())
        races=[]
        for number, audit_first in enumerate((True, False), 1):
            subject=f'bd140000-0000-0000-0000-{number:012d}'
            seed=execute(f"insert into auth.users(id,email,raw_user_meta_data,created_at,raw_app_meta_data) values('{subject}','privacy-race-{number}@cercly.test','{{}}',now(),jsonb_build_object('cercly_qa_privacidad',jsonb_build_object('autorizada',true,'ensayo_id','bd140000-0000-0000-0000-000000000099'))); insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado) select id,'bd140000-0000-0000-0000-000000000099',created_at,now()+interval '1 hour',true from auth.users where id='{subject}'; insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado) values('{subject}','pendiente');")
            if seed.returncode: raise RuntimeError('RACE_FIXTURE_FAILED')
            audit=f"insert into public.auditoria_moderacion_establecimientos(establecimiento_id,actor_id,ejecutor_db,estado_anterior,estado_nuevo,publicable_anterior,publicable_nuevo) values('bd140000-0000-0000-0000-000000000010','{subject}','postgres','pendiente','aprobado',false,true);"
            delete=f"delete from auth.users where id='{subject}';"
            first,second=(audit,delete) if audit_first else (delete,audit)
            with ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(execute,"set application_name='cercly-privacy-race';begin;"+first+'select pg_sleep(2);commit;')
                for _ in range(80):
                    ready=execute("select count(*) from pg_stat_activity where application_name='cercly-privacy-race' and wait_event='PgSleep';")
                    if ready.stdout.strip()==b'1': break
                    if future.done(): raise RuntimeError('RACE_FIRST_TRANSACTION_FAILED')
                    time.sleep(.05)
                else: raise RuntimeError('RACE_BARRIER_FAILED')
                rejected=execute('begin;'+second+'commit;')
                accepted=future.result(timeout=10)
            expected=b'42501' if audit_first else b'23503'
            (evidence/f'race-{number}-accepted.log').write_bytes(accepted.stdout+accepted.stderr)
            (evidence/f'race-{number}-rejected.log').write_bytes(rejected.stdout+rejected.stderr)
            if accepted.returncode or not rejected.returncode or expected not in rejected.stderr:
                raise RuntimeError('RACE_SECURITY_ASSERTION_FAILED; evidence='+str(evidence))
            state=execute(f"select (select count(*) from auth.users where id='{subject}')||':'||(select count(*) from public.auditoria_moderacion_establecimientos where actor_id='{subject}');")
            if state.returncode or state.stdout.strip()!=(b'1:1' if audit_first else b'0:0'):
                raise RuntimeError('RACE_ORPHAN_OR_DATA_LOSS')
            races.append({'first':'audit' if audit_first else 'delete','passed':True,'rejection_sqlstate':expected.decode()})
        # Revocación QA concurrente: no puede ignorarse una inscripción revocada
        # mientras Auth DELETE esperaba su bloqueo. Sin historial ni permisos extra.
        subject='bd160000-0000-0000-0000-000000000001'
        run_id='bd160000-0000-0000-0000-000000000099'
        seed=execute(f"insert into auth.users(id,email,raw_user_meta_data,created_at,raw_app_meta_data) values('{subject}','qa-revocation@cercly.test','{{}}',now(),jsonb_build_object('cercly_qa_privacidad',jsonb_build_object('autorizada',true,'ensayo_id','{run_id}'))); insert into cercly_account_private.sujetos_qa_supresion(usuario_id,ensayo_id,auth_creado_en,vence_en,habilitado) select id,'{run_id}',created_at,now()+interval '1 hour',true from auth.users where id='{subject}'; insert into cercly_account_private.solicitudes_eliminacion(usuario_id,estado) values('{subject}','pendiente');")
        if seed.returncode: raise RuntimeError('QA_REVOCATION_FIXTURE_FAILED')
        with ThreadPoolExecutor(max_workers=1) as pool:
            future=pool.submit(execute,"set application_name='cercly-qa-revocation';begin;update cercly_account_private.sujetos_qa_supresion set habilitado=false where usuario_id='"+subject+"';select pg_sleep(2);commit;")
            for _ in range(80):
                ready=execute("select count(*) from pg_stat_activity where application_name='cercly-qa-revocation' and wait_event='PgSleep';")
                if ready.stdout.strip()==b'1': break
                if future.done(): raise RuntimeError('QA_REVOCATION_FIRST_FAILED')
                time.sleep(.05)
            else: raise RuntimeError('QA_REVOCATION_BARRIER_FAILED')
            rejected=execute("delete from auth.users where id='"+subject+"';")
            accepted=future.result(timeout=10)
        (evidence/'qa-revocation-accepted.log').write_bytes(accepted.stdout+accepted.stderr)
        (evidence/'qa-revocation-rejected.log').write_bytes(rejected.stdout+rejected.stderr)
        state=execute("select (select count(*) from auth.users where id='"+subject+"')||':'||(select count(*) from cercly_account_private.sujetos_qa_supresion where usuario_id='"+subject+"' and not habilitado);")
        if accepted.returncode or not rejected.returncode or b'42501' not in rejected.stderr or state.returncode or state.stdout.strip()!=b'1:1':
            raise RuntimeError('QA_REVOCATION_RACE_FAILED; evidence='+str(evidence))
        races.append({'first':'qa_registration_revocation','passed':True,'rejection_sqlstate':'42501','identity_preserved':True})
        report={'network':'none','ports':False,'remote_connections':False,'migration':MIGRATION,
                'concurrency':races,'migration_sha256':hashlib.sha256((ROOT/'supabase/migrations'/MIGRATION).read_bytes()).hexdigest(),
                'qa_guard_default':'QA-specific route denies unenrolled subjects; normal route rejects classified QA subjects',
                'tests':results,'passed':sum(x['passed'] for x in results),'failed':0,'evidence_dir':str(evidence)}
        (evidence/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report),flush=True)
    finally:
        if started:
            r=run(['stop','--time','2',name])
            if r.returncode: raise RuntimeError('LOCAL_CLEANUP_FAILED:'+name)

if __name__=='__main__': main()
