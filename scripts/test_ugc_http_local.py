#!/usr/bin/env python3
"""UGC por HTTP real; únicamente el stack local NUEVO cercly-ugc-final-1-0."""
import argparse,base64,json,secrets,subprocess,uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.error import HTTPError

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--credentials',type=Path,required=True)
p.add_argument('--report',type=Path,required=True)
a=p.parse_args()
assert a.credentials.resolve().is_relative_to('/tmp') and a.credentials.stat().st_mode & 0o077 == 0
c=json.loads(a.credentials.read_text());api='http://127.0.0.1:56451';assert c['API_URL']==api
stack='cercly-ugc-final-1-0';db='supabase_db_'+stack
assert json.loads(subprocess.check_output(['podman','network','inspect',stack]))[0]['internal']
results=[]
def check(label,ok):
 results.append({'case':label,'status':'PASS' if ok else 'FAIL'})
 a.report.write_text(json.dumps({'scope':'LOCAL_REAL_HTTP_UGC','cases':results},ensure_ascii=False,indent=2)+'\n')
 assert ok,label
 print('PASS '+label,flush=True)
def sql(q):
 r=subprocess.run(['podman','exec','-i',db,'psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q,text=True,capture_output=True)
 if r.returncode:raise RuntimeError('SQL fixture local: '+r.stderr[:300])
 return r.stdout.strip()
def http(method,path,body=None,token=None,admin=False):
 assert path.startswith('/') and not path.startswith('//')
 key=c['SERVICE_ROLE_KEY'] if admin else c['ANON_KEY']
 raw=body if isinstance(body,bytes) or body is None else json.dumps(body).encode()
 headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'image/png' if isinstance(body,bytes) else 'application/json','Prefer':'return=representation'}
 try:r=urlopen(Request(api+path,data=raw,headers=headers,method=method),timeout=20)
 except HTTPError as e:r=e
 data=r.read()
 try:data=json.loads(data) if data else None
 except (ValueError,UnicodeDecodeError):pass
 return r.status,data
def rpc(name,body,token):return http('POST','/rest/v1/rpc/'+name,body,token)
def user(label):
 email='ugc-'+uuid.uuid4().hex+'@cercly.test';password=secrets.token_urlsafe(24)
 status,data=http('POST','/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True,'user_metadata':{'nombre':'UGC sintético '+label}},admin=True)
 assert status==200,('crear fixture',status)
 uid=str(uuid.UUID(data['id']));status,s=http('POST','/auth/v1/token?grant_type=password',{'email':email,'password':password})
 assert status==200
 return uid,s['access_token']

owner,ot=user('responsable');reader,rt=user('lector');admin,at=user('administrador');other,xt=user('otro')
sql(f"update public.usuarios set rol='propietario' where id='{owner}';update public.usuarios set rol='administrador' where id='{admin}';")
business=str(uuid.uuid4());category=sql('select id from public.categorias limit 1')
sql(f"insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable) values('{business}','{owner}','{category}','Negocio sintético UGC','Prueba',0,0,'aprobado',true)")
png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQ0AAAAASUVORK5CYII=')
path=f'{owner}/{business}/qa.png'
status,_=http('POST','/storage/v1/object/establecimientos-imagenes/'+path,png,ot)
check('Storage rechaza subida sin aceptar normas',status>=400)
status,normas=rpc('ugc_normas_publicacion',{},ot);check('normas completas con versión y SHA desde servidor',status==200 and len(normas['huella'])==64 and 'discriminación' in normas['texto'])
status,_=rpc('ugc_aceptar_normas',{'p_version':normas['version'],'p_huella':'falsa'},ot);check('huella falsa rechazada',status==400)
status,_=rpc('ugc_aceptar_normas',{'p_version':normas['version'],'p_huella':normas['huella']},ot);check('aceptación explícita real registrada',status in (200,204))
check('aceptación vinculada solo al sujeto real',sql(f"select count(*) from cercly_ugc_privado.aceptaciones where usuario_id='{owner}'")== '1' and sql(f"select count(*) from cercly_ugc_privado.aceptaciones where usuario_id='{reader}'")=='0')
status,_=http('POST','/storage/v1/object/establecimientos-imagenes/'+path,png,ot);check('Storage permite imagen tras aceptación',status==200)
photo=str(uuid.uuid4());status,data=http('POST','/rest/v1/fotos_establecimiento',{'id':photo,'establecimiento_id':business,'ruta_storage':path},ot)
if status!=201:print({'http':status,'code':data.get('code'),'message':data.get('message')},flush=True)
check('publicación de foto por REST y RLS reales',status==201 and data[0]['id']==photo)
promotion=str(uuid.uuid4());status,data=http('POST','/rest/v1/promociones',{'id':promotion,'establecimiento_id':business,'titulo':'Promo sintética','fecha_inicio':'2026-01-01T00:00:00Z','fecha_fin':'2027-01-01T00:00:00Z'},ot);check('publicación de promoción tras aceptación',status==201 and data[0]['id']==promotion)
for table, payload in (
 ('fotos_establecimiento', {'establecimiento_id':business,'ruta_storage':'no-autorizado.png'}),
 ('promociones', {'establecimiento_id':business,'titulo':'No autorizada',
                  'fecha_inicio':'2026-01-01T00:00:00Z','fecha_fin':'2027-01-01T00:00:00Z'}),
):
    status, data = http('POST', '/rest/v1/'+table, payload, xt)
    check('rechazo sin aceptación: '+table, status==403 and data.get('code')=='42501')
rpc('ugc_aceptar_normas',{'p_version':normas['version'],'p_huella':normas['huella']},xt)
for table, body in (
 ('fotos_establecimiento', {'establecimiento_id':business,'ruta_storage':'sin-propiedad.png'}),
 ('promociones', {'establecimiento_id':business,'titulo':'Sin propiedad',
                  'fecha_inicio':'2026-01-01T00:00:00Z','fecha_fin':'2027-01-01T00:00:00Z'}),
):
    status, data = http('POST', '/rest/v1/'+table, body, xt)
    check('aceptación no concede propiedad: '+table, status==403 and data.get('code')=='42501')
request_id=str(uuid.uuid4())
registration={
    'id':request_id, 'solicitante_id':owner, 'tipo':'registro',
    'datos_propuestos':{
        'nombre':'Registro UGC sintético','direccion':'Prueba','latitud':1,
        'longitud':1,'categoria_id':category,
        'horarios':[{'dia_semana':1,'apertura_minutos':480,'cierre_minutos':1020}],
    },
}
status,data=http('POST','/rest/v1/solicitudes_establecimientos',registration,ot)
if status!=201:
    print('Solicitud de registro:',status,data.get('code'),data.get('message'),flush=True)
check('propietario con normas conserva la creación de solicitudes',status==201)
status,data=rpc('responder_solicitud_establecimiento',{
    'p_solicitud_id':request_id,'p_estado':'aprobada','p_motivo_respuesta':'Revisión de fixture sintético',
},at)
if status not in (200,204):
    print('Aprobación de registro:',status,data.get('code'),data.get('message'),flush=True)
check('admin revisa solicitud y horario sin aceptar normas de autor',status in (200,204))
check('aprobación entrega la ficha al solicitante',
      sql(f"select count(*) from public.establecimientos e join public.solicitudes_establecimientos s on s.establecimiento_id=e.id join public.horarios_establecimiento h on h.establecimiento_id=e.id where s.id='{request_id}' and e.propietario_id='{owner}' and h.dia_semana=1")=='1')
reported={}
for tipo,obj in [('establecimiento',business),('fotografia',photo),('promocion',promotion),('propietario',business)]:
 status,data=rpc('ugc_denunciar',{'p_tipo':tipo,'p_objetivo_id':obj,'p_motivo':'derechos','p_detalle':'Reporte exclusivamente sintético'},rt)
 check('denuncia HTTP '+tipo,status==200 and isinstance(data,str));reported[tipo]=data
with ThreadPoolExecutor(max_workers=8) as pool:
 duplicate=list(pool.map(lambda _:rpc('ugc_denunciar',{'p_tipo':'establecimiento','p_objetivo_id':business,'p_motivo':'spam','p_detalle':'Duplicado sintético'},rt),range(24)))
check('24 denuncias concurrentes convergen en un caso',all(s==200 and d==reported['establecimiento'] for s,d in duplicate))
check('concurrencia no crea filas duplicadas',sql(f"select count(*) from cercly_ugc_privado.denuncias where denunciante_id='{reader}' and tipo='establecimiento' and objetivo_id='{business}'")=='1')
status,data=rpc('ugc_mis_denuncias',{},xt);check('otra cuenta no ve denuncias ajenas',status==200 and data==[])
status,_=rpc('ugc_denuncias_admin',{},rt);check('lector no accede a cola administrativa',status==403)
status,_=rpc('ugc_contexto_denuncia',{'p_denuncia_id':reported['fotografia']},rt);check('lector no accede a contexto o trazabilidad ajena',status==403)
status,_=rpc('ugc_revisar_denuncia',{'p_denuncia_id':reported['fotografia'],'p_estado':'retirada','p_motivo':'No tiene autorización para revisar'},rt);check('lector no puede moderar',status==403)
status,_=rpc('ugc_bloquear_responsable',{'p_tipo':'establecimiento','p_objetivo_id':business},rt);check('bloqueo persistido por RPC real',status in (200,204))
status,data=rpc('ugc_mis_bloqueos',{},rt);check('bloqueo vuelve con referencia reconocible',status==200 and len(data)==1 and data[0]['referencia']=='Negocio sintético UGC')
for table,identity in [('establecimientos',business),('fotos_establecimiento',photo),('promociones',promotion)]:
 status,data=http('GET',f'/rest/v1/{table}?id=eq.{identity}',token=rt);check('RLS oculta '+table+' al bloqueador',status==200 and data==[])
status,data=http('GET',f'/rest/v1/establecimientos?id=eq.{business}',token=xt);check('bloqueo no afecta a otro lector',status==200 and len(data)==1)
status,_=http('POST','/storage/v1/object/sign/establecimientos-imagenes/'+path,{'expiresIn':60});check('catálogo permite URL de foto pública al visitante',status==200)
status,_=http('POST','/storage/v1/object/sign/establecimientos-imagenes/'+path,{'expiresIn':60},rt);check('no se firman nuevas URL de foto bloqueada',status>=400)
status,_=rpc('ugc_desbloquear',{'p_bloqueado_id':owner},xt)
status,data=rpc('ugc_mis_bloqueos',{},rt);check('otra cuenta no puede desbloquear por ti',len(data)==1)
rpc('ugc_desbloquear',{'p_bloqueado_id':owner},rt)
status,data=http('GET',f'/rest/v1/establecimientos?id=eq.{business}',token=rt);check('desbloqueo propio restaura catálogo',status==200 and len(data)==1)
status,context=rpc('ugc_contexto_denuncia',{'p_denuncia_id':reported['fotografia']},at);check('admin ve contenido e historial sin correo del denunciante',status==200 and context['ruta']==path and 'denunciante_id' not in context)
status,_=rpc('ugc_revisar_denuncia',{'p_denuncia_id':reported['fotografia'],'p_estado':'en_revision','p_motivo':'Se inicia revisión del archivo sintético'},at);check('admin inicia revisión con motivo',status in (200,204))
status,_=rpc('ugc_revisar_denuncia',{'p_denuncia_id':reported['fotografia'],'p_estado':'retirada','p_motivo':'Se retira por infracción sintética comprobada'},at);check('admin retira sin borrar datos compartidos',status in (200,204))
status,data=http('GET',f'/rest/v1/fotos_establecimiento?id=eq.{photo}',token=xt);check('foto retirada deja de ser visible a otro lector',status==200 and data==[])
status,_=http('POST','/storage/v1/object/sign/establecimientos-imagenes/'+path,{'expiresIn':60},xt);check('foto retirada no obtiene nuevas URL firmadas',status>=400)
status,_=http('POST','/storage/v1/object/sign/establecimientos-imagenes/'+path,{'expiresIn':60});check('visitante tampoco obtiene URL nueva de foto retirada',status>=400)
check('retirada conserva metadato y archivo para revisión',sql(f"select count(*) from storage.objects where name='{path}'")=='1' and sql(f"select count(*) from public.fotos_establecimiento where id='{photo}'")=='1')
status,data=rpc('ugc_contexto_denuncia',{'p_denuncia_id':reported['fotografia']},at);check('trazabilidad guarda dos transiciones',status==200 and len(data['historial'])==2)
for i in range(6):
 obj=str(uuid.uuid4());sql(f"insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable) values('{obj}','{owner}','{category}','QA cuota {i}','Prueba',0,0,'aprobado',true)")
 assert rpc('ugc_denunciar',{'p_tipo':'establecimiento','p_objetivo_id':obj,'p_motivo':'spam','p_detalle':''},rt)[0]==200
obj=str(uuid.uuid4());sql(f"insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud,estado,publicable) values('{obj}','{owner}','{category}','QA exceso','Prueba',0,0,'aprobado',true)")
status,data=rpc('ugc_denunciar',{'p_tipo':'establecimiento','p_objetivo_id':obj,'p_motivo':'spam','p_detalle':''},rt);check('denuncia 11 limitada por servidor',status==400 and data.get('code')=='P0001')
next_version='qa-'+uuid.uuid4().hex
sql(f"update cercly_ugc_privado.normas set vigente=false;insert into cercly_ugc_privado.normas(version,texto,huella,vigente) values('{next_version}','Normas nuevas sintéticas',encode(extensions.digest('Normas nuevas sintéticas','sha256'),'hex'),true)")
try:
    status,data=rpc('ugc_exigir_normas',{},ot);check('cambio de versión exige renovar aceptación',status==403 and data.get('code')=='42501')
finally:
    sql(f"update cercly_ugc_privado.normas set vigente=false where version='{next_version}';update cercly_ugc_privado.normas set vigente=true where version='{normas['version']}'")
status,_=rpc('ugc_bloquear_responsable',{'p_tipo':'establecimiento','p_objetivo_id':business},rt)
check('bloqueo existe antes de revocar sesión',status in (200,204))
status,_=http('POST','/auth/v1/logout?scope=global',{},rt)
check('Auth revoca la sesión sintética',status==204)
status,data=rpc('ugc_desbloquear',{'p_bloqueado_id':owner},rt)
print(f"Revocación en PostgREST: HTTP {status}, código {data.get('code') if isinstance(data,dict) else '-'}",flush=True)
check('JWT de sesión revocada no modifica UGC',status in (401,403) and data.get('code')=='28000')
check('revocación deja intacto el bloqueo',sql(f"select count(*) from cercly_ugc_privado.bloqueos where usuario_id='{reader}' and bloqueado_id='{owner}'")=='1')
report=json.loads(a.report.read_text());report.update(passed=len(results),failed=0,limitations=['Local stack only; no hosted changes','Private URL tokens issued before a withdrawal may remain valid until expiry','Terms/retention require owner approval before deployment'])
a.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'{len(results)} PASS; 0 FAIL; LOCAL ONLY')
