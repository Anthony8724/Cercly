#!/usr/bin/env python3
"""Reproducción sintética con extensiones reales; no usa el respaldo de STAGING."""
import copy,json,os,re,subprocess,tempfile,time,uuid
from pathlib import Path
from cercly_backup_catalog import QUERIES,wrapped
from recuperar_propietarios_relaciones_local import compare_relations,plan_relation_owner_recovery,MANAGED_RELATIONS

IMAGE='public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'

def main():
    os.umask(0o077)
    name='cercly-relation-owner-test-'+uuid.uuid4().hex[:10]
    operator='cercly_restore_operator_'+uuid.uuid4().hex[:8]
    env={k:v for k,v in os.environ.items() if k not in ('CONTAINER_HOST','CONTAINER_CONNECTION','DOCKER_HOST','PGPASSWORD','PGSERVICE','PGSERVICEFILE','PGPASSFILE')}
    evidence=Path(tempfile.mkdtemp(prefix='cercly-relation-owner-test-'));started=False;checks={}
    def run(args,data=None):
        r=subprocess.run(['podman','--remote=false',*args],input=data,capture_output=True,env=env,timeout=180)
        if r.returncode:raise RuntimeError('SYNTHETIC_COMMAND_FAILED_'+str(r.returncode)+': '+r.stderr.decode())
        return r.stdout
    def sql(query,db='postgres',user='supabase_admin'):
        return run(['exec','-i',name,'psql','-X','-qAt','-h','127.0.0.1','-U',user,'-d',db,'--set=ON_ERROR_STOP=1'],query.encode()).decode().strip()
    def cat(label,db):return json.loads(sql(wrapped(QUERIES[label]),db))
    member_query="select n.nspname schema,c.relname name,e.extname from pg_depend d join pg_class c on d.classid='pg_class'::regclass and d.objid=c.oid join pg_namespace n on n.oid=c.relnamespace join pg_extension e on d.refclassid='pg_extension'::regclass and d.refobjid=e.oid where d.deptype='e' order by 1,2;"
    def rejected(label,src= None,dst=None,members=None,exts=None,op=None):
        try:plan_relation_owner_recovery(src if src is not None else source,dst if dst is not None else before,members if members is not None else target_members,op or operator,source_ext,exts if exts is not None else target_ext)
        except ValueError:checks[label]=True
        else:checks[label]=False
    try:
        run(['run','-d','--rm','--pull=never','--network','none','--log-driver=none','--name',name,'-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE,'postgres','-c','cron.launch_active_jobs=off'])
        started=True
        for _ in range(120):
            r=subprocess.run(['podman','--remote=false','exec',name,'pg_isready','-h','127.0.0.1','-U','supabase_admin'],capture_output=True,env=env)
            if r.returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('SYNTHETIC_SERVER_TIMEOUT')
        checks['network_none']=run(['inspect',name,'--format','{{.HostConfig.NetworkMode}}']).strip()==b'none'
        sql('create role '+operator+' login superuser; create database owner_source template template0 owner postgres; create database owner_target template template0 owner postgres;')
        sql('create schema extensions; create schema vault; create extension postgis with schema extensions; create extension pg_stat_statements with schema extensions; create extension supabase_vault with schema vault; alter view extensions.pg_stat_statements owner to postgres; alter view extensions.pg_stat_statements_info owner to postgres; create table public.fixture(id int); alter table public.fixture owner to postgres; insert into public.fixture values(42); alter table public.fixture enable row level security; alter table public.fixture force row level security; create policy fixture_select on public.fixture for select to anon using(id=42); grant select on public.fixture to anon;', 'owner_source')
        source=cat('relations','owner_source');source_ext=cat('extensions','owner_source')
        source_acl=cat('relation_acl','owner_source');source_policies=cat('policies','owner_source')
        dump=run(['exec',name,'pg_dump','-h','127.0.0.1','-U','supabase_admin','-d','owner_source','-Fc'])
        toc=run(['exec','-i',name,'pg_restore','--list'],dump).decode()
        checks['native_dump_omits_managed_relation_definitions']=not any(re.search(r'\b(?:TABLE|VIEW) '+re.escape(s)+' '+re.escape(n)+r'(?: |$)',toc) for s,n in MANAGED_RELATIONS)
        run(['exec','-i',name,'pg_restore','-h','127.0.0.1','-U',operator,'-d','owner_target','--single-transaction','--exit-on-error'],dump)
        before=cat('relations','owner_target');target_ext=cat('extensions','owner_target')
        target_members=json.loads(sql(wrapped(member_query.rstrip(';')),'owner_target'))
        diff=compare_relations(source,before)
        checks['seven_owner_differences_reproduced']=len(diff['differences'])==7 and all(set(d['attributes'])=={'owner'} and d['attributes']['owner']['restored']==operator for d in diff['differences'])
        checks['managed_extension_memberships_verified']=all(any((m['schema'],m['name'])==key and m['extname']==ext for m in target_members) for key,(ext,kind) in MANAGED_RELATIONS.items())
        checks['source_five_admin_two_postgres']=sum(r['owner']=='supabase_admin' for r in source if (r['schema'],r['name']) in MANAGED_RELATIONS)==5 and sum(r['owner']=='postgres' for r in source if (r['schema'],r['name']) in MANAGED_RELATIONS)==2
        checks['comparator_accepts_only_row_order_difference']=compare_relations(source,list(reversed(source)))['equivalent_catalog']
        plan=plan_relation_owner_recovery(source,before,target_members,operator,source_ext,target_ext)
        checks['plan_changes_only_seven_archived_owners']=plan['change_count']==7 and len(re.findall(r'^ALTER (?:TABLE|VIEW) ',plan['sql'],re.M))==7 and not re.search(r'\b(?:GRANT|REVOKE|REASSIGN|DROP|UPDATE|INSERT|DELETE)\b',plan['sql'])
        changed=copy.deepcopy(before);changed[0]['relrowsecurity']=not changed[0]['relrowsecurity'];rejected('rejects_rls_difference',dst=changed)
        changed=copy.deepcopy(before);changed[0]['relkind']='m';rejected('rejects_kind_difference',dst=changed)
        changed=copy.deepcopy(before);changed[0]['extra_attribute']=True;rejected('rejects_unknown_attribute',dst=changed)
        rejected('rejects_missing_relation',dst=before[1:])
        rejected('rejects_additional_relation',dst=before+[dict(before[0],name='extra')])
        rejected('rejects_duplicate_identity',dst=before+[before[0]])
        changed=copy.deepcopy(before);next(x for x in changed if x['name']=='secrets')['owner']='anon';rejected('rejects_non_operator_owner',dst=changed)
        changed=copy.deepcopy(source);next(x for x in changed if x['name']=='secrets')['owner']='anon';rejected('rejects_unreviewed_source_owner',src=changed)
        changed=copy.deepcopy(target_members);next(x for x in changed if x['name']=='secrets')['extname']='postgis';rejected('rejects_wrong_extension_member',members=changed)
        changed=copy.deepcopy(target_ext);changed[0]['extversion']='0.0';rejected('rejects_extension_version_mismatch',exts=changed)
        rejected('rejects_arbitrary_operator',op='anon')
        members_before=cat('memberships','owner_target')
        # Un error después de ALTER OWNER revierte todas las modificaciones.
        failing_sql=plan['sql'].replace('COMMIT;', 'SELECT 1 / 0; COMMIT;')
        try:sql(failing_sql,'owner_target',operator)
        except RuntimeError:checks['error_inside_owner_transaction_is_reported']=True
        else:checks['error_inside_owner_transaction_is_reported']=False
        checks['failed_owner_transaction_rolls_back_catalog']=before==cat('relations','owner_target')
        sql(plan['sql'],'owner_target',operator)
        after=cat('relations','owner_target')
        checks['exact_relation_catalog_after_correction']=compare_relations(source,after)['equivalent_catalog']
        checks['exact_relation_acl_after_correction']=source_acl==cat('relation_acl','owner_target')
        checks['exact_policy_catalog_after_correction']=source_policies==cat('policies','owner_target')
        checks['membership_graph_unchanged']=members_before==cat('memberships','owner_target')
        checks['fixture_data_preserved']=sql('select count(*)=1 and min(id)=42 from public.fixture;','owner_target')=='t'
        checks['unauthorized_update_remains_denied']=sql("select not has_table_privilege('anon','public.fixture','UPDATE') and not has_table_privilege('authenticated','public.fixture','SELECT');",'owner_target')=='t'
        checks['rls_visibility_preserved']=sql('set role anon; select count(*) from public.fixture;','owner_target')=='1'
        checks['second_plan_is_noop']=plan_relation_owner_recovery(source,after,target_members,operator,source_ext,target_ext)['change_count']==0
        # Una discrepancia real de ACL sigue siendo detectable aunque coincidan owners.
        sql('grant update on public.fixture to anon;','owner_target')
        checks['additional_privilege_is_detected']=source_acl!=cat('relation_acl','owner_target')
        checks['privilege_change_does_not_hide_as_owner_difference']=compare_relations(source,cat('relations','owner_target'))['equivalent_catalog'] and source_acl!=cat('relation_acl','owner_target')
        result={'synthetic_only':True,'real_backup_used':False,'network':'none','checks_passed':sum(checks.values()),'checks_failed':sum(not v for v in checks.values()),'checks':checks}
        (evidence/'result.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2));print('EVIDENCE='+str(evidence/'result.json'))
        if not all(checks.values()):raise SystemExit(1)
    finally:
        if started:run(['stop','--time','2',name])

if __name__=='__main__':main()
