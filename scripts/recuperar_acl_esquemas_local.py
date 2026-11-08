"""Plan limitado de recuperación de ACL archivadas; no conecta ni ejecuta SQL."""
from comparar_esquemas_respaldo import compare_schemas
from cercly_backup_catalog import ident


def plan_graphql_acl_recovery(source, restored, decode_acl):
    result = compare_schemas(source, restored, decode_acl)
    if result['missing_schemas'] or result['extra_schemas']:
        raise ValueError('Esquemas faltantes/adicionales: requiere diagnóstico')
    commands = ['begin;']
    count = 0
    for difference in result['differences']:
        name, attrs = difference['schema'], difference['attributes']
        if name not in ('graphql','graphql_public') or 'owner' in attrs:
            raise ValueError('La recuperación limitada no cambia propietarios ni otros esquemas')
        grants = attrs.get('acl_grants', {})
        if grants.get('extra'):
            raise ValueError('Privilegios adicionales: no se revocan ni ignoran automáticamente')
        if difference['source_raw']['owner'] != 'supabase_admin':
            raise ValueError('Grantor/propietario no soportado por este plan limitado')
        for grant in grants.get('missing', []):
            if (grant['grantor'] != 'supabase_admin' or grant['grantee_kind'] != 'role'
                or grant['privilege_type'] != 'USAGE'
                or grant['grantee'] not in ('anon','authenticated','service_role','postgres')
                or grant['is_grantable'] != (grant['grantee'] == 'postgres')):
                raise ValueError('Concesión fuera del alcance revisado')
            commands.append('set local role '+ident(grant['grantor'])+';')
            commands.append('grant usage on schema '+ident(name)+' to '+ident(grant['grantee'])
                + (' with grant option' if grant['is_grantable'] else '') + ';')
            commands.append('reset role;')
            count += 1
    commands.append('commit;')
    return {'grant_count':count, 'sql':'\n'.join(commands)+'\n'}
