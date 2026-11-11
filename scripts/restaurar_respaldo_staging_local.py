#!/usr/bin/env python3
"""Requiere autorización expresa. No exporta ni conecta a bases remotas."""
import argparse,hashlib,json,os,pathlib,re,shutil,socket,stat,subprocess,sys,tarfile,tempfile,time,uuid
from cercly_backup_catalog import QUERIES,wrapped,ident,fingerprint
from comparar_esquemas_respaldo import acl_decode_query,compare_schemas,public_schema_details
from recuperar_acl_esquemas_local import plan_graphql_acl_recovery
from recuperar_propietarios_relaciones_local import plan_relation_owner_recovery,compare_relations
REF='dlajxviqhkdcqnmczhvr'
IMAGE='public.ecr.aws/supabase/postgres@sha256:0450166354dc9c1d25f0322ac8b580774d4fb0184d2b087f6e4fe9499c66cf53'
parser=argparse.ArgumentParser(description='Restauración local aislada de un respaldo cifrado existente; sin conexiones a Supabase.')
parser.add_argument('--ejecutar-restauracion-local', action='store_true', help='Solo usar tras autorización explícita del propietario')
parser.add_argument('--diagnosticar-esquemas',action='store_true',help='Detenerse tras comparar esquemas y guardar diagnóstico cifrado; no certificar recuperación completa')
parser.add_argument('--recuperar-acl-archivadas',action='store_true',help='Solo en destino aislado: reponer los grants GraphQL originales del inventario validado; no conceder otros')
parser.add_argument('--recuperar-propietarios-archivados',action='store_true',help='Solo en destino aislado: recuperar los propietarios archivados de los siete miembros de extensiones revisados; verificar después ACL y políticas completas')
parser.add_argument('--cipher-socket',type=pathlib.Path,required=True,help='Socket privado del agente de cifrado, sin frase en argumentos')
args=parser.parse_args()
if not args.ejecutar_restauracion_local:parser.error('Falta autorización operativa explícita; no se descifra el respaldo')
CIPHER_SOCKET=args.cipher_socket.resolve()
if not (CIPHER_SOCKET.is_relative_to(pathlib.Path('/run/user')/str(os.getuid()))
        and stat.S_ISSOCK(CIPHER_SOCKET.stat().st_mode)
        and CIPHER_SOCKET.stat().st_uid==os.getuid()
        and CIPHER_SOCKET.stat().st_mode&0o077==0
        and CIPHER_SOCKET.parent.stat().st_mode&0o077==0):
 parser.error('El socket debe ser privado y pertenecer al usuario local')
EXPECTED_SHA256='f6cc43269951284a870aadfbe08d52c94e268b2b39d63a7307e3d98938bbc297'
DEST=pathlib.Path('/home/Anthony/RespaldosPrivados/Cercly/STAGING/20261107')
FINAL=DEST/'staging-database-bundle.tar.gpg'
os.umask(0o077)
env={k:v for k,v in os.environ.items() if k not in ['CONTAINER_HOST','CONTAINER_CONNECTION','DOCKER_HOST','PGPASSWORD','PGSERVICE','PGSERVICEFILE','PGPASSFILE']}
name='cercly-staging-restore-'+uuid.uuid4().hex[:10]
operator='cercly_restore_operator_'+uuid.uuid4().hex[:8]
started=False;scratch=None;stage='cipher_integrity';checks=[]
attempt_id=time.strftime('%Y%m%dT%H%M%SZ',time.gmtime())+'-'+uuid.uuid4().hex[:8]
class Failure(Exception):
 def __init__(self,category,exit_code=None,sqlstate=None,error_bytes=None):
  super().__init__(category);self.exit_code=exit_code;self.sqlstate=sqlstate;self.error_bytes=error_bytes
def run(args,data=None):
 r=subprocess.run(['podman','--remote=false',*args],input=data,capture_output=True,env=env,timeout=180)
 if r.returncode:
  message=r.stderr.lower()
  reason='PERMISSION_DENIED' if b'permission denied' in message else 'EXTENSION_OR_PLATFORM_MISMATCH' if b'extension' in message or b'pg_cron' in message else 'LOCAL_RESTORE_COMMAND_FAILED'
  templates=[(b'already exists','OBJECT_ALREADY_EXISTS'),
             (b'must be superuser','SUPERUSER_REQUIRED'),
             (b'must be owner','OBJECT_OWNER_REQUIRED'),
             (b'is not available','EXTENSION_OR_FEATURE_UNAVAILABLE'),
             (b'could not access file','EXTENSION_LIBRARY_UNAVAILABLE'),
             (b'violates foreign key','FOREIGN_KEY_VIOLATION'),
             (b'duplicate key','DUPLICATE_KEY'),
             (b'unrecognized configuration parameter','UNSUPPORTED_CONFIGURATION'),
             (b'role ', 'ROLE_OR_OWNERSHIP_ERROR')]
  for fragment,category in templates:
   if fragment in message:reason=category;break
  state=re.search(rb'(?:ERROR|FATAL):\s+([A-Z0-9]{5})\b',r.stderr)
  raise Failure(reason,r.returncode,state.group(1).decode() if state else None,r.stderr)
 return r.stdout
def sql(query,db='cercly_restore',user=None):
 return run(['exec','-i',name,'psql','-X','-qAt','-h','127.0.0.1','-U',user or operator,'-d',db,'--set=ON_ERROR_STOP=1','--set=VERBOSITY=sqlstate','--set=SHOW_CONTEXT=never'],query.encode()).decode().strip()
def cipher(request):
 with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as s:
  s.connect(str(CIPHER_SOCKET));s.sendall((json.dumps(request)+'\n').encode());data=b''
  while not data.endswith(b'\n'):
   part=s.recv(4096)
   if not part:raise Failure('CIPHER_AGENT_DISCONNECTED')
   data+=part
  if not json.loads(data)['ok']:raise Failure('DECRYPTION_FAILED')
def fail(category):raise Failure(category)
def verify(condition,label):
 checks.append({'check':label,'passed':bool(condition)})
 if not condition:fail('CHECK_FAILED_'+label.upper())
try:
 report=json.loads((DEST/'verification-report.json').read_text())
 report.update({'acl_recovery_grants_applied':0,'archived_schema_acl_verified':False,'role_context_matches':None,'recovery_complete':False,'relation_owner_changes_applied':0})
 verify(report['project_ref']==REF and report['export']=='PASS','source_project_and_export')
 verify(hashlib.sha256(FINAL.read_bytes()).hexdigest()==EXPECTED_SHA256==report['encrypted_sha256'],'original_sha256')
 scratch=pathlib.Path(tempfile.mkdtemp(prefix='cercly-staging-restore-',dir='/run/user/1000'))
 plain=scratch/'bundle.tar'
 cipher({'operation':'decrypt','source':str(FINAL),'target':str(plain)})
 with tarfile.open(plain) as t:
  expected={'database.dump','roles-no-passwords.sql','snapshot-catalog.json','snapshot-data.json','manifest.json'}
  members=t.getmembers();verify(len(members)==len(expected) and {x.name for x in members}==expected and all(x.isfile() for x in members),'decrypted_bundle_members')
  for member in members:
   p=scratch/member.name
   with p.open('xb') as f:os.chmod(p,0o600);shutil.copyfileobj(t.extractfile(member),f)
 manifest=json.loads((scratch/'manifest.json').read_text());verify(manifest['project_ref']==REF,'bundle_project')
 for i,(path,digest) in enumerate(manifest['files'].items(),1):verify(hashlib.sha256((scratch/path).read_bytes()).hexdigest()==digest,'component_sha256_'+str(i))
 source=json.loads((scratch/'snapshot-catalog.json').read_text());source_data=json.loads((scratch/'snapshot-data.json').read_text())
 print('Integridad del respaldo cifrado y del bundle descifrado: PASS',flush=True)
 stage='local_instance_start'
 run(['run','-d','--rm','--pull=never','--log-driver=none','--network','none','--name',name,
  '-v',str(scratch)+':/backup:ro,Z','-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE,
  'postgres','-c','cron.database_name=cercly_restore','-c','cron.launch_active_jobs=off','-c','logging_collector=off','-c','log_min_error_statement=panic']);started=True
 for _ in range(120):
  r=subprocess.run(['podman','--remote=false','exec',name,'pg_isready','-h','127.0.0.1','-U','supabase_admin'],capture_output=True,env=env)
  if r.returncode==0:break
  time.sleep(.5)
 else:fail('LOCAL_POSTGRES_START_TIMEOUT')
 verify(run(['inspect',name,'--format','{{.HostConfig.NetworkMode}}']).strip()==b'none','network_none')
 stage='restore_roles_prepare.bootstrap_identity'
 verify(sql("select rolsuper from pg_roles where rolname=current_user;",db='postgres',user='supabase_admin')=='t','bootstrap_superuser')
 stage='restore_roles_prepare.create_local_operator'
 sql('create role '+ident(operator)+' login superuser;',db='postgres',user='supabase_admin')
 verify(sql("select current_user = '"+operator+"' and rolsuper from pg_roles where rolname=current_user;",db='postgres')=='t','local_maintenance_operator')
 stage='restore_roles_prepare.inventory'
 present={x['rolname'] for x in json.loads(sql(wrapped("select rolname from pg_roles where rolname !~ '^pg_'"),db='postgres'))}
 source_roles={x['rolname'] for x in source['roles']}
 verify(operator not in source_roles,'maintenance_role_not_in_source')
 stage='restore_roles_prepare.create_missing_roles'
 for role in sorted(source_roles-present):sql('create role '+ident(role)+';',db='postgres')
 # El rol de mantenimiento local se conserva para no depender de los atributos
 # de postgres que el backup repondrá al final. No recibe credenciales remotas.
 stage='restore_roles_prepare.create_database'
 sql('create database cercly_restore with template template0 owner postgres;',db='postgres')
 stage='database_restore'
 run(['exec',name,'pg_restore','--host=127.0.0.1','--username='+operator,'--dbname=cercly_restore',
  '--single-transaction','--exit-on-error','/backup/database.dump'])
 verify(True,'pg_restore_completed')
 print('pg_restore completó la transacción en PostgreSQL local sin red',flush=True)
 stage='restore_roles_apply'
 roles_sql=(scratch/'roles-no-passwords.sql').read_text()
 pattern=r'^CREATE ROLE ((?:"(?:[^"\n]|"")*"|[A-Za-z_][A-Za-z_0-9$]*));\s*$'
 matches=list(re.finditer(pattern,roles_sql,re.MULTILINE))
 unquote=lambda x:x[1:-1].replace('""','"') if x.startswith('"') else x
 verify({unquote(x.group(1)) for x in matches}==source_roles,'role_file_coverage')
 roles_sql=re.sub(pattern,'',roles_sql,flags=re.MULTILINE)
 # Conservar membresías de bootstrap. pg_dumpall no recrea necesariamente
 # las internas pg_*; no revocar todo antes de importar el archivo de roles.
 sql(roles_sql,db='postgres')
 stage='catalog_verification'
 restored={}
 for label,query in QUERIES.items():
  restored[label]=json.loads(sql('begin read only; set local search_path=pg_catalog; '+wrapped(query)+' commit;'))
 restored['roles']=[x for x in restored['roles'] if x['rolname']!=operator]
 role_context_matches=(source['roles']==restored['roles'] and source['memberships']==restored['memberships'])
 report['role_context_matches']=role_context_matches
 if args.recuperar_propietarios_archivados:
  stage='archived_relation_owner_recovery'
  verify(role_context_matches,'source_role_context_before_owner_recovery')
  member_query="select n.nspname schema,c.relname name,e.extname from pg_depend d join pg_class c on d.classid='pg_class'::regclass and d.objid=c.oid join pg_namespace n on n.oid=c.relnamespace join pg_extension e on d.refclassid='pg_extension'::regclass and d.refobjid=e.oid where d.deptype='e' order by 1,2"
  members=json.loads(sql(wrapped(member_query)))
  # El plan falla ante cambios de tipo, RLS, extensiones, objetos desconocidos
  # o propietarios distintos del administrador temporal de ESTE destino.
  owner_plan=plan_relation_owner_recovery(source['relations'],restored['relations'],members,operator,source['extensions'],restored['extensions'])
  sql(owner_plan['sql'])
  report['relation_owner_changes_applied']=owner_plan['change_count']
  for label in ('relations','relation_acl','column_acl','policies'):
   restored[label]=json.loads(sql('begin read only; set local search_path=pg_catalog; '+wrapped(QUERIES[label])+' commit;'))
  verify(source['relations']==restored['relations'],'archived_relation_owner_recovery_exact')
  # No se concede ni elimina ningún permiso para forzar esta igualdad.
  verify(source['relation_acl']==restored['relation_acl'],'relation_acl_after_owner_recovery')
  verify(source['column_acl']==restored['column_acl'],'column_acl_after_owner_recovery')
  verify(source['policies']==restored['policies'],'policies_after_owner_recovery')
 acl_cache={}
 def decode_schema_acl(row):
  cache_key=(row['owner'],row['acl'])
  if cache_key not in acl_cache:
   acl_cache[cache_key]=json.loads(sql(acl_decode_query(row,source_roles)))
  return acl_cache[cache_key]
 if args.recuperar_acl_archivadas:
  stage='archived_schema_acl_recovery'
  verify(role_context_matches,'source_role_context_before_acl_recovery')
  plan=plan_graphql_acl_recovery(source['schemas'],restored['schemas'],decode_schema_acl)
  sql(plan['sql'])
  report['acl_recovery_grants_applied']=plan['grant_count']
  acl_cache.clear()
  restored['schemas']=json.loads(sql('begin read only; set local search_path=pg_catalog; '+wrapped(QUERIES['schemas'])+' commit;'))
  verify(compare_schemas(source['schemas'],restored['schemas'],decode_schema_acl)['equivalent_catalog'],'archived_schema_acl_recovery_exact')
  report['archived_schema_acl_verified']=True
 stage='schema_comparison'
 schema_result=compare_schemas(source['schemas'],restored['schemas'],decode_schema_acl)
 # Proyecciones de USAGE/CREATE bajo el grafo local restaurado. Un pseudo-rol
 # pg_database_owner depende además del dueño de base; no se presume su valor
 # original porque ese atributo no figura en snapshot-catalog.json.
 schema_result['role_context_matches']=role_context_matches
 schema_result['source_database_owner_recorded']=False
 schema_result['restored_database_owner']=sql("select pg_get_userbyid(datdba) from pg_database where datname=current_database();")
 report['schema_summary']=schema_result['summary']
 schema_result['source_raw']=source['schemas'];schema_result['restored_raw']=restored['schemas']
 schema_result['source_roles']=source['roles'];schema_result['restored_roles']=restored['roles']
 schema_result['source_memberships']=source['memberships'];schema_result['restored_memberships']=restored['memberships']
 private_diff=scratch/'schema-comparison-private.json'
 private_diff.write_text(json.dumps(schema_result,indent=2)+'\n');os.chmod(private_diff,0o600)
 schema_diagnostic=DEST/('restore-diagnostic-'+attempt_id+'-schemas.gpg')
 cipher({'operation':'encrypt_diagnostic','source':str(private_diff),'target':str(schema_diagnostic)})
 if args.diagnosticar_esquemas:
  diagnostic={'attempt_id':attempt_id,'project_ref':REF,'original_sha256':EXPECTED_SHA256,
   'network':'none','pg_restore_completed':True,'full_validation_complete':False,
   'comparison_equivalent':schema_result['equivalent_catalog'],
   'summary':schema_result['summary'],'safe_details':public_schema_details(schema_result),
   'role_context_matches':role_context_matches,'source_database_owner_recorded':False,
   'restored_migrations_count':len(restored['migrations']),
   'migration_catalog_matches':source['migrations']==restored['migrations'],
   'encrypted_diagnostic':str(schema_diagnostic),
   'pending':['data fingerprints','functions','triggers','RLS','other ACL','sequences','source database-owner context']}
  (DEST/('schema-diagnostic-'+attempt_id+'.json')).write_text(json.dumps(diagnostic,indent=2)+'\n')
  print('SCHEMA_DIAGNOSTIC_COMPLETE; '+json.dumps(diagnostic,ensure_ascii=False),flush=True)
  sys.exit(0)
 stage='catalog_verification'
 for label in QUERIES:
  if label=='schemas':
   verify(schema_result['equivalent_catalog'],'catalog_schemas')
  elif source[label]!=restored[label]:
   checks.append({'check':'catalog_'+label,'passed':False})
   detail={'catalog':label,'source':source[label],'restored':restored[label]}
   if label=='relations':
    detail['comparison']=compare_relations(source[label],restored[label])
    detail['security_context']={key:{'source':source[key],'restored':restored[key]} for key in ('relation_acl','column_acl','policies')}
   raise Failure('CATALOG_MISMATCH_'+label.upper(),error_bytes=json.dumps(detail,indent=2).encode())
  else:verify(True,'catalog_'+label)
 stage='data_verification'
 data_check_index=0
 for x in source['relations']:
  if x['relkind'] not in ['r','p','m']:continue
  key=x['schema']+'.'+x['name']
  actual=json.loads(sql('begin read only; set local search_path=pg_catalog; '+fingerprint(x['schema'],x['name'])+' commit;'))
  data_check_index+=1;verify(actual==source_data[key],'data_fingerprint_'+str(data_check_index))
 stage='sequences_verification'
 for sequence_index,x in enumerate(source['sequences'],1):
  key=x['schemaname']+'.'+x['sequencename']
  actual=json.loads(sql(wrapped('select last_value,is_called from '+ident(x['schemaname'])+'.'+ident(x['sequencename']))))
  verify(actual==source['sequence_state'][key],'sequence_state_'+str(sequence_index))
 # La evidencia local ya inspeccionada no contiene el propietario/contexto
 # original de base (sin entrada DATABASE en TOC ni metadato en el inventario).
 # Es un pendiente explícito: jamás se convierte en PASS o GO global.
 stage='database_metadata_verification'
 if 'database_metadata' in source:fail('DATABASE_METADATA_FORMAT_REQUIRES_REVIEW')
 pending=[{'check':'original_database_context','status':'PENDING',
           'reason':'No original database owner/ACL/config metadata in archived snapshot or inspected TOC'}]
 if any('owner' not in ext for ext in source['extensions']):
  pending.append({'check':'original_extension_owner_context','status':'PENDING',
                  'reason':'Original extension owners are not recorded in the archived extension inventory'})
 for key in ['failed_stage','failure_category','failure_exit_code','failure_sqlstate','encrypted_diagnostic']:
  report.pop(key,None)
 report.update({'restoration':'VERIFIED_WITH_PENDING_DATABASE_CONTEXT','recovery_complete':False,
  'go_for_remote_migrations':False,'network':'none','historical_migrations':len(restored['migrations']),
  'checks_passed':sum(x['passed'] for x in checks),'checks_failed':sum(not x['passed'] for x in checks),
  'checks_pending':len(pending),'pending_checks':pending,'checks':checks,'attempt_id':attempt_id,
  'data_relations_verified':data_check_index,'sequences_verified':len(source['sequences']),
  'functions_verified':len(source['functions']),'triggers_verified':len(source['triggers']),
  'policies_verified':len(source['policies']),'schema_diagnostic':str(schema_diagnostic),
  'limitations':['Storage bytes excluded','External settings and secrets excluded',
  'Custom role passwords excluded','OAuth/SMTP/Auth services not exercised',
  'Encrypted Vault secrets may require platform key not provided by database dump']})
 (DEST/('restore-attempt-'+attempt_id+'.json')).write_text(json.dumps(report,indent=2)+'\n')
 (DEST/'verification-report.json').write_text(json.dumps(report,indent=2)+'\n')
 print('LOCAL_CHECKS_COMPLETE; '+json.dumps({k:report[k] for k in [
  'restoration','checks_passed','checks_failed','checks_pending','acl_recovery_grants_applied',
  'archived_schema_acl_verified','role_context_matches','data_relations_verified','sequences_verified',
  'functions_verified','triggers_verified','policies_verified','historical_migrations','recovery_complete']},ensure_ascii=False),flush=True)

except Exception as error:
 reason=str(error) if isinstance(error,Failure) else type(error).__name__
 if not checks or checks[-1]['passed']:checks.append({'check':stage,'passed':False})
 diagnostic_path=None
 if isinstance(error,Failure) and error.error_bytes and scratch:
  try:
   private_error=scratch/'restore-error-private.txt';private_error.write_bytes(error.error_bytes);os.chmod(private_error,0o600)
   diagnostic_path=DEST/('restore-diagnostic-'+attempt_id+'.gpg')
   cipher({'operation':'encrypt_diagnostic','source':str(private_error),'target':str(diagnostic_path)})
  except Exception:diagnostic_path=None
 print('STOPPED; stage='+stage+'; reason='+reason+'; exit='+str(getattr(error,'exit_code',None))+'; SQLSTATE='+str(getattr(error,'sqlstate',None))+'; sin reintento ni cambios remotos',flush=True)
 if (DEST/'verification-report.json').exists():
  # Conservar resultados de ESTE intento, sin recargar indicadores antiguos.
  if 'report' not in locals():report=json.loads((DEST/'verification-report.json').read_text())
  report.update({'restoration':'FAILED','recovery_complete':False,'go_for_remote_migrations':False,'failed_stage':stage,'failure_category':reason,'failure_exit_code':getattr(error,'exit_code',None),'failure_sqlstate':getattr(error,'sqlstate',None)})
  report.update({'checks_passed':sum(x['passed'] for x in checks),'checks_failed':sum(not x['passed'] for x in checks),'checks':checks,'attempt_id':attempt_id,'encrypted_diagnostic':str(diagnostic_path) if diagnostic_path else None})
  (DEST/('restore-attempt-'+attempt_id+'.json')).write_text(json.dumps(report,indent=2)+'\n')
  (DEST/'verification-report.json').write_text(json.dumps(report,indent=2)+'\n')
 sys.exit(1)
finally:
 if started:subprocess.run(['podman','--remote=false','stop','--time','2',name],capture_output=True,env=env,timeout=30)
 if scratch and scratch.exists():shutil.rmtree(scratch)
 try:cipher({'operation':'stop'})
 except Exception:pass
 # El agente es responsable de su socket; no se borran carpetas que este script no creó.
