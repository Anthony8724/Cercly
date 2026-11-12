"""Plan local cerrado: solo concesiones PostGIS presentes en el inventario.

No ejecuta SQL. No reconstruye por intuición ACL arbitrarias ni modifica ACL
de Vault/pg_stat_statements. Cualquier diferencia no revisada bloquea el plan.
"""
from cercly_backup_catalog import ident
from diagnostico_acl_relaciones_local import compare_relation_acl
from recuperar_propietarios_relaciones_local import compare_relations, relation_index

POSTGIS_RELATIONS = {'geography_columns', 'geometry_columns', 'spatial_ref_sys'}
PRIVILEGES = {'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN'}
ACL_FIELDS = {'schema', 'name', 'grantor', 'grantee', 'privilege_type', 'is_grantable'}


def plan_postgis_acl_recovery(source_relations, target_relations, source_acl, target_acl,
                              target_members, source_extensions, target_extensions,
                              *, role_context_matches):
    if role_context_matches is not True:
        raise ValueError('ROLE_CONTEXT_NOT_VERIFIED')
    if not compare_relations(source_relations, target_relations)['equivalent_catalog']:
        raise ValueError('RELATION_CATALOG_MISMATCH')
    if sorted(source_extensions, key=lambda row: row['extname']) != sorted(
            target_extensions, key=lambda row: row['extname']):
        raise ValueError('EXTENSION_CATALOG_MISMATCH')
    if not any(row['extname'] == 'postgis' and row['schema'] == 'extensions'
               for row in source_extensions):
        raise ValueError('POSTGIS_EXTENSION_NOT_VERIFIED')
    comparison = compare_relation_acl(source_acl, target_acl)
    if comparison['additional_entries']:
        raise ValueError('UNEXPECTED_ADDITIONAL_ACL')
    source = relation_index(source_relations)
    members = relation_index(target_members)
    statements = ['BEGIN;', 'SET LOCAL ROLE "supabase_admin";']
    grants = []
    for missing in comparison['missing_entries']:
        row = missing['entry']
        key = row['schema'], row['name']
        if (set(row) != ACL_FIELDS or missing['count'] != 1
                or row['schema'] != 'extensions' or row['name'] not in POSTGIS_RELATIONS
                or row['grantor'] != 'supabase_admin' or row['grantee'] != 'postgres'
                or row['is_grantable'] is not True or row['privilege_type'] not in PRIVILEGES
                or source.get(key, {}).get('owner') != 'supabase_admin'
                or members.get(key, {}).get('extname') != 'postgis'):
            raise ValueError('UNREVIEWED_MISSING_RELATION_ACL')
        # Fuente explícita con cobertura exacta del grupo que se permite reparar.
        archived = [entry for entry in source_acl if (entry['schema'], entry['name']) == key
                    and entry['grantor'] == 'supabase_admin' and entry['grantee'] == 'postgres']
        if (len(archived) != 8 or {entry['privilege_type'] for entry in archived} != PRIVILEGES
                or any(set(entry) != ACL_FIELDS or entry['is_grantable'] is not True for entry in archived)):
            raise ValueError('ARCHIVED_POSTGRES_GRANT_GROUP_NOT_VERIFIED')
        statements.append(f'GRANT {row["privilege_type"]} ON TABLE {ident(key[0])}.{ident(key[1])}'
                          ' TO "postgres" WITH GRANT OPTION;')
        grants.append(row)
    statements.extend(['RESET ROLE;', 'COMMIT;'])
    return {'grant_count': len(grants), 'grants': grants, 'sql': '\n'.join(statements) + '\n',
            'requires_exact_full_acl_verification': True}
