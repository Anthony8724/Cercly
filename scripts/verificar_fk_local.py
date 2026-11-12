"""SQL de verificación referencial de solo lectura; sin conexión ni reparación."""
import re
from cercly_backup_catalog import ident

FK_INVENTORY = """select n.nspname schema,c.relname name,k.conname,k.convalidated,
 k.confmatchtype, pn.nspname parent_schema, pc.relname parent_name,
 (select jsonb_agg(jsonb_build_object('child',a.attname,'parent',p.attname,
 'operator_schema',onsp.nspname,'operator',op.oprname) order by pos)
 from generate_subscripts(k.conkey,1) pos
 join pg_attribute a on a.attrelid=k.conrelid and a.attnum=k.conkey[pos]
 join pg_attribute p on p.attrelid=k.confrelid and p.attnum=k.confkey[pos]
 join pg_operator op on op.oid=k.conpfeqop[pos]
 join pg_namespace onsp on onsp.oid=op.oprnamespace) pairs
 from pg_constraint k join pg_class c on c.oid=k.conrelid
 join pg_namespace n on n.oid=c.relnamespace
 join pg_class pc on pc.oid=k.confrelid join pg_namespace pn on pn.oid=pc.relnamespace
 where k.contype='f' and n.nspname !~ '^pg_' and n.nspname<>'information_schema'
 order by 1,2,3"""


def orphan_query(row):
    if row['confmatchtype'] not in ('s','f') or not row['pairs']:
        raise ValueError('UNSUPPORTED_FOREIGN_KEY_MATCH')
    tests=[];nulls=[];nonnulls=[]
    for pair in row['pairs']:
        operator=pair['operator']
        if not re.fullmatch(r'[+*/<>=~!@#%^&|`?\-]+',operator):
            raise ValueError('UNSUPPORTED_FOREIGN_KEY_OPERATOR')
        child='child.'+ident(pair['child']);parent='parent.'+ident(pair['parent'])
        tests.append(parent+' OPERATOR('+ident(pair['operator_schema'])+'.'+operator+') '+child)
        nulls.append(child+' IS NULL');nonnulls.append(child+' IS NOT NULL')
    missing='NOT EXISTS (SELECT 1 FROM '+ident(row['parent_schema'])+'.'+ident(row['parent_name'])+' parent WHERE '+' AND '.join(tests)+')'
    predicate=(' AND '.join(nonnulls)+' AND '+missing if row['confmatchtype']=='s' else
               '('+' OR '.join(nonnulls)+') AND (('+' OR '.join(nulls)+') OR '+missing+')')
    return ('BEGIN READ ONLY; SELECT count(*) FROM '+ident(row['schema'])+'.'+ident(row['name'])+
            ' child WHERE '+predicate+'; COMMIT;')
