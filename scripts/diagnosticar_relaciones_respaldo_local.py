#!/usr/bin/env python3
"""Diagnóstico del intento 20261107T173236Z-80c424ec; sin restaurar ni conectar a Supabase."""

def main():
    import sys,os,pathlib,hashlib,json,socket,tempfile,shutil,tarfile,subprocess,re
    from inspeccionar_acl_dump_local import IMAGE,safe_role
    os.umask(0o077)
    base=pathlib.Path('/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107')
    backup=base/'staging-database-bundle.tar.gpg'
    diag=base/'restore-diagnostic-20261107T173236Z-80c424ec.gpg'
    import argparse
    parser=argparse.ArgumentParser(description='Inspección offline de la discrepancia real de relaciones; no restaura datos')
    parser.add_argument('--cipher-socket',required=True,type=pathlib.Path)
    args=parser.parse_args()
    sock=args.cipher_socket.resolve()
    import stat
    assert sock.is_relative_to(pathlib.Path('/run/user')/str(os.getuid()))
    assert stat.S_ISSOCK(sock.stat().st_mode) and sock.stat().st_uid==os.getuid() and sock.stat().st_mode&0o077==0
    assert sock.parent.stat().st_mode&0o077==0
    scratch=pathlib.Path(tempfile.mkdtemp(prefix='cercly-staging-restore-relations-',dir='/run/user/1000'))
    def cipher(source,target):
     with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as s:
      s.connect(str(sock));s.sendall((json.dumps({'operation':'decrypt','source':str(source),'target':str(target)})+'\n').encode());data=b''
      while not data.endswith(b'\n'):
       part=s.recv(65536)
       if not part:raise RuntimeError('CIPHER_DISCONNECTED')
       data+=part
      assert json.loads(data)['ok'],'DECRYPTION_FAILED'
    def native(options):
     env={k:v for k,v in os.environ.items() if k not in ('CONTAINER_HOST','CONTAINER_CONNECTION','DOCKER_HOST','PGPASSWORD','PGSERVICE','PGSERVICEFILE','PGPASSFILE')}
     r=subprocess.run(['podman','--remote=false','run','--rm','--pull=never','--network','none','--read-only','--log-driver=none','-v',str(scratch)+':/inspection:ro,Z','--entrypoint','pg_restore',IMAGE,*options,'/inspection/database.dump'],capture_output=True,env=env,timeout=120)
     if r.returncode:raise RuntimeError('ARCHIVE_READ_FAILED_EXIT_'+str(r.returncode))
     return r.stdout.decode()
    def index(rows):
     out={(r['schema'],r['name']):r for r in rows}
     assert len(out)==len(rows),'DUPLICATE_IDENTIFIERS'
     return out
    try:
     assert hashlib.sha256(backup.read_bytes()).hexdigest()=='f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297'
     cipher(diag,scratch/'diagnostic.json');raw=json.loads((scratch/'diagnostic.json').read_text());assert raw['catalog']=='relations'
     left=index(raw['source']);right=index(raw['restored']);differences=[]
     for key in sorted(left.keys()|right.keys()):
      a=left.get(key);b=right.get(key)
      if a==b:continue
      fields={k:{'source':safe_role(a.get(k)) if k=='owner' else a.get(k),'restored':safe_role(b.get(k)) if k=='owner' else b.get(k)} for k in sorted(a.keys()|b.keys()) if a.get(k)!=b.get(k)} if a and b else {}
      differences.append({'schema':key[0],'name':key[1],'presence':'missing' if b is None else 'additional' if a is None else 'both','different_attributes':fields})
     cipher(backup,scratch/'bundle.tar')
     with tarfile.open(scratch/'bundle.tar') as t:
      expected={'database.dump','roles-no-passwords.sql','snapshot-catalog.json','snapshot-data.json','manifest.json'}
      assert len(t.getmembers())==len(expected) and set(t.getnames())==expected and all(x.isfile() for x in t.getmembers())
      manifest=json.load(t.extractfile('manifest.json'));assert manifest['project_ref']=='dlajxviqhkdcqnmczhvr'
      for name,digest in manifest['files'].items():
       data=t.extractfile(name).read();assert hashlib.sha256(data).hexdigest()==digest
       if name in ('database.dump','snapshot-catalog.json'):(scratch/name).write_bytes(data)
     source=json.loads((scratch/'snapshot-catalog.json').read_text());assert source['relations']==raw['source']
     toc=native(['--list']);ddl=native(['--schema-only','--file=-'])
     def ident(v):return '"'+v.replace('"','""')+'"'
     for d in differences:
      schema,name=d['schema'],d['name'];qvariants=[schema+'.'+name,ident(schema)+'.'+ident(name),schema+'.'+ident(name),ident(schema)+'.'+name]
      selected=[line for line in toc.splitlines() if re.match(r'^\d+;',line) and re.search(r'\b'+re.escape(schema)+r' '+re.escape(name)+r'(?: |$)',line)]
      owners=[];flags=[]
      for line in ddl.splitlines():
       if any(re.match(r'^ALTER (?:TABLE(?: ONLY)?|SEQUENCE|VIEW|MATERIALIZED VIEW) '+re.escape(q)+r' ',line) for q in qvariants):
        if ' OWNER TO ' in line:
         owner=line.split(' OWNER TO ',1)[1].rstrip(';').strip('"');owners.append(safe_role(owner))
        for flag in ('ENABLE ROW LEVEL SECURITY','DISABLE ROW LEVEL SECURITY','FORCE ROW LEVEL SECURITY','NO FORCE ROW LEVEL SECURITY'):
         if line.endswith(flag+';'):flags.append(flag)
      d['source_record']=left.get((schema,name));d['restored_record']=right.get((schema,name))
      d['archive_evidence']={'toc_entries':selected,'ddl_owner_roles':owners,'ddl_rls_flags':flags,'schema_ddl_mentions_object':any(q in ddl for q in qvariants)}
      d['source_security_inventory']={'acl_entries':len([x for x in source['relation_acl'] if x['schema']==schema and x['name']==name]),'policies':len([x for x in source['policies'] if x['schemaname']==schema and x['tablename']==name]),'triggers':len([x for x in source['triggers'] if x['schema']==schema and x['name']==name])}
     summary={'source_relation_count':len(left),'restored_relation_count':len(right),'different_relation_count':len(differences),'raw_order_only':not differences and raw['source']!=raw['restored'],'differences':differences,'database_metadata_recorded':'database_metadata' in source,'database_toc_entries':sum(bool(re.search(r'\bDATABASE(?: PROPERTIES)? - ',l)) for l in toc.splitlines()),'full_restore_performed':False,'network':'none','target_acl_policies_archived_in_error_diagnostic':False,'source_extensions':source['extensions'],'extension_creation_statements':[l for l in ddl.splitlines() if l.startswith('CREATE EXTENSION ')],'extension_toc_entries':[l for l in toc.splitlines() if re.search(r'\bEXTENSION - (postgis|pg_stat_statements|supabase_vault)\b',l)]}
     out=pathlib.Path('/tmp/cercly-relations-diagnostic-summary.json');out.write_text(json.dumps(summary,indent=2)+'\n');out.chmod(0o600)
     print(json.dumps(summary,indent=2),flush=True)
    finally:shutil.rmtree(scratch)

if __name__ == "__main__":
    main()
