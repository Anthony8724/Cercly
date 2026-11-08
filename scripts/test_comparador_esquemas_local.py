#!/usr/bin/env python3
"""Fixtures sin red para comparar permisos de esquema, usando parser PostgreSQL."""
import json,os,subprocess,tempfile,time,uuid
from pathlib import Path
from comparar_esquemas_respaldo import acl_decode_query,compare_schemas

IMAGE='public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'

def main():
    os.umask(0o077)
    name='cercly-schema-test-'+uuid.uuid4().hex[:10]
    evidence=Path(tempfile.mkdtemp(prefix='cercly-schema-test-'))
    env={k:v for k,v in os.environ.items() if k not in ('CONTAINER_HOST','CONTAINER_CONNECTION','DOCKER_HOST','PGPASSWORD','PGSERVICE','PGSERVICEFILE','PGPASSFILE')}
    started=False;checks={}
    def run(args,data=None):
        r=subprocess.run(['podman','--remote=false',*args],input=data,capture_output=True,env=env,timeout=120)
        if r.returncode:raise RuntimeError('Error sintético: '+r.stderr.decode())
        return r.stdout
    def sql(q):
        return run(['exec','-i',name,'psql','-X','-qAt','-h','127.0.0.1','-U','supabase_admin','-d','postgres','--set=ON_ERROR_STOP=1'],q.encode()).decode().strip()
    roles=['schema_owner_a','schema_owner_b','schema_parent','schema_child','app reader','PUBLIC','schema_grantor']
    def decode(row):return json.loads(sql(acl_decode_query(row,roles)))
    def row(acl,owner='schema_owner_a',name='fixture'):return {'nspname':name,'owner':owner,'acl':acl}
    def comparison(a,b):return compare_schemas([a],[b],decode)
    try:
        run(['run','-d','--rm','--pull=never','--network','none','--log-driver=none','--name',name,'-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE,'postgres','-c','cron.launch_active_jobs=off'])
        started=True
        for _ in range(120):
            ready=subprocess.run(['podman','--remote=false','exec',name,'pg_isready','-h','127.0.0.1','-U','supabase_admin'],capture_output=True,env=env)
            if ready.returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('No inició PostgreSQL sintético')
        assert run(['inspect',name,'--format','{{.HostConfig.NetworkMode}}']).strip()==b'none'
        for role in roles:sql('create role "'+role.replace('"','""')+'" nologin;')
        sql('grant schema_parent to schema_child with inherit true;')
        base='{schema_owner_a=UC/schema_owner_a,schema_parent=U/schema_owner_a}'
        reordered='{schema_parent=U/schema_owner_a,schema_owner_a=UC/schema_owner_a}'
        x=comparison(row(base),row(reordered));checks['acl_order_equal']=x['equivalent_catalog'] and x['summary']['representation_only_count']==1
        checks['null_matches_explicit_default']=comparison(row(None),row('{schema_owner_a=UC/schema_owner_a}'))['equivalent_catalog']
        checks['null_is_not_empty_acl']=not comparison(row(None),row('{}'))['equivalent_catalog']
        changed='{schema_owner_a=UC/schema_owner_a,schema_parent=UC/schema_owner_a}'
        x=comparison(row(base),row(changed));checks['extra_create_detected']=not x['equivalent_catalog'] and x['summary']['effective_usage_create_difference_count']==1
        grantable='{schema_owner_a=UC/schema_owner_a,schema_parent=U*/schema_owner_a}'
        checks['grant_option_detected']=not comparison(row(base),row(grantable))['equivalent_catalog']
        grantor='{schema_owner_a=UC/schema_owner_a,schema_parent=U/schema_grantor}'
        checks['grantor_change_not_ignored']=not comparison(row(base),row(grantor))['equivalent_catalog']
        checks['owner_change_detected']=not comparison(row('{}'),row('{}',owner='schema_owner_b'))['equivalent_catalog']
        checks['missing_managed_schema_detected']=not compare_schemas([row(None,name='extensions')],[],decode)['equivalent_catalog']
        checks['extra_schema_detected']=not compare_schemas([],[row(None,name='extra')],decode)['equivalent_catalog']
        a=[row(None,name='a'),row(None,name='b')];checks['schema_order_equal']=compare_schemas(a,list(reversed(a)),decode)['equivalent_catalog']
        def made_acl(grantee):
            return json.loads(sql("select to_json(array[makeaclitem("+grantee+",'schema_owner_a'::regrole,'USAGE',false)]::aclitem[]::text);"))
        quoted=made_acl("'\"app reader\"'::regrole")
        checks['quoted_role_supported']=comparison(row(quoted),row(quoted))['equivalent_catalog']
        public_acl=made_acl('0::oid')
        named_public_acl=made_acl("'\"PUBLIC\"'::regrole")
        checks['public_not_named_PUBLIC']=not comparison(row(public_acl),row(named_public_acl))['equivalent_catalog']
        effect=decode(row(base));child=next(x for x in effect['effective_usage_create'] if x['rolname']=='schema_child')
        checks['inherited_usage_recognized']=child['usage'] and not child['create_objects']
        sql('create schema fixture authorization schema_owner_a; grant usage on schema fixture to schema_parent;')
        actual=json.loads(sql("select json_agg(json_build_object('rolname',rolname,'usage',has_schema_privilege(oid,'fixture','USAGE'),'create_objects',has_schema_privilege(oid,'fixture','CREATE')) order by rolname) from pg_roles where rolname in ('schema_owner_a','schema_owner_b','schema_parent','schema_child','app reader','PUBLIC','schema_grantor');"))
        checks['projection_matches_postgres_effective_privileges']=effect['effective_usage_create']==actual
        sql('grant schema_parent to schema_child with inherit false;')
        changed_child=next(x for x in decode(row(base))['effective_usage_create'] if x['rolname']=='schema_child')
        checks['non_inherited_grant_not_assumed']=not changed_child['usage']
        try:compare_schemas([row(None),row(None)],[],decode)
        except ValueError:checks['duplicate_schema_rejected']=True
        else:checks['duplicate_schema_rejected']=False
        assert all(checks.values()),checks
        (evidence/'result.json').write_text(json.dumps({'network':'none','synthetic_only':True,'checks':checks},indent=2)+'\n')
        print('Comparador sintético: '+str(len(checks))+'/'+str(len(checks))+' PASS')
        print('Evidencia: '+str(evidence))
    finally:
        if started:run(['stop','--time','2',name])

if __name__=='__main__':main()
