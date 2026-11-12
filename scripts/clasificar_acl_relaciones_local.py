"""Clasifica solo normalización acreditada de ACL NULL; no concede permisos."""
from comparar_esquemas_respaldo import literal
from diagnostico_acl_relaciones_local import compare_relation_acl
from recuperar_propietarios_relaciones_local import compare_relations, relation_index

REVIEWED_DEFAULT_RELATIONS = {
    ('cercly_account_private', 'auditoria_eliminacion'): 'r',
    ('cercly_account_private', 'solicitudes_eliminacion'): 'r',
    ('cercly_auth_private', 'auditoria_superadministradores'): 'r',
    ('cercly_auth_private', 'superadministradores'): 'r',
    ('staging', 'importacion_establecimientos_osm'): 'r',
    ('staging', 'importacion_establecimientos_osm_id_seq'): 'S',
}


def relation_acl_decode_query(raw_acl, owner, kind):
    if kind not in ('r', 'p', 'v', 'm', 'S'):
        raise ValueError('UNSUPPORTED_RELATION_KIND')
    acl = 'NULL::aclitem[]' if raw_acl is None else literal(raw_acl) + '::aclitem[]'
    quoted_owner = literal('"' + owner.replace('"', '""') + '"')
    acl_kind = 's' if kind == 'S' else 'r'
    return f"""begin read only; set local standard_conforming_strings=on;
    set local search_path=pg_catalog;
    with acl_value as (select coalesce({acl},acldefault('{acl_kind}',{quoted_owner}::regrole::oid)) value)
    select coalesce(jsonb_agg(to_jsonb(x) order by grantor,grantee,privilege_type,is_grantable),'[]'::jsonb)
    from (select pg_get_userbyid(a.grantor) grantor,
      case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end grantee,
      a.privilege_type,a.is_grantable
      from acl_value cross join lateral aclexplode(
        case when cardinality(value)=0 then NULL::aclitem[] else value end) a) x;
    commit;"""


def classify_null_acl_representation(source_relations, restored_relations,
                                     source_acl, restored_acl, target_storage, decode_acl):
    """No infiere derechos por ser owner. Compara todos los grants con acldefault.

    Solo normaliza si la fuente tiene ACL explícita NO vacía y el destino tiene
    relacl NULL acreditado. Fuente sin filas sigue siendo ambigua (NULL vs {}).
    El callback usa el parser PostgreSQL correspondiente; no simplifica grantor
    ni grant option. Los originales permanecen sin modificar.
    """
    if not compare_relations(source_relations, restored_relations)['equivalent_catalog']:
        raise ValueError('RELATION_CATALOG_MISMATCH')
    relations = relation_index(source_relations)
    storage = relation_index(target_storage)
    # Validar filas y mantener atributos desconocidos y multiplicidades.
    compare_relation_acl(source_acl, restored_acl)
    normalized = list(restored_acl)
    classifications = []
    ambiguous = []
    for key, original_relation in sorted(relations.items()):
        original = [row for row in source_acl if (row['schema'], row['name']) == key]
        actual = [row for row in restored_acl if (row['schema'], row['name']) == key]
        if not original:
            ambiguous.append(dict(schema=key[0], name=key[1],
                                  reason='Source raw ACL NULL vs explicit empty was not archived'))
        if original == actual:
            continue
        raw = storage.get(key)
        if raw is None or raw.get('owner') != original_relation['owner']:
            raise ValueError('MISSING_OR_INCONSISTENT_ACL_STORAGE')
        item = dict(schema=key[0], name=key[1], relkind=original_relation['relkind'],
                    source_owner=original_relation['owner'], restored_owner=raw['owner'],
                    target_acl_is_null=raw['raw_acl'] is None,
                    source_explicit=original, target_explicit=actual,
                    classification='unresolved_or_security_difference')
        if original and not actual and raw['raw_acl'] is None:
            defaults = [dict(schema=key[0], name=key[1], **entry)
                        for entry in decode_acl(None, raw['owner'], original_relation['relkind'])]
            item['default_acl_comparison'] = compare_relation_acl(original, defaults)
            item['target_normalized_defaults'] = defaults
            if item['default_acl_comparison']['same_entries_including_multiplicity']:
                item.update(classification='representation_explicit_vs_null_default',
                            target_normalized_defaults=defaults, needs_grant_or_revoke=False)
                normalized.extend(defaults)
        classifications.append(item)
    remaining = compare_relation_acl(source_acl, normalized)
    normalized.sort(key=lambda row: (row['schema'],row['name'],row['grantor'],row['grantee'],
                                    row['privilege_type'],row['is_grantable']))
    return dict(classifications=classifications, restored_acl_normalized=normalized,
                remaining_comparison=remaining,
                ambiguous_source_empty_acl=ambiguous,
                representation_entry_count=sum(len(row['source_explicit']) for row in classifications
                    if row['classification'] == 'representation_explicit_vs_null_default'),
                scope='Object ACL equivalence; effective access also requires matching roles, RLS, columns and database context')


def verify_reviewed_representation(classification):
    """El restaurador solo acepta los seis casos acreditados; ningún SQL correctivo."""
    for row in classification['classifications']:
        if row['classification'] != 'representation_explicit_vs_null_default':
            continue
        key = row['schema'], row['name']
        if (REVIEWED_DEFAULT_RELATIONS.get(key) != row['relkind']
                or row['source_owner'] != 'postgres' or row['restored_owner'] != 'postgres'):
            raise ValueError('UNREVIEWED_NULL_ACL_NORMALIZATION')
