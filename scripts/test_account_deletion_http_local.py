#!/usr/bin/env python3
"""HTTP real contra el stack DESECHABLE cercly-delete-http-20261119.

Rechaza URLs alojadas y contenedores/redes ajenos. Crea sus propias identidades
y PNG sintéticos; solo elimina las identidades creadas por esta ejecución.
No monta datos reales ni descarga imágenes. Ver ELIMINACION_HTTP_LOCAL.md.
"""
import argparse
import base64
import hashlib
import json
import re
import secrets
import subprocess
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
STACK = 'cercly-delete-http-20261119'
DB = 'supabase_db_' + STACK
API = 'http://127.0.0.1:56431'
HANDLER = 'http://127.0.0.1:56435'
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQ0AAAAASUVORK5CYII=')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credentials', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    assert args.credentials.resolve().is_relative_to('/tmp')
    assert args.credentials.stat().st_mode & 0o077 == 0
    config = json.loads(args.credentials.read_text())
    assert config['API_URL'] == API
    assert subprocess.check_output(['podman', 'inspect', DB, '--format', '{{.Name}}'], text=True).strip() == DB
    network = json.loads(subprocess.check_output(['podman', 'network', 'inspect', STACK], text=True))
    assert network[0]['internal'] is True
    results = []
    created = set()

    def check(label, condition, detail=None):
        results.append({'case': label, 'status': 'PASS' if condition else 'FAIL', **({'detail': detail} if detail else {})})
        args.report.write_text(json.dumps({'scope': 'LOCAL_ONLY_REAL_HTTP', 'cases': results}, ensure_ascii=False, indent=2) + '\n')
        if not condition:
            raise AssertionError(label)
        print('PASS ' + label, flush=True)

    def sql(query):
        p = subprocess.run(['podman', 'exec', '-i', DB, 'psql', '-X', '-qAt', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], input=query, text=True, capture_output=True)
        if p.returncode:
            raise RuntimeError('SQL local falló: ' + p.stderr[:600])
        return p.stdout.strip()

    def http(method, path, body=None, token=None, admin=False, binary=False):
        url = path if path.startswith(HANDLER) else API + path
        assert url.startswith(API + '/') or url == HANDLER
        key = config['SERVICE_ROLE_KEY'] if admin else config['ANON_KEY']
        headers = {'apikey': key, 'Authorization': 'Bearer ' + (token or key), 'Content-Type': 'image/png' if isinstance(body, bytes) else 'application/json'}
        raw = body if isinstance(body, bytes) or body is None else json.dumps(body).encode()
        try:
            response = urlopen(Request(url, data=raw, headers=headers, method=method), timeout=20)
        except HTTPError as error:
            response = error
        data = response.read()
        return response.status, data if binary else (json.loads(data) if data else None)

    def user(label):
        email = 'http-' + uuid.uuid4().hex + '@cercly.test'
        password = secrets.token_urlsafe(24)
        status, data = http('POST', '/auth/v1/admin/users', {'email': email, 'password': password, 'email_confirm': True, 'user_metadata': {'nombre': 'Sintético ' + label}}, admin=True)
        assert status == 200, ('crear identidad sintética', status)
        identity = str(uuid.UUID(data['id']))
        created.add(identity)
        status, session = http('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        assert status == 200, ('login sintético', status)
        return {'id': identity, 'token': session['access_token'], 'refresh': session['refresh_token']}

    def delete_self(subject, expected):
        assert subject['id'] in created
        status, data = http('POST', HANDLER, {}, token=subject['token'])
        check('handler ' + expected, data and data.get('estado') == expected and status == (200 if expected == 'eliminada' else 202), {'http': status})

    def own_counts(identity):
        assert identity in created
        return json.loads(sql(f"""select jsonb_build_object(
          'auth',(select count(*) from auth.users where id='{identity}'),
          'perfil',(select count(*) from public.usuarios where id='{identity}'),
          'sesiones',(select count(*) from auth.sessions where user_id='{identity}'),
          'refresh',(select count(*) from auth.refresh_tokens where user_id='{identity}'),
          'cuota',(select count(*) from cercly_rutas_privado.rutas_limites_usuarios where usuario_id='{identity}'),
          'preferencias',(select count(*) from public.preferencias_usuario where usuario_id='{identity}'),
          'categorias',(select count(*) from public.preferencias_usuario_categorias where usuario_id='{identity}'),
          'push',(select count(*) from public.push_preferences where user_id='{identity}'),
          'instalaciones',(select count(*) from public.fcm_installations where user_id='{identity}'),
          'solicitud',(select count(*) from cercly_account_private.solicitudes_eliminacion where usuario_id='{identity}'))"""))

    # La migración solo debe cambiar un cuerpo de función, nunca datos/ACL.
    definition = sql("select pg_get_functiondef('cercly_account_private.es_referencia_identidad_plataforma(oid)'::regprocedure)")
    old, count = re.subn(r",\s*\('cercly_rutas_privado','rutas_limites_usuarios','rutas_limites_usuarios_usuario_id_fkey','usuario_id','c'\)", '', definition)
    assert count == 1
    migration = (ROOT / 'supabase/migrations/20261119231916_reconocer_cuota_rutas_eliminacion.sql').read_text()
    assert re.findall(r'^create or replace function (\S+)', migration, re.M) == ['cercly_account_private.es_referencia_identidad_plataforma(p_constraint']
    check('migración sin DML, ALTER ni GRANT', not re.search(r'^\s*(insert|update|delete|alter|grant|revoke|drop)\b', migration, re.I | re.M))
    metadata = "select jsonb_build_array(proowner,proacl,prosecdef,proconfig) from pg_proc where oid='cercly_account_private.es_referencia_identidad_plataforma(oid)'::regprocedure"
    acl_before = sql(metadata)
    data_fingerprint = """do $$ declare t record; h text; all_rows text:=''; begin
      for t in select schemaname,tablename from pg_tables where schemaname in ('public','cercly_rutas_privado')
        or (schemaname='auth' and tablename='users') or (schemaname='storage' and tablename='objects') order by schemaname,tablename loop
        execute format('select md5(coalesce(string_agg(to_jsonb(x)::text, chr(10) order by to_jsonb(x)::text), '''')) from %I.%I x', t.schemaname,t.tablename) into h;
        all_rows:=all_rows||t.schemaname||'.'||t.tablename||':'||h;
      end loop;
      perform set_config('cercly.http_fixture_fingerprint',md5(all_rows),false);
    end $$; select current_setting('cercly.http_fixture_fingerprint');"""
    data_before = sql(data_fingerprint)
    before = sql('begin;' + old + "; select cercly_account_private.tiene_dependencias('00000000-0000-0000-0000-000000000000'); rollback;")
    check('sin excepción la cuota reproduce el bloqueo global', before == 't')
    sql(migration)
    check('propietario ACL SECURITY DEFINER y search_path conservados', sql(metadata) == acl_before)
    check('migración conserva datos preexistentes public Auth cuota y Storage', sql(data_fingerprint) == data_before)
    check('cuota corregida no bloquea identidad vacía', sql("select cercly_account_private.tiene_dependencias('00000000-0000-0000-0000-000000000000')") == 'f')

    simple = user('simple')
    neighbor = user('negocio ajeno')
    photo = user('foto propia')
    business, promotion = str(uuid.uuid4()), str(uuid.uuid4())
    category = sql('select id from public.categorias order by id limit 1')
    sql(f"""update public.usuarios set rol='administrador' where id='{neighbor['id']}';
      insert into public.establecimientos(id,propietario_id,categoria_id,nombre,direccion,latitud,longitud)
      values('{business}','{neighbor['id']}','{category}','Negocio sintético protegido','Dirección de prueba',0,0);
      insert into public.promociones(id,establecimiento_id,titulo,fecha_inicio,fecha_fin)
      values('{promotion}','{business}','Promoción sintética',now(),now()+interval '1 day');""")
    for subject in (simple, neighbor, photo):
        status, data = http('POST', '/rest/v1/rpc/consumir_cuota_rutas', {}, token=subject['token'])
        check('cuota HTTP propia ' + ('simple' if subject is simple else 'vecino' if subject is neighbor else 'foto'), status == 200 and data is True)
    s = simple['id']
    sql(f"""insert into public.preferencias_usuario(usuario_id,radio_metros) values('{s}',1000);
      insert into public.preferencias_usuario_categorias values('{s}','{category}');
      insert into public.push_preferences(user_id) values('{s}');
      insert into public.fcm_installations(installation_id,user_id,fcm_installation_id,platform,active)
      values(gen_random_uuid(),'{s}','synthetic-no-real-fcm-token','android',false);""")
    path_neighbor = f"{neighbor['id']}/{business}/foto.png"
    path_photo = f"{photo['id']}/{business}/foto-propia.png"
    for label, path, subject in [('vecino',path_neighbor,neighbor),('propia',path_photo,photo)]:
        status, _ = http('POST', '/storage/v1/object/establecimientos-imagenes/' + path, PNG, token=subject['token'])
        check('subida Storage HTTP ' + label, status == 200)
        status, data = http('GET', '/storage/v1/object/establecimientos-imagenes/' + path, admin=True, binary=True)
        check('bytes Storage verificables ' + label, status == 200 and data == PNG)
    sql(f"insert into public.fotos_establecimiento(establecimiento_id,ruta_storage) values('{business}','{path_neighbor}')")
    snapshot_query = f"""select jsonb_build_array(
      (select to_jsonb(u) from auth.users u where id='{neighbor['id']}'),
      (select to_jsonb(u) from public.usuarios u where id='{neighbor['id']}'),
      (select to_jsonb(e) from public.establecimientos e where id='{business}'),
      (select to_jsonb(p) from public.promociones p where id='{promotion}'),
      (select to_jsonb(f) from public.fotos_establecimiento f where establecimiento_id='{business}'),
      (select to_jsonb(q) from cercly_rutas_privado.rutas_limites_usuarios q where usuario_id='{neighbor['id']}'))"""
    neighbor_before = sql(snapshot_query)
    check('caso simple contiene relaciones y sesión reales', all(own_counts(s)[key] > 0 for key in ('auth','perfil','sesiones','refresh','cuota','preferencias','categorias','push','instalaciones')))
    status, _ = http('POST', HANDLER, {'p_usuario_id': neighbor['id']}, token=simple['token'])
    check('handler rechaza elegir sujeto ajeno', status == 400)
    delete_self(simple, 'eliminada')
    counts = own_counts(s)
    for key, value in counts.items():
        check('simple elimina ' + key, value == 0)
    status, data = http('GET','/auth/v1/user',token=simple['token'])
    error_code = data.get('error_code') or data.get('code')
    check('JWT viejo rechazado por Auth', status in (401,403,404) and error_code in ('user_not_found','session_not_found','bad_jwt'), {'http':status,'error_code':error_code})
    status, _ = http('POST','/auth/v1/token?grant_type=refresh_token',{'refresh_token':simple['refresh']})
    check('refresh viejo rechazado', status in (400,401))
    status, _ = http('POST','/rest/v1/rpc/consumir_cuota_rutas',{},token=simple['token'])
    check('JWT viejo no recrea cuota PostgreSQL', status >= 400 and own_counts(s)['cuota'] == 0)
    check('identidad perfil negocio promoción foto y cuota ajenos intactos', sql(snapshot_query) == neighbor_before)
    status, data = http('GET','/storage/v1/object/establecimientos-imagenes/'+path_neighbor,admin=True,binary=True)
    check('fotografía ajena conserva bytes y hash', status == 200 and hashlib.sha256(data).digest() == hashlib.sha256(PNG).digest())

    delete_self(photo, 'revision')
    check('foto propia bloquea borrado Auth y conserva sesión', own_counts(photo['id'])['auth'] == 1 and own_counts(photo['id'])['sesiones'] > 0)
    status, data = http('GET','/storage/v1/object/establecimientos-imagenes/'+path_photo,token=photo['token'],binary=True)
    check('revisión conserva foto propia', status == 200 and data == PNG)
    status, data = http('DELETE','/storage/v1/object/establecimientos-imagenes',{'prefixes':[path_photo]},token=photo['token'])
    check('supresión explícita Storage por titular sintético', status == 200 and len(data) == 1)
    status, _ = http('GET','/storage/v1/object/establecimientos-imagenes/'+path_photo,admin=True,binary=True)
    check('foto eliminada ya no es recuperable por API Storage', status in (400,404))
    check('metadato Storage propio eliminado', sql(f"select count(*) from storage.objects where name='{path_photo}'") == '0')
    # Una revisión nunca se convierte automáticamente en aprobación.
    delete_self(photo, 'revision')
    status, data = http('POST','/rest/v1/rpc/revisar_eliminacion_cuenta',{'p_usuario_id':photo['id'],'p_accion':'aprobar'},token=neighbor['token'])
    check('aprobación explícita por administrador sintético sin dependencias', status == 200 and data == 'aprobada')
    delete_self(photo, 'eliminada')
    check('cuenta con foto retirada completa Auth perfil sesiones solicitud', all(v == 0 for v in own_counts(photo['id']).values()))
    check('caso con foto no cambia datos ajenos', sql(snapshot_query) == neighbor_before)
    status, data = http('POST',HANDLER,{},token=neighbor['token'])
    check('propietario con negocio permanece en revisión', status == 202 and data.get('estado') == 'revision' and own_counts(neighbor['id'])['auth'] == 1)
    check('revisión no borra negocio promoción ni imagen ajenos', sql(snapshot_query) == neighbor_before)
    report = json.loads(args.report.read_text())
    report.update({'passed':len(results),'failed':0,'http_services':['GoTrue','PostgREST','Storage','Deno handler + supabase-js 2.75.0'], 'limitations':['No gateway Edge JWT; handler verifies getUser itself','No hosted Staging or Production','Storage API proves unreadability and metadata removal, not disk forensics or backups','No external email/OTP channel or device QA']})
    args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(f"{len(results)} PASS; 0 FAIL; LOCAL ONLY")


if __name__ == '__main__':
    main()
