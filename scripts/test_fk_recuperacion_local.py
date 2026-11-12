#!/usr/bin/env python3
"""Fixtures de FK simples/compuestas y guardas RPC; no usa el respaldo real."""
import json,os,subprocess,tempfile,time,uuid
from pathlib import Path
from cercly_backup_catalog import wrapped
from verificar_fk_local import FK_INVENTORY,orphan_query
from test_correcciones_local import IMAGE
from sql_local_session import clean_environment


def main():
    os.umask(0o077);name='cercly-fk-fixture-'+uuid.uuid4().hex[:10];started=False;checks={}
    env=clean_environment()
    def run(options,data=None,allow_error=False):
        result=subprocess.run(['podman','--remote=false',*options],input=data,capture_output=True,env=env,timeout=180)
        if result.returncode and not allow_error:raise RuntimeError('SYNTHETIC_FK_COMMAND_FAILED_'+str(result.returncode)+': '+result.stderr.decode())
        return result
    def sql(query,allow_error=False):
        result=run(['exec','-i',name,'psql','-X','-qAt','-h','127.0.0.1','-U','supabase_admin','-d','postgres','--set=ON_ERROR_STOP=1','--set=VERBOSITY=verbose','--set=SHOW_CONTEXT=never'],query.encode(),allow_error)
        return result if allow_error else result.stdout.decode().strip()
    try:
        run(['run','-d','--rm','--pull=never','--network','none','--log-driver=none','--name',name,'-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE,'postgres','-c','cron.launch_active_jobs=off','-c','logging_collector=off']);started=True
        for _ in range(120):
            if run(['exec',name,'pg_isready','-h','127.0.0.1','-U','supabase_admin'],allow_error=True).returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('SYNTHETIC_FK_TIMEOUT')
        checks['network_none']=run(['inspect',name,'--format','{{.HostConfig.NetworkMode}}']).stdout.strip()==b'none'
        sql('create schema qa; create table qa.parent(a int,b int,primary key(a,b)); insert into qa.parent values(1,2); create table qa.simple(a int,b int,foreign key(a,b) references qa.parent(a,b) match simple); create table qa.full_match(a int,b int,foreign key(a,b) references qa.parent(a,b) match full); insert into qa.simple values(1,2),(NULL,9),(9,NULL),(NULL,NULL); insert into qa.full_match values(1,2),(NULL,NULL);')
        inventory=json.loads(sql(wrapped(FK_INVENTORY)))
        selected={row['name']:row for row in inventory if row['schema']=='qa'}
        checks['simple_nulls_are_exempt']=sql(orphan_query(selected['simple']))=='0'
        checks['full_all_null_and_valid_are_exempt']=sql(orphan_query(selected['full_match']))=='0'
        sql('alter table qa.simple drop constraint simple_a_b_fkey; insert into qa.simple values(8,9); alter table qa.simple add constraint simple_a_b_fkey foreign key(a,b) references qa.parent(a,b) match simple not valid; alter table qa.full_match drop constraint full_match_a_b_fkey; insert into qa.full_match values(1,NULL),(8,9); alter table qa.full_match add constraint full_match_a_b_fkey foreign key(a,b) references qa.parent(a,b) match full not valid;')
        selected={row['name']:row for row in json.loads(sql(wrapped(FK_INVENTORY))) if row['schema']=='qa'}
        checks['simple_orphan_is_detected']=sql(orphan_query(selected['simple']))=='1'
        checks['full_partial_null_and_orphan_detected']=sql(orphan_query(selected['full_match']))=='2'
        checks['not_valid_state_is_preserved']=all(not row['convalidated'] for row in selected.values())
        before=sql('select count(*) from qa.simple;');sql(orphan_query(selected['simple']));checks['read_only_verification_does_not_change_rows']=before==sql('select count(*) from qa.simple;')
        try:orphan_query(dict(selected['simple'],confmatchtype='p'))
        except ValueError:checks['unsupported_match_rejected']=True
        else:checks['unsupported_match_rejected']=False
        changed=dict(selected['simple'],pairs=[dict(selected['simple']['pairs'][0],operator='=;select')])
        try:orphan_query(changed)
        except ValueError:checks['unsafe_operator_rejected']=True
        else:checks['unsafe_operator_rejected']=False
        sql("create function qa.denied_rpc() returns void language plpgsql security definer as $$ begin raise exception 'Solo un administrador autenticado puede responder solicitudes.'; end $$; grant usage on schema qa to authenticated; grant execute on function qa.denied_rpc() to authenticated;")
        denied=sql('begin read only; set local role authenticated; select qa.denied_rpc(); rollback;',True)
        checks['rpc_denial_sqlstate_and_message_identified']=denied.returncode!=0 and b'P0001' in denied.stderr and b'Solo un administrador autenticado puede responder solicitudes.' in denied.stderr
        result={'synthetic_only':True,'real_backup_used':False,'checks_passed':sum(checks.values()),'checks_failed':sum(not v for v in checks.values()),'checks':checks}
        output=Path(tempfile.mkdtemp(prefix='cercly-fk-tests-'))/'result.json';output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));print('EVIDENCE='+str(output))
        if not all(checks.values()):raise SystemExit(1)
    finally:
        if started:run(['stop','--time','2',name])


if __name__=='__main__':main()
