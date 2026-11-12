"""Plan limitado para un destino aislado; no conecta ni ejecuta SQL.

Los propietarios proceden del inventario archivado, nunca de una inferencia
sobre el propietario de la extensión o de la base.
"""
import re

from cercly_backup_catalog import ident


MANAGED_RELATIONS = {
    ('extensions', 'geography_columns'): ('postgis', 'v'),
    ('extensions', 'geometry_columns'): ('postgis', 'v'),
    ('extensions', 'spatial_ref_sys'): ('postgis', 'r'),
    ('extensions', 'pg_stat_statements'): ('pg_stat_statements', 'v'),
    ('extensions', 'pg_stat_statements_info'): ('pg_stat_statements', 'v'),
    ('vault', 'decrypted_secrets'): ('supabase_vault', 'v'),
    ('vault', 'secrets'): ('supabase_vault', 'r'),
}


def relation_index(rows):
    result = {}
    for row in rows:
        key = (row['schema'], row['name'])
        if key in result:
            raise ValueError('DUPLICATE_RELATION_IDENTITY')
        result[key] = row
    return result


def compare_relations(source, restored):
    """Compara por identidad, sin descartar atributos, propietarios ni RLS."""
    left, right = relation_index(source), relation_index(restored)
    differences = []
    for key in sorted(left.keys() | right.keys()):
        a, b = left.get(key), right.get(key)
        if a == b:
            continue
        differences.append({
            'schema': key[0], 'name': key[1],
            'presence': 'missing' if b is None else 'additional' if a is None else 'both',
            'attributes': {
                field: {'source': a.get(field), 'restored': b.get(field)}
                for field in sorted(a.keys() | b.keys())
                if (field not in a or field not in b or a[field] != b[field])
            } if a is not None and b is not None else {},
        })
    return {'equivalent_catalog': not differences, 'differences': differences}


def plan_relation_owner_recovery(source, restored, target_memberships,
                                 operator, source_extensions, restored_extensions,
                                 *, pgstat_creation_evidence=None):
    """No suprime discrepancias: permite solo el defecto demostrado de siete objetos.

    Antes de ejecutar el plan deben consultarse nuevamente los catálogos del
    destino. Después se exige comparar relaciones, ACL y políticas completas.
    ALTER OWNER puede cambiar ACL implícitas y referencias al propietario;
    la equivalencia de permisos jamás se deduce del éxito del comando.
    """
    if not re.fullmatch(r'cercly_restore_operator_[a-f0-9]{8}', operator):
        raise ValueError('INVALID_LOCAL_MAINTENANCE_OPERATOR')
    if sorted(source_extensions, key=lambda x: x['extname']) != sorted(
            restored_extensions, key=lambda x: x['extname']):
        raise ValueError('EXTENSION_CATALOG_MISMATCH')
    memberships = relation_index(target_memberships)
    left, right = relation_index(source), relation_index(restored)
    comparison = compare_relations(source, restored)
    changes, statements = [], ['BEGIN;']
    for diff in comparison['differences']:
        key = (diff['schema'], diff['name'])
        if diff['presence'] != 'both' or key not in MANAGED_RELATIONS:
            raise ValueError('UNREVIEWED_RELATION_DIFFERENCE')
        a, b = left[key], right[key]
        extname, kind = MANAGED_RELATIONS[key]
        if set(diff['attributes']) != {'owner'}:
            raise ValueError('NON_OWNER_ATTRIBUTE_DIFFERENCE')
        # Con /etc/postgresql y session_preload_libraries=supautils, la imagen
        # crea estas dos vistas como supabase_admin incluso si el ejecutor es
        # nuestro operador. Exigir reproducción independiente en una BD vacía;
        # no aceptar supabase_admin como propietario alternativo general.
        proof = pgstat_creation_evidence or {}
        observed_pgstat_creator = (
            key in {('extensions', 'pg_stat_statements'), ('extensions', 'pg_stat_statements_info')}
            and a['owner'] == 'postgres' and b['owner'] == 'supabase_admin'
            and proof.get('session_user') == operator and proof.get('current_user') == operator
            and proof.get('extension') == {'extname': 'pg_stat_statements', 'extversion': '1.11',
                                          'schema': 'extensions', 'owner': 'supabase_admin'}
            and {'extname': 'pg_stat_statements', 'extversion': '1.11', 'schema': 'extensions'} in source_extensions
            and relation_index(proof.get('relations', [])).get(key) == b)
        if (b['owner'] != operator and not observed_pgstat_creator) or a['owner'] not in {'postgres', 'supabase_admin'}:
            raise ValueError('UNEXPECTED_RELATION_OWNER')
        if a['relkind'] != kind or memberships.get(key, {}).get('extname') != extname:
            raise ValueError('EXTENSION_MEMBERSHIP_OR_RELATION_KIND_MISMATCH')
        verb = 'VIEW' if kind == 'v' else 'TABLE'
        statements.append(f'ALTER {verb} {ident(key[0])}.{ident(key[1])} OWNER TO {ident(a["owner"])};')
        changes.append({'schema': key[0], 'name': key[1], 'owner': a['owner']})
    statements.append('COMMIT;')
    return {'owner_changes': changes, 'change_count': len(changes),
            'sql': '\n'.join(statements) + '\n',
            'requires_full_acl_policy_verification': True}
