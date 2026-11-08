#!/usr/bin/env python3
"""Reproduce omisión de ACL de extensión y prueba recuperación exacta sin red."""
import json,os,re,subprocess,tempfile,time,uuid
from pathlib import Path
from comparar_esquemas_respaldo import compare_schemas,acl_decode_query
from recuperar_acl_esquemas_local import plan_graphql_acl_recovery

IMAGE='public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'

def main():
    os.umask(0o077);name='cercly-acl-recovery-'+uuid.uuid4().hex[:10]
    env={k:v for k,v in os.environ.items() if k not in ('CONTAINER_HOST','CONTAINER_CONNECTION','DOCKER_HOST','PGPASSWORD','PGSERVICE','PGSERVICEFILE','PGPASSFILE')}
    evidence=Path(tempfile.mkdtemp(prefix='cercly-acl-recovery-'));started=False;checks={}
    def run(args,data=None):
        r=subprocess.run(['podman','--remote=false',*args],input=data,capture_output=True,env=env,timeout=120)
        if r.returncode:raise RuntimeError('Fallo solo sintético: '+r.stderr.decode())
        return r.stdout
    def sql(query,db='postgres'):
        return run(['exec','-i',name,'psql','-X','-qAt','-h','127.0.0.1','-U','supabase_admin','-d',db,'--set=ON_ERROR_STOP=1'],query.encode()).decode().strip()
    def schemas(db):
        return json.loads(sql("select jsonb_agg(to_jsonb(x) order by nspname) from (select nspname,pg_get_userbyid(nspowner) owner,nspacl::text acl from pg_namespace where nspname in ('graphql','graphql_public'))x;",db))
    roles=['anon','authenticated','service_role','postgres','supabase_admin','acl_unauthorized']
    def decode(row):return json.loads(sql(acl_decode_query(row,roles),'acl_target'))
    member_query="select jsonb_agg(to_jsonb(x) order by role,member,grantor) from (select r.rolname role,m.rolname member,g.rolname grantor,a.admin_option,a.inherit_option,a.set_option from pg_auth_members a join pg_roles r on r.oid=a.roleid join pg_roles m on m.oid=a.member join pg_roles g on g.oid=a.grantor where m.rolname='pg_monitor' and r.rolname in ('pg_read_all_settings','pg_read_all_stats','pg_stat_scan_tables'))x;"
    try:
        run(['run','-d','--rm','--pull=never','--network','none','--log-driver=none','--name',name,'-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE,'postgres','-c','cron.launch_active_jobs=off'])
        started=True
        for _ in range(120):
            r=subprocess.run(['podman','--remote=false','exec',name,'pg_isready','-h','127.0.0.1','-U','supabase_admin'],capture_output=True,env=env)
            if r.returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('Servidor sintético no inició')
        assert run(['inspect',name,'--format','{{.HostConfig.NetworkMode}}']).strip()==b'none'
        sql('create role acl_unauthorized nologin; create role acl_parent nologin; create role acl_child nologin; grant acl_parent to acl_child with admin false, inherit false, set true;')
        original_members=json.loads(sql(member_query));assert len(original_members)==3
        role_dump=run(['exec',name,'pg_dumpall','-h','127.0.0.1','-U','supabase_admin','--roles-only','--no-role-passwords']).decode()
        checks['native_roles_dump_omits_builtin_monitor_edges']=not any(re.search(r'^GRANT '+role+r' TO pg_monitor\b',role_dump,re.M) for role in ['pg_read_all_settings','pg_read_all_stats','pg_stat_scan_tables'])
        # Cada llamada psql es sesión separada: prueba transaccional en una llamada.
        lost=sql('begin; revoke pg_read_all_settings,pg_read_all_stats,pg_stat_scan_tables from pg_monitor; '+member_query+' rollback;')
        checks['blanket_revoke_removes_builtin_edges']=lost==''
        checks['reproduction_rolled_back']=json.loads(sql(member_query))==original_members
        cleaned=re.sub(r'^CREATE ROLE (?:"(?:[^"\n]|"")*"|[A-Za-z_][A-Za-z_0-9$]*);\s*$','',role_dump,flags=re.M)
        sql('revoke acl_parent from acl_child;')
        sql(cleaned)
        checks['native_role_restore_preserves_builtin_edges']=json.loads(sql(member_query))==original_members
        child=json.loads(sql("select row_to_json(x) from (select a.admin_option,a.inherit_option,a.set_option,g.rolname grantor from pg_auth_members a join pg_roles g on g.oid=a.grantor where a.roleid='acl_parent'::regrole and a.member='acl_child'::regrole)x;"))
        checks['custom_membership_flags_and_grantor_restored']=child=={'admin_option':False,'inherit_option':False,'set_option':True,'grantor':'supabase_admin'}
        sql('create database acl_source template template0; create database acl_target template template0;')
        shared=run(['exec',name,'pg_config','--sharedir']).decode().strip()+'/extension/'
        control="comment='Cercly synthetic ACL fixture'\ndefault_version='1.0'\nrelocatable=false\n"
        ext_base='create schema graphql; create schema graphql_public;\n'
        ext_grants='grant usage on schema graphql,graphql_public to anon,authenticated,service_role;\ngrant usage on schema graphql,graphql_public to postgres with grant option;\n'
        run(['exec','-i',name,'tee',shared+'cercly_acl_probe.control'],control.encode())
        run(['exec','-i',name,'tee',shared+'cercly_acl_probe--1.0.sql'],(ext_base+ext_grants).encode())
        sql('create extension cercly_acl_probe;','acl_source');source=schemas('acl_source')
        dump=run(['exec',name,'pg_dump','-h','127.0.0.1','-U','supabase_admin','-d','acl_source','-Fc'])
        toc=run(['exec','-i',name,'pg_restore','--list'],dump).decode()
        checks['native_extension_dump_has_no_schema_acl_entries']=not re.search(r'\bACL - SCHEMA graphql(?:_public)?\b',toc)
        # Simula el mismo objeto gestionado con inicialización local distinta.
        # Solo los archivos de ESTA extensión sintética dentro de ESTE contenedor.
        run(['exec','-i',name,'tee',shared+'cercly_acl_probe--1.0.sql'],ext_base.encode())
        run(['exec','-i',name,'pg_restore','-h','127.0.0.1','-U','supabase_admin','-d','acl_target','--single-transaction','--exit-on-error'],dump)
        before=schemas('acl_target');diff=compare_schemas(source,before,decode)
        missing=sum(len(x['attributes'].get('acl_grants',{}).get('missing',[])) for x in diff['differences'])
        checks['eight_missing_grants_reproduced']=missing==8 and diff['summary']['owner_difference_count']==0
        plan=plan_graphql_acl_recovery(source,before,decode)
        checks['plan_only_eight_original_usage_grants']=plan['grant_count']==8 and 'grant create' not in plan['sql'].lower()
        sql(plan['sql'],'acl_target')
        checks['full_schema_acl_and_owner_equivalence']=compare_schemas(source,schemas('acl_target'),decode)['equivalent_catalog']
        original_grants={x['nspname']:decode(x)['grants'] for x in source}
        actual_grants={x['nspname']:decode(x)['grants'] for x in schemas('acl_target')}
        checks['grantor_and_grant_options_exact']=original_grants==actual_grants
        checks['unauthorized_create_denied']=sql("select not has_schema_privilege('anon','graphql','CREATE') and not has_schema_privilege('authenticated','graphql_public','CREATE') and not has_schema_privilege('acl_unauthorized','graphql','USAGE');",'acl_target')=='t'
        sql('set role anon; grant usage on schema graphql to acl_unauthorized; reset role;','acl_target')
        checks['unauthorized_delegation_not_effective']=sql("select not has_schema_privilege('acl_unauthorized','graphql','USAGE');",'acl_target')=='t'
        sql('grant create on schema graphql to anon;','acl_target')
        changed=schemas('acl_target')
        checks['comparator_detects_added_privilege']=not compare_schemas(source,changed,decode)['equivalent_catalog']
        try:plan_graphql_acl_recovery(source,changed,decode)
        except ValueError:checks['recovery_refuses_unexpected_extra_privilege']=True
        else:checks['recovery_refuses_unexpected_extra_privilege']=False
        assert all(checks.values()),checks
        (evidence/'result.json').write_text(json.dumps({'synthetic_only':True,'network':'none','checks':checks},indent=2)+'\n')
        print('Recuperación sintética: '+str(len(checks))+'/'+str(len(checks))+' PASS')
        print('Evidencia: '+str(evidence))
    finally:
        if started:run(['stop','--time','2',name])

if __name__=='__main__':main()
