#!/usr/bin/env python3
"""Reproduce omisión de ACL iniciales PostGIS; exclusivamente datos sintéticos."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

from cercly_backup_catalog import QUERIES, wrapped
from diagnostico_acl_relaciones_local import compare_relation_acl, relation_security_diagnostic
from recuperar_acl_relaciones_local import plan_postgis_acl_recovery
from recuperar_propietarios_relaciones_local import plan_relation_owner_recovery
from test_correcciones_local import IMAGE
from sql_local_session import clean_environment


def main():
    os.umask(0o077)
    name = 'cercly-postgis-acl-test-' + uuid.uuid4().hex[:10]
    operator = 'cercly_restore_operator_' + uuid.uuid4().hex[:8]
    env = clean_environment()
    checks = {}
    started = False

    def run(options, data=None):
        result = subprocess.run(['podman', '--remote=false', *options], input=data,
                                capture_output=True, env=env, timeout=180)
        if result.returncode:
            # Solo SQL sintético; ni credenciales ni datos reales entran al contenedor.
            raise RuntimeError('SYNTHETIC_COMMAND_FAILED_' + str(result.returncode)
                               + ': ' + result.stderr.decode())
        return result.stdout

    def sql(query, database='postgres', user='supabase_admin'):
        return run(['exec', '-i', name, 'psql', '-X', '-qAt', '-h', '127.0.0.1',
                    '-U', user, '-d', database, '--set=ON_ERROR_STOP=1'], query.encode()).decode().strip()

    def cat(label, database):
        return json.loads(sql(wrapped(QUERIES[label]), database))

    def plan(acl=None, **changes):
        arguments = dict(source_relations=source, target_relations=target,
                         source_acl=source_acl, target_acl=target_acl if acl is None else acl,
                         target_members=members, source_extensions=extensions,
                         target_extensions=target_extensions, role_context_matches=True)
        arguments.update(changes)
        return plan_postgis_acl_recovery(**arguments)

    def rejects(label, **changes):
        try:
            plan(**changes)
        except ValueError:
            checks[label] = True
        else:
            checks[label] = False

    try:
        run(['run', '-d', '--rm', '--pull=never', '--network', 'none', '--log-driver=none',
             '--name', name, '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', IMAGE,
             'postgres', '-c', 'cron.launch_active_jobs=off'])
        started = True
        for _ in range(120):
            ready = subprocess.run(['podman', '--remote=false', 'exec', name, 'pg_isready',
                                    '-h', '127.0.0.1', '-U', 'supabase_admin'],
                                   capture_output=True, env=env)
            if ready.returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('SYNTHETIC_SERVER_TIMEOUT')
        checks['network_none'] = run(['inspect', name, '--format', '{{.HostConfig.NetworkMode}}']).strip() == b'none'
        sql('create role ' + operator + ' login superuser; '
            'create database acl_source template template0 owner postgres; '
            'create database acl_target template template0 owner postgres;')
        sql('create schema extensions; '
            'alter default privileges for role supabase_admin grant all on tables to postgres with grant option; '
            'create extension postgis with schema extensions; '
            'alter default privileges for role supabase_admin revoke all on tables from postgres; '
            'create table public.fixture(id int); alter table public.fixture owner to postgres; '
            'insert into public.fixture values(42); alter table public.fixture enable row level security; '
            'create policy fixture_select on public.fixture for select to anon using(false); '
            'grant select on public.fixture to anon;', 'acl_source')
        source = cat('relations', 'acl_source')
        source_acl = cat('relation_acl', 'acl_source')
        source_columns = cat('column_acl', 'acl_source')
        source_policies = cat('policies', 'acl_source')
        extensions = cat('extensions', 'acl_source')
        checks['synthetic_initial_privileges_include_24_postgres_grant_options'] = sql(
            "select count(*) from pg_init_privs i join pg_class c on i.classoid='pg_class'::regclass and i.objoid=c.oid join pg_namespace n on c.relnamespace=n.oid cross join lateral aclexplode(i.initprivs) a where n.nspname='extensions' and c.relname in ('geography_columns','geometry_columns','spatial_ref_sys') and i.privtype='e' and pg_get_userbyid(a.grantee)='postgres' and a.is_grantable;",
            'acl_source') == '24'
        dump = run(['exec', name, 'pg_dump', '-h', '127.0.0.1', '-U', 'supabase_admin', '-d', 'acl_source', '-Fc'])
        toc = run(['exec', '-i', name, 'pg_restore', '--list'], dump).decode()
        checks['postgis_acl_not_serialized_in_native_dump'] = not any(
            ' ACL extensions TABLE ' + relation + ' ' in toc
            for relation in ('geography_columns', 'geometry_columns', 'spatial_ref_sys'))
        run(['exec', '-i', name, 'pg_restore', '-h', '127.0.0.1', '-U', operator,
             '-d', 'acl_target', '--single-transaction', '--exit-on-error'], dump)
        target = cat('relations', 'acl_target')
        target_extensions = cat('extensions', 'acl_target')
        members = json.loads(sql(wrapped("select n.nspname schema,c.relname name,e.extname from pg_depend d join pg_class c on d.classid='pg_class'::regclass and d.objid=c.oid join pg_namespace n on n.oid=c.relnamespace join pg_extension e on d.refclassid='pg_extension'::regclass and d.refobjid=e.oid where d.deptype='e' order by 1,2"), 'acl_target'))
        owner_plan = plan_relation_owner_recovery(source, target, members, operator, extensions, target_extensions)
        checks['three_postgis_owners_need_recovery'] = owner_plan['change_count'] == 3
        before_acl = cat('relation_acl', 'acl_target')
        sql(owner_plan['sql'], 'acl_target', operator)
        target = cat('relations', 'acl_target')
        target_acl = cat('relation_acl', 'acl_target')
        def relevant_postgres(rows):
            return [row for row in rows if row['schema'] == 'extensions'
                    and row['name'] in ('geography_columns', 'geometry_columns', 'spatial_ref_sys')
                    and row['grantee'] == 'postgres']
        checks['grants_absent_before_owner_change_not_revoked_by_alter_owner'] = (
            len(relevant_postgres(source_acl)) == 24
            and not relevant_postgres(before_acl) and not relevant_postgres(target_acl))
        comparison = compare_relation_acl(source_acl, target_acl)
        checks['owner_recovery_preserves_missing_24_grant_options'] = (
            len(comparison['missing_entries']) == 24 and not comparison['additional_entries']
            and all(entry['entry']['grantor'] == 'supabase_admin'
                    and entry['entry']['grantee'] == 'postgres'
                    and entry['entry']['is_grantable'] is True
                    for entry in comparison['missing_entries']))
        original = dict(relations=source, relation_acl=source_acl,
                        column_acl=source_columns, policies=source_policies)
        restored = dict(relations=target, relation_acl=target_acl,
                        column_acl=cat('column_acl', 'acl_target'), policies=cat('policies', 'acl_target'))
        before = dict(restored, relation_acl=before_acl)
        detail = json.loads(relation_security_diagnostic(original, restored, before))
        checks['exact_missing_rows_and_before_after_are_captured'] = (
            len(detail['acl_comparison']['missing_entries']) == 24
            and detail['before_owner_recovery']['relation_acl'] == before_acl)
        recovery = plan()
        checks['limited_plan_24_only_archived_grants'] = (
            recovery['grant_count'] == 24 and 'REVOKE' not in recovery['sql']
            and 'ALL PRIVILEGES' not in recovery['sql'] and 'SET LOCAL ROLE "supabase_admin"' in recovery['sql'])
        roles_before, memberships_before = cat('roles', 'acl_target'), cat('memberships', 'acl_target')
        try:
            sql(recovery['sql'].replace('COMMIT;', 'SELECT 1/0; COMMIT;'), 'acl_target', operator)
        except RuntimeError:
            checks['transaction_error_reported'] = True
        else:
            checks['transaction_error_reported'] = False
        checks['failed_acl_transaction_rolls_back'] = target_acl == cat('relation_acl', 'acl_target')
        sql(recovery['sql'], 'acl_target', operator)
        after_acl = cat('relation_acl', 'acl_target')
        checks['exact_acl_after_recovery_including_order'] = source_acl == after_acl
        checks['exact_owners_unchanged'] = source == cat('relations', 'acl_target')
        checks['grantor_and_grant_options_match'] = compare_relation_acl(source_acl, after_acl)['same_entries_including_multiplicity']
        checks['no_role_or_membership_changes'] = roles_before == cat('roles', 'acl_target') and memberships_before == cat('memberships', 'acl_target')
        checks['columns_and_policies_unchanged'] = source_columns == cat('column_acl', 'acl_target') and source_policies == cat('policies', 'acl_target')
        checks['fixture_data_preserved'] = sql('select count(*)=1 and min(id)=42 from public.fixture;', 'acl_target') == 't'
        checks['unauthorized_write_denied'] = sql("select not has_table_privilege('anon','public.fixture','UPDATE') and not has_table_privilege('anon','extensions.spatial_ref_sys','UPDATE');", 'acl_target') == 't'
        checks['unauthorized_rows_hidden_by_rls'] = sql('set role anon; select count(*) from public.fixture;', 'acl_target') == '0'
        checks['idempotent_plan'] = plan(acl=after_acl)['grant_count'] == 0
        rejects('rejects_unverified_roles', role_context_matches=False)
        rejects('rejects_extra_grant', acl=target_acl + [dict(comparison['missing_entries'][0]['entry'], grantee='anon')])
        rejects('rejects_changed_grantor', acl=target_acl + [dict(comparison['missing_entries'][0]['entry'], grantor='postgres')])
        rejects('rejects_changed_grant_option', acl=target_acl + [dict(comparison['missing_entries'][0]['entry'], is_grantable=False)])
        mutated = copy.deepcopy(target)
        next(row for row in mutated if row['name'] == 'spatial_ref_sys')['owner'] = 'postgres'
        rejects('rejects_owner_mismatch', target_relations=mutated)
        mutated = copy.deepcopy(members)
        next(row for row in mutated if row['name'] == 'spatial_ref_sys')['extname'] = 'other'
        rejects('rejects_wrong_extension_membership', target_members=mutated)
        rejects('rejects_extension_version', target_extensions=[dict(row, extversion='0.0') for row in target_extensions])
        rejects('rejects_unreviewed_relation_missing_acl', acl=[row for row in target_acl if row['schema'] != 'public'])
        mutated = copy.deepcopy(source_acl)
        next(row for row in mutated if row['name'] == 'spatial_ref_sys' and row['grantee'] == 'postgres')['is_grantable'] = False
        rejects('rejects_unreviewed_source_grant_option', source_acl=mutated)
        result = dict(synthetic_only=True, real_backup_used=False, network='none',
                      checks_passed=sum(checks.values()), checks_failed=sum(not value for value in checks.values()), checks=checks)
        evidence = Path(tempfile.mkdtemp(prefix='cercly-postgis-acl-synthetic-')) / 'result.json'
        evidence.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result, indent=2))
        print('EVIDENCE=' + str(evidence))
        if not all(checks.values()):
            raise SystemExit(1)
    finally:
        if started:
            run(['stop', '--time', '2', name])


if __name__ == '__main__':
    main()
