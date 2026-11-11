"""Comparación estricta y diagnóstico privado de esquemas PostgreSQL.

No conecta a bases. decode_acl lo ejecuta el llamador exclusivamente en su
instancia local. Los resultados detallados deben cifrarse; no imprimirlos.
"""
import json


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def acl_decode_query(row, role_names):
    """PostgreSQL interpreta aclitem[], nombres citados y defaults implícitos."""
    owner = literal('"' + row['owner'].replace('"', '""') + '"')
    acl = 'NULL::aclitem[]' if row['acl'] is None else literal(row['acl']) + '::aclitem[]'
    roles = ','.join(literal(x) for x in sorted(role_names))
    return f"""begin read only; set local standard_conforming_strings=on;
    set local search_path=pg_catalog;
    with a as (select coalesce({acl},acldefault('n',{owner}::regrole::oid)) value),
    g as (select x.* from a cross join lateral aclexplode(case when cardinality(a.value)=0 then null::aclitem[] else a.value end) x),
    grants as (select pg_get_userbyid(grantor) grantor,
      case when grantee=0 then 'public' else 'role' end grantee_kind,
      case when grantee=0 then 'PUBLIC' else pg_get_userbyid(grantee) end grantee,
      privilege_type,is_grantable from g order by 1,2,3,4,5),
    effective as (select r.rolname,
      r.rolsuper or exists(select 1 from g where privilege_type='USAGE' and
        case when grantee=0 then true else pg_has_role(r.oid,grantee,'USAGE') end) usage,
      r.rolsuper or exists(select 1 from g where privilege_type='CREATE' and
        case when grantee=0 then true else pg_has_role(r.oid,grantee,'USAGE') end) create_objects
      from pg_roles r where r.rolname in ({roles or "''"}) order by r.rolname)
    select json_build_object(
      'grants',coalesce((select jsonb_agg(to_jsonb(x)) from grants x),'[]'),
      'effective_usage_create',coalesce((select jsonb_agg(to_jsonb(x)) from effective x),'[]'));
    commit;"""


def _key(row):
    return json.dumps(row, sort_keys=True, ensure_ascii=False)


def compare_schemas(source, restored, decode_acl):
    """El orden no importa; propietario, grantor, grants y grant options sí."""
    def index(rows):
        result = {}
        for row in rows:
            if set(row) != {'nspname','owner','acl'} or row['nspname'] in result:
                raise ValueError('Catálogo ambiguo o forma no soportada')
            result[row['nspname']] = row
        return result
    left, right = index(source), index(restored)
    result = {'equivalent_catalog': True, 'differences': [], 'representation_only': [],
              'missing_schemas': sorted(left.keys()-right.keys()),
              'extra_schemas': sorted(right.keys()-left.keys())}
    for name in sorted(left.keys() & right.keys()):
        original, actual = left[name], right[name]
        a, b = decode_acl(original), decode_acl(actual)
        ga, gb = sorted(a['grants'], key=_key), sorted(b['grants'], key=_key)
        attributes = {}
        if original['owner'] != actual['owner']:
            attributes['owner'] = {'source': original['owner'], 'restored': actual['owner']}
        if ga != gb:
            attributes['acl_grants'] = {'missing': [x for x in ga if x not in gb],
                                        'extra': [x for x in gb if x not in ga]}
        if a['effective_usage_create'] != b['effective_usage_create']:
            attributes['effective_usage_create'] = {
                'source_projection': a['effective_usage_create'],
                'restored_projection': b['effective_usage_create']}
        # Las proyecciones usan el grafo LOCAL. No prueban el grafo original
        # ni el propietario de base original si el backup no los acredita.
        if attributes:
            result['differences'].append({'schema': name, 'attributes': attributes,
                'source_raw': original, 'restored_raw': actual})
        elif original['acl'] != actual['acl']:
            result['representation_only'].append(name)
    result['equivalent_catalog'] = not (result['differences'] or result['missing_schemas'] or result['extra_schemas'])
    result['summary'] = {'source_count': len(left), 'restored_count': len(right),
        'missing_count': len(result['missing_schemas']), 'extra_count': len(result['extra_schemas']),
        'owner_difference_count': sum('owner' in x['attributes'] for x in result['differences']),
        'acl_difference_count': sum('acl_grants' in x['attributes'] for x in result['differences']),
        'effective_usage_create_difference_count': sum('effective_usage_create' in x['attributes'] for x in result['differences']),
        'representation_only_count': len(result['representation_only'])}
    return result


def public_schema_details(result):
    """Solo identificadores públicos conocidos; todo lo demás queda en el cifrado."""
    schemas={'public','auth','storage','extensions','graphql','graphql_public','realtime',
             'vault','net','cron','pgsodium','pgsodium_masks','supabase_functions',
             'supabase_migrations','cercly_auth_private','cercly_account_private','staging'}
    roles={'postgres','supabase_admin','supabase_auth_admin','supabase_storage_admin',
           'supabase_realtime_admin','pg_database_owner','authenticator','anon',
           'authenticated','service_role','PUBLIC'}
    def role(name):
        import re
        return name if name in roles or re.fullmatch(r'cercly_restore_operator_[a-f0-9]{8}',name) else '<rol privado>'
    def grant(item):
        return {k:role(v) if k in ('grantor','grantee') else v for k,v in item.items()}
    details=[]
    for item in result['differences']:
        safe={'schema':item['schema'] if item['schema'] in schemas else '<esquema privado>',
              'attributes':list(item['attributes'])}
        if 'owner' in item['attributes']:safe['owner']={k:role(v) for k,v in item['attributes']['owner'].items()}
        if 'acl_grants' in item['attributes']:
            safe['acl_grants']={k:[grant(g) for g in values] for k,values in item['attributes']['acl_grants'].items()}
        details.append(safe)
    return details
