#!/usr/bin/env python3
"""Inspección offline de TOC/ACL y roles archivados; nunca restaura una base."""
import argparse,hashlib,json,os,re,shutil,socket,stat,subprocess,tarfile,tempfile,uuid
from pathlib import Path

IMAGE='public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'
BASE=Path('/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107')
BACKUP=BASE/'staging-database-bundle.tar.gpg'
DIAG=BASE/'restore-diagnostic-20261107T170758Z-cdaf959c-schemas.gpg'
EXPECTED='f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297'
SAFE={'postgres','supabase_admin','supabase_auth_admin','supabase_storage_admin','supabase_realtime_admin',
      'authenticator','anon','authenticated','service_role','pg_database_owner','pg_read_all_data',
      'pg_write_all_data','pg_monitor','pg_signal_backend','pg_read_all_settings','pg_read_all_stats',
      'pg_stat_scan_tables','supabase_replication_admin','supabase_read_only_user','dashboard_user','supabase_functions_admin'}

def safe_role(value):
    return value if value in SAFE or re.fullmatch(r'cercly_restore_operator_[a-f0-9]{8}',value) else '<rol privado>'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cipher-socket',required=True,type=Path)
    args=parser.parse_args();cipher_socket=args.cipher_socket.resolve()
    assert cipher_socket.is_relative_to(Path('/run/user')/str(os.getuid()))
    assert stat.S_ISSOCK(cipher_socket.stat().st_mode) and cipher_socket.stat().st_mode&0o077==0
    assert cipher_socket.parent.stat().st_mode&0o077==0
    os.umask(0o077)
    scratch=Path(tempfile.mkdtemp(prefix='cercly-staging-restore-inspection-',dir='/run/user/'+str(os.getuid())))
    env={k:v for k,v in os.environ.items() if k not in ('CONTAINER_HOST','CONTAINER_CONNECTION','DOCKER_HOST','PGPASSWORD','PGSERVICE','PGSERVICEFILE','PGPASSFILE')}
    stage='integrity'
    def cipher(operation,source=None,target=None):
        request={'operation':operation}
        if source is not None:request.update(source=str(source),target=str(target))
        with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as s:
            s.connect(str(cipher_socket));s.sendall((json.dumps(request)+'\n').encode());data=b''
            while not data.endswith(b'\n'):
                part=s.recv(65536)
                if not part:raise RuntimeError('Agente privado desconectado')
                data+=part
            if not json.loads(data)['ok']:raise RuntimeError('Operación privada de cifrado fallida')
    def archive_command(options):
        r=subprocess.run(['podman','--remote=false','run','--rm','--pull=never','--network','none',
          '--read-only','--log-driver=none','-v',str(scratch)+':/inspection:ro,Z','--entrypoint','pg_restore',IMAGE,
          *options,'/inspection/database.dump'],capture_output=True,env=env,timeout=120)
        if r.returncode:raise RuntimeError('pg_restore de inspección exit='+str(r.returncode))
        return r.stdout.decode()
    try:
        assert hashlib.sha256(BACKUP.read_bytes()).hexdigest()==EXPECTED
        cipher('decrypt',BACKUP,scratch/'bundle.tar')
        cipher('decrypt',DIAG,scratch/'schema-diagnostic-private.json')
        with tarfile.open(scratch/'bundle.tar') as t:
            names={'database.dump','roles-no-passwords.sql','snapshot-catalog.json','snapshot-data.json','manifest.json'}
            assert len(t.getmembers())==len(names) and set(t.getnames())==names and all(x.isfile() for x in t.getmembers())
            manifest=json.load(t.extractfile('manifest.json'));assert manifest['project_ref']=='dlajxviqhkdcqnmczhvr'
            for name,digest in manifest['files'].items():
                data=t.extractfile(name).read();assert hashlib.sha256(data).hexdigest()==digest
                if name!='snapshot-data.json':
                    (scratch/name).write_bytes(data);os.chmod(scratch/name,0o600)
        original=json.loads((scratch/'snapshot-catalog.json').read_text())
        diag=json.loads((scratch/'schema-diagnostic-private.json').read_text())
        stage='toc_list'
        toc=archive_command(['--list']);selected=[];acl_lines=[];schema_lines=[];db_lines=[];ext_lines=[]
        for line in toc.splitlines():
            if not re.match(r'^\d+;',line):continue
            if re.search(r'\bACL - SCHEMA (?:graphql|graphql_public)(?: |$)',line):acl_lines.append(line);selected.append(line)
            elif re.search(r'\bSCHEMA - (?:graphql|graphql_public)(?: |$)',line):schema_lines.append(line);selected.append(line)
            elif re.search(r'\bEXTENSION - pg_graphql(?: |$)',line):ext_lines.append(line);selected.append(line)
            elif re.search(r'\bDATABASE(?: PROPERTIES)? - ',line):db_lines.append(line);selected.append(line)
        (scratch/'selected.toc').write_text('\n'.join(selected)+'\n')
        stage='selected_acl_sql'
        sql=archive_command(['--use-list=/inspection/selected.toc','--file=-']) if selected else ''
        # El filtro TOC limita el SQL a esquemas/ACL/extension/propiedades de base.
        grant_statements=re.findall(r'\bGRANT\s+[^;]+\bON\s+SCHEMA\s+"?(?:graphql|graphql_public)"?\s+TO\s+[^;]+;',sql,re.IGNORECASE)
        revoke_statements=re.findall(r'\bREVOKE\s+[^;]+\bON\s+SCHEMA\s+"?(?:graphql|graphql_public)"?\s+FROM\s+[^;]+;',sql,re.IGNORECASE)
        role_diffs=[];left={x['rolname']:x for x in diag['source_roles']};right={x['rolname']:x for x in diag['restored_roles']}
        for role in sorted(left.keys()|right.keys()):
            if role not in left or role not in right:
                role_diffs.append({'role':role,'presence':'missing' if role not in right else 'extra'})
            else:
                fields={k:{'source':left[role].get(k),'restored':right[role].get(k)} for k in left[role] if left[role].get(k)!=right[role].get(k)}
                if fields:role_diffs.append({'role':role,'fields':fields})
        key=lambda x:json.dumps(x,sort_keys=True)
        src={key(x):x for x in diag['source_memberships']};dst={key(x):x for x in diag['restored_memberships']}
        missing=[src[x] for x in sorted(src.keys()-dst.keys())];extra=[dst[x] for x in sorted(dst.keys()-src.keys())]
        def safe_member(x):return {k:safe_role(v) if k in ('role','member','grantor') else v for k,v in x.items()}
        safe_roles=[{'role':safe_role(x['role']),'presence':x['presence']} if 'presence' in x else {'role':safe_role(x['role']),'different_attributes':list(x['fields'])} for x in role_diffs]
        db_owner=None
        for line in db_lines:
            match=re.search(r'\bDATABASE - postgres ([a-z_][a-z_0-9]*)$',line)
            if match:db_owner=match.group(1)
        detail={'toc_selected':selected,'selected_sql':sql,'acl_grants':grant_statements,'acl_revokes':revoke_statements,
                'role_differences':role_diffs,'missing_memberships':missing,'extra_memberships':extra,
                'source_schemas':original['schemas'],'source_extensions':original['extensions'],
                'source_database_owner_from_toc':db_owner}
        (scratch/'inspection-private.json').write_text(json.dumps(detail,indent=2)+'\n')
        identifier=uuid.uuid4().hex[:12];encrypted=BASE/('restore-diagnostic-inspection-'+identifier+'.gpg')
        cipher('encrypt_diagnostic',scratch/'inspection-private.json',encrypted)
        summary={'backup_sha256':EXPECTED,'network':'none','database_restore_performed':False,
            'graphql_schema_toc_entries':len(schema_lines),'graphql_acl_toc_entries':len(acl_lines),
            'graphql_extension_toc_entries':len(ext_lines),'graphql_schema_grant_statements':len(grant_statements),
            'graphql_schema_revoke_statements':len(revoke_statements),'database_toc_entries':len(db_lines),
            'source_database_owner_from_toc':safe_role(db_owner) if db_owner else None,
            'role_attribute_or_presence_differences':safe_roles,
            'memberships_missing':list(map(safe_member,missing)),'memberships_extra':list(map(safe_member,extra)),
            'encrypted_evidence':str(encrypted)}
        public=BASE/('acl-inspection-'+identifier+'.json');public.write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps(summary,indent=2),flush=True);print('Informe saneado: '+str(public),flush=True)
    except Exception as e:
        print('INSPECTION_STOPPED; stage='+stage+'; '+str(e),flush=True);raise SystemExit(1)
    finally:
        try:cipher('stop')
        except Exception:pass
        shutil.rmtree(scratch)

if __name__=='__main__':main()
