"""Diagnóstico estricto de ACL archivadas; no ejecuta GRANT ni REVOKE.

El orden SQL puede depender de la collation de cada base. Se informa por
separado del contenido: nunca se descartan grantor, grant option, duplicados
ni atributos desconocidos. Este módulo no autoriza reparaciones automáticas.
"""
from collections import Counter
import json

from recuperar_propietarios_relaciones_local import compare_relations


def _encode(row):
    return json.dumps(row, sort_keys=True, ensure_ascii=False, separators=(',', ':'),
                      allow_nan=False)


def _entries(rows):
    for row in rows:
        if not isinstance(row, dict) or not {
            'schema', 'name', 'grantor', 'grantee', 'privilege_type', 'is_grantable'
        }.issubset(row):
            raise ValueError('INCOMPLETE_RELATION_ACL_ROW')
        if type(row['is_grantable']) is not bool:
            raise ValueError('INVALID_GRANT_OPTION')
        if any(not isinstance(row[k], str) or not row[k] for k in
               ('schema', 'name', 'grantor', 'grantee', 'privilege_type')):
            raise ValueError('INVALID_RELATION_ACL_IDENTITY')
    return Counter(_encode(row) for row in rows)


def compare_relation_acl(source, restored):
    """Multiconjunto exacto; solo clasifica, no cambia el criterio del restaurador."""
    left, right = _entries(source), _entries(restored)
    def expand(counts):
        return [dict(entry=json.loads(key), count=count)
                for key, count in sorted(counts.items())]
    missing, additional = left - right, right - left
    return {
        'same_entries_including_multiplicity': left == right,
        'same_order': source == restored,
        'order_only': left == right and source != restored,
        'missing_entries': expand(missing),
        'additional_entries': expand(additional),
        'different_relations': [dict(schema=schema, name=name) for schema, name in
            sorted({(json.loads(key)['schema'], json.loads(key)['name'])
                    for key in missing.keys() | additional.keys()})],
    }


def relation_security_diagnostic(source, restored, before_owner=None,
                                 target_acl_storage=None):
    """Contenido privado: entregar solo al agente de cifrado, nunca a stdout."""
    detail = {
        'catalog': 'relation_acl_after_owner_recovery',
        'source': {key: source[key] for key in
                   ('relations', 'relation_acl', 'column_acl', 'policies')},
        'restored': {key: restored[key] for key in
                     ('relations', 'relation_acl', 'column_acl', 'policies')},
        'relations_comparison': compare_relations(source['relations'], restored['relations']),
        'acl_comparison': compare_relation_acl(source['relation_acl'], restored['relation_acl']),
        'before_owner_recovery': before_owner,
        'target_acl_storage_after_owner': target_acl_storage,
        'coverage_limits': [
            'Source relation_acl contains exploded explicit ACL only, not raw relacl.',
            'No rows cannot distinguish source NULL/default ACL from explicit empty ACL.',
            'Source pseudo-grantee PUBLIC is not distinguished from a quoted role PUBLIC.',
            'Effective rights require verified roles, memberships, ownership and RLS.',
            'Original database owner/ACL/configuration and extension owners remain unrecorded.',
        ],
    }
    if before_owner is not None:
        detail['owner_change_acl_comparison'] = compare_relation_acl(
            before_owner['relation_acl'], restored['relation_acl'])
    return json.dumps(detail, ensure_ascii=False, indent=2, allow_nan=False).encode()
