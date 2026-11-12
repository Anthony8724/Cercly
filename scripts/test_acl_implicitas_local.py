#!/usr/bin/env python3
"""Pruebas de ACL por defecto; solo fixtures, sin el respaldo real ni red."""
import copy,json,os,subprocess,tempfile,time,uuid
from pathlib import Path
from cercly_backup_catalog import QUERIES,wrapped,ident
from clasificar_acl_relaciones_local import (classify_null_acl_representation,
    relation_acl_decode_query,verify_reviewed_representation,REVIEWED_DEFAULT_RELATIONS)
from diagnostico_acl_relaciones_local import compare_relation_acl
from test_correcciones_local import IMAGE
from sql_local_session import clean_environment
from recuperar_acl_relaciones_local import plan_postgis_acl_recovery
from recuperar_propietarios_relaciones_local import plan_relation_owner_recovery


def main():
    os.umask(0o077);container='cercly-null-acl-synthetic-'+uuid.uuid4().hex[:10]
    env=clean_environment()
    started=False;checks={}
    def run(options,data=None):
        result=subprocess.run(['podman','--remote=false',*options],input=data,capture_output=True,env=env,timeout=180)
        if result.returncode:raise RuntimeError('SYNTHETIC_SQL_FAILED_'+str(result.returncode)+': '+result.stderr.decode())
        return result.stdout
    def sql(query,database='postgres'):
        return run(['exec','-i',container,'psql','-X','-qAt','-h','127.0.0.1','-U','supabase_admin','-d',database,'--set=ON_ERROR_STOP=1'],query.encode()).decode().strip()
    def cat(label,db):return json.loads(sql(wrapped(QUERIES[label]),db))
    def storage(db):
        return json.loads(sql(wrapped("select n.nspname schema,c.relname name,pg_get_userbyid(c.relowner) owner,c.relacl::text raw_acl,acldefault(case when c.relkind='S' then 's'::\"char\" else 'r'::\"char\" end,c.relowner)::text default_acl from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname !~ '^pg_' and n.nspname<>'information_schema' and c.relkind in ('r','p','v','m','S') order by 1,2"),db))
    def decode(raw,owner,kind):return json.loads(sql(relation_acl_decode_query(raw,owner,kind)))
    def classify(**changes):
        args=dict(source_relations=source,target_storage=raw,restored_relations=target,
                  source_acl=source_acl,restored_acl=target_acl,decode_acl=decode)
        args.update(changes);return classify_null_acl_representation(**args)
    def rejects(label,**changes):
        try:classify(**changes)
        except ValueError:checks[label]=True
        else:checks[label]=False
    def setup_defaults(database):
        for schema in sorted({key[0] for key in REVIEWED_DEFAULT_RELATIONS}):
            sql('create schema '+ident(schema)+';',database)
        for (schema,name),kind in REVIEWED_DEFAULT_RELATIONS.items():
            table=ident(schema)+'.'+ident(name);verb='SEQUENCE' if kind=='S' else 'TABLE'
            sql('CREATE '+verb+' '+table+(';' if kind=='S' else '(id int);')+' ALTER '+verb+' '+table+' OWNER TO postgres; GRANT ALL ON '+verb+' '+table+' TO postgres;',database)
    try:
        run(['run','-d','--rm','--pull=never','--network','none','--log-driver=none','--name',container,'-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE,'postgres','-c','cron.launch_active_jobs=off','-c','logging_collector=off']);started=True
        for _ in range(120):
            result=subprocess.run(['podman','--remote=false','exec',container,'pg_isready','-h','127.0.0.1','-U','supabase_admin'],capture_output=True,env=env)
            if result.returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('SYNTHETIC_START_TIMEOUT')
        checks['network_none']=run(['inspect',container,'--format','{{.HostConfig.NetworkMode}}']).strip()==b'none'
        sql('create database acl_defaults_source template template0 owner postgres; create database acl_defaults_target template template0 owner postgres; create role acl_fixture_owner login nosuperuser noinherit nobypassrls; create role acl_fixture_outsider nosuperuser noinherit nobypassrls;')
        setup_defaults('acl_defaults_source')
        source=cat('relations','acl_defaults_source');source_acl=cat('relation_acl','acl_defaults_source')
        dump=run(['exec',container,'pg_dump','-h','127.0.0.1','-U','supabase_admin','-d','acl_defaults_source','-Fc'])
        toc=run(['exec','-i',container,'pg_restore','--list'],dump).decode()
        checks['native_dump_omits_default_equivalent_acl']=not any(' ACL '+schema+' ' in toc for schema,_ in REVIEWED_DEFAULT_RELATIONS)
        run(['exec','-i',container,'pg_restore','-h','127.0.0.1','-U','supabase_admin','-d','acl_defaults_target','--single-transaction','--exit-on-error'],dump)
        target=cat('relations','acl_defaults_target');target_acl=cat('relation_acl','acl_defaults_target');raw=storage('acl_defaults_target')
        checks['43_explicit_source_rows_and_zero_target_rows']=len(source_acl)==43 and not target_acl and all(row['raw_acl'] is None for row in raw)
        result=classify()
        checks['all_43_classified_as_representation']=result['representation_entry_count']==43 and len(result['classifications'])==6
        checks['normalized_catalog_is_exact_including_grantor_and_option']=compare_relation_acl(source_acl,result['restored_acl_normalized'])['same_entries_including_multiplicity']
        checks['no_remaining_missing_or_additional']=not result['remaining_comparison']['missing_entries'] and not result['remaining_comparison']['additional_entries']
        verify_reviewed_representation(result);checks['six_reviewed_names_are_accepted']=True
        checks['classifier_does_not_modify_acl_storage']=raw==storage('acl_defaults_target') and not cat('relation_acl','acl_defaults_target')
        checks['table_defaults_have_8_and_sequence_defaults_3']=len(decode(None,'postgres','r'))==8 and len(decode(None,'postgres','S'))==3
        changed=copy.deepcopy(source_acl);changed[0]['is_grantable']=True
        checks['grant_option_difference_is_not_normalized']=classify(source_acl=changed)['representation_entry_count']<43
        changed=copy.deepcopy(source_acl);changed[0]['grantor']='supabase_admin'
        checks['grantor_difference_is_not_normalized']=classify(source_acl=changed)['representation_entry_count']<43
        changed=copy.deepcopy(source_acl);changed[0]['grantee']='acl_fixture_outsider'
        checks['grantee_difference_is_not_normalized']=classify(source_acl=changed)['representation_entry_count']<43
        checks['duplicate_grant_is_not_discarded']=classify(source_acl=source_acl+[source_acl[0]])['representation_entry_count']<43
        checks['additional_actual_grant_remains_detected']=bool(classify(restored_acl=[dict(source_acl[0],grantee='acl_fixture_outsider')])['remaining_comparison']['additional_entries'])
        changed=copy.deepcopy(target);changed[0]['owner']='supabase_admin';rejects('owner_mismatch_rejected',restored_relations=changed)
        changed=copy.deepcopy(target);changed[0]['relrowsecurity']=not changed[0]['relrowsecurity'];rejects('rls_mismatch_rejected',restored_relations=changed)
        changed=copy.deepcopy(raw);changed[0]['owner']='supabase_admin';rejects('inconsistent_storage_owner_rejected',target_storage=changed)
        rejects('missing_storage_rejected',target_storage=raw[1:])
        changed=copy.deepcopy(result);changed['classifications'][0]['name']='unreviewed'
        try:verify_reviewed_representation(changed)
        except ValueError:checks['unreviewed_name_rejected']=True
        else:checks['unreviewed_name_rejected']=False
        changed=copy.deepcopy(raw);changed[0]['raw_acl']='{}'
        checks['explicit_empty_acl_is_never_treated_as_null']=classify(target_storage=changed)['representation_entry_count']<43 and decode('{}','postgres','r')==[]
        empty=classify(source_acl=[],restored_acl=[])
        checks['missing_source_raw_acl_is_reported_as_ambiguous']=len(empty['ambiguous_source_empty_acl'])==6 and empty['representation_entry_count']==0
        # Probar privilegios ordinarios revocados con owner NO superusuario y sin membresías.
        sql('create schema qa; create table qa.revoked(id int); alter table qa.revoked owner to acl_fixture_owner; grant usage on schema qa to acl_fixture_owner; revoke select on qa.revoked from acl_fixture_owner;')
        checks['owner_can_lack_ordinary_select']=sql("select not has_table_privilege('acl_fixture_owner','qa.revoked','SELECT');")=='t'
        checks['owner_retains_inherent_grant_option']=sql("select has_table_privilege('acl_fixture_owner','qa.revoked','SELECT WITH GRANT OPTION');")=='t'
        src=[row for row in cat('relation_acl','postgres') if row['schema']=='qa']
        rel=[row for row in cat('relations','postgres') if row['schema']=='qa']
        pretend_null=[dict(schema='qa',name='revoked',owner='acl_fixture_owner',raw_acl=None)]
        revoked=classify_null_acl_representation(rel,rel,src,[],pretend_null,decode)
        checks['revoked_owner_privilege_is_a_real_difference']=revoked['representation_entry_count']==0 and any(row['entry']['privilege_type']=='SELECT' for row in revoked['classifications'][0]['default_acl_comparison']['additional_entries'])
        checks['outsider_remains_without_select']=sql("select not has_table_privilege('acl_fixture_outsider','qa.revoked','SELECT');")=='t'
        checks['fixtures_owner_is_not_superuser_or_bypass']=sql("select not rolsuper and not rolbypassrls and not rolinherit from pg_roles where rolname='acl_fixture_owner';")=='t'
        # Integración de los dos grupos en una sola importación SINTÉTICA:
        # 43 diferencias de representación y 24 GRANT PostGIS realmente ausentes.
        operator='cercly_restore_operator_'+uuid.uuid4().hex[:8]
        sql('create role '+ident(operator)+' login superuser; create database acl_combined_source template template0 owner postgres; create database acl_combined_target template template0 owner postgres;')
        setup_defaults('acl_combined_source')
        sql('create schema extensions; alter default privileges for role supabase_admin grant all on tables to postgres with grant option; create extension postgis with schema extensions; alter default privileges for role supabase_admin revoke all on tables from postgres;','acl_combined_source')
        src_rel2=cat('relations','acl_combined_source');src_acl2=cat('relation_acl','acl_combined_source');src_ext2=cat('extensions','acl_combined_source')
        dump2=run(['exec',container,'pg_dump','-h','127.0.0.1','-U','supabase_admin','-d','acl_combined_source','-Fc'])
        run(['exec','-i',container,'pg_restore','-h','127.0.0.1','-U',operator,'-d','acl_combined_target','--single-transaction','--exit-on-error'],dump2)
        dst_rel2=cat('relations','acl_combined_target');dst_ext2=cat('extensions','acl_combined_target')
        members=json.loads(sql(wrapped("select n.nspname schema,c.relname name,e.extname from pg_depend d join pg_class c on d.classid='pg_class'::regclass and d.objid=c.oid join pg_namespace n on n.oid=c.relnamespace join pg_extension e on d.refclassid='pg_extension'::regclass and d.refobjid=e.oid where d.deptype='e' order by 1,2"),'acl_combined_target'))
        owner_plan=plan_relation_owner_recovery(src_rel2,dst_rel2,members,operator,src_ext2,dst_ext2)
        sql(owner_plan['sql'],'acl_combined_target')
        dst_rel2=cat('relations','acl_combined_target');dst_acl2=cat('relation_acl','acl_combined_target')
        original_diff=compare_relation_acl(src_acl2,dst_acl2)
        checks['combined_fixture_reproduces_67_missing_zero_additional']=sum(row['count'] for row in original_diff['missing_entries'])==67 and not original_diff['additional_entries']
        combined=classify_null_acl_representation(src_rel2,dst_rel2,src_acl2,dst_acl2,storage('acl_combined_target'),decode)
        verify_reviewed_representation(combined)
        checks['combined_normalization_removes_only_43_representation_entries']=combined['representation_entry_count']==43 and sum(row['count'] for row in combined['remaining_comparison']['missing_entries'])==24
        recovery=plan_postgis_acl_recovery(src_rel2,dst_rel2,src_acl2,combined['restored_acl_normalized'],members,src_ext2,dst_ext2,role_context_matches=True)
        checks['combined_plan_only_24_grants']=recovery['grant_count']==24
        sql(recovery['sql'],'acl_combined_target')
        after_acl2=cat('relation_acl','acl_combined_target')
        combined_after=classify_null_acl_representation(src_rel2,cat('relations','acl_combined_target'),src_acl2,after_acl2,storage('acl_combined_target'),decode)
        verify_reviewed_representation(combined_after)
        checks['combined_complete_normalized_acl_equals_source']=src_acl2==combined_after['restored_acl_normalized']
        checks['combined_24_grants_verified_individually']=all(after_acl2.count(grant)==1 and src_acl2.count(grant)==1 for grant in recovery['grants'])
        checks['combined_43_raw_acl_entries_remain_implicit']=combined_after['representation_entry_count']==43 and len(after_acl2)==len(src_acl2)-43
        result=dict(synthetic_only=True,real_backup_used=False,network='none',checks_passed=sum(checks.values()),checks_failed=sum(not value for value in checks.values()),checks=checks)
        output=Path(tempfile.mkdtemp(prefix='cercly-null-acl-tests-'))/'result.json';output.write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2));print('EVIDENCE='+str(output))
        if not all(checks.values()):raise SystemExit(1)
    finally:
        if started:run(['stop','--time','2',container])


if __name__=='__main__':main()
