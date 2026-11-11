import test from 'node:test';
import assert from 'node:assert/strict';
import { createNormalDeletionHandler, createQaDeletionHandler } from './account_deletion_handler.mjs';

const config = { url: 'https://dlajxviqhkdcqnmczhvr.supabase.co', anonKey: 'synthetic-public',
  serviceKey: 'synthetic-server', allowedOrigins: 'https://normal.example' };
function fixture({ requestError = null, authError = null, decision = 'pendiente',
  allowed = true, signOutError = null, deletionError = null } = {}) {
  const calls = [];
  const createClient = (_url, key, options) => {
    calls.push(['client', key === config.serviceKey ? 'server' : 'public']);
    if (key === config.serviceKey) return {
      rpc: async (name, params) => { calls.push(['admin-rpc', name, params]);
        return name.startsWith('validar_') ? { data: allowed, error: null } : { error: null }; },
      auth: { admin: {
        signOut: async (_token, scope) => { calls.push(['signOut', scope]); return { error: signOutError }; },
        deleteUser: async (id, soft) => { calls.push(['delete', id, soft]); return { error: deletionError }; },
      } },
    };
    if (options.global) return { rpc: async (name, ...args) => {
      calls.push(['user-rpc', name, args]); return { data: decision, error: requestError };
    } };
    return { auth: { getUser: async () => {
      calls.push(['getUser']); return { data: { user: authError ? null : { id: 'verified-own-subject' } }, error: authError };
    } } };
  };
  return { createClient, calls };
}
const req = (body = {}, suffix = '', headers = {}) => new Request('https://edge.example'+suffix, {
  method: 'POST', headers: { Authorization: 'Bearer synthetic-token', 'Content-Type': 'application/json', ...headers },
  body: JSON.stringify(body),
});
const rpcNames = f => f.calls.filter(c => c[0].endsWith('rpc')).map(c => c[1]);

test('normal conserva solicitud y validación normales y borra solo getUser.id', async () => {
  const f = fixture(); const r = await createNormalDeletionHandler(f.createClient, config)(req());
  assert.equal(r.status, 200); assert.equal((await r.json()).estado, 'eliminada');
  assert.deepEqual(rpcNames(f), ['solicitar_eliminacion_cuenta', 'validar_eliminacion_cuenta',
    'validar_eliminacion_cuenta', 'finalizar_eliminacion_cuenta']);
  assert.deepEqual(f.calls.find(c => c[0] === 'delete'), ['delete', 'verified-own-subject', false]);
});
test('QA usa exclusivamente solicitud y validaciones QA', async () => {
  const f = fixture(); const r = await createQaDeletionHandler(f.createClient, config)(req());
  assert.equal(r.status, 200);
  assert.deepEqual(rpcNames(f), ['solicitar_eliminacion_cuenta_qa', 'validar_eliminacion_cuenta_qa',
    'validar_eliminacion_cuenta_qa', 'finalizar_eliminacion_cuenta']);
});
test('QA denegado no cae a normal ni usa el servidor para borrar', async () => {
  const f = fixture({ requestError: { code: '42501' } });
  const r = await createQaDeletionHandler(f.createClient, config)(req());
  assert.equal(r.status, 403); assert.equal((await r.json()).estado, 'qa_no_autorizada');
  assert.deepEqual(rpcNames(f), ['solicitar_eliminacion_cuenta_qa']);
  assert.equal(f.calls.some(c => c[0] === 'delete' || c[0] === 'signOut' || c[1] === 'server'), false);
});
test('identidad QA denegada en normal no dispara ruta QA automáticamente', async () => {
  const f = fixture({ requestError: { code: '42501' } });
  const r = await createNormalDeletionHandler(f.createClient, config)(req());
  assert.equal(r.status, 403); assert.deepEqual(rpcNames(f), ['solicitar_eliminacion_cuenta']);
  assert.equal(f.calls.some(c => c[0] === 'delete'), false);
});
test('QA fuera de STAGING no inicia siquiera SDK/Auth', async () => {
  const f = fixture(); const r = await createQaDeletionHandler(f.createClient,
    { ...config, url: 'https://other-environment.example' })(req());
  assert.equal(r.status, 503); assert.deepEqual(f.calls, []);
});
test('body no permite ID ajeno, rol, ensayo o modo QA en ninguna ruta', async () => {
  for (const factory of [createNormalDeletionHandler, createQaDeletionHandler]) {
    for (const body of [{ user_id: 'foreign' }, { mode: 'qa' }, { qa: true }, { ensayo_id: 'foreign' }, { role: 'admin' }]) {
      const f = fixture(); const r = await factory(f.createClient, config)(req(body));
      assert.equal(r.status, 400); assert.deepEqual(f.calls, []);
    }
  }
});
test('query y headers del cliente no cambian ruta ni sujeto', async () => {
  const f = fixture(); await createNormalDeletionHandler(f.createClient, config)(req({},
    '/?mode=qa&user_id=foreign', { 'X-Cercly-Mode': 'qa' }));
  assert.equal(rpcNames(f).some(n => n.endsWith('_qa')), false);
  assert.deepEqual(f.calls.find(c => c[0] === 'delete'), ['delete', 'verified-own-subject', false]);
});
test('Auth debe verificar identidad en ambas rutas', async () => {
  for (const factory of [createNormalDeletionHandler, createQaDeletionHandler]) {
    const f = fixture({ authError: { message: 'synthetic' } });
    assert.equal((await factory(f.createClient, config)(req())).status, 401);
    assert.deepEqual(rpcNames(f), []);
  }
});
test('historial normal en revisión conserva estado sin borrado ni signOut', async () => {
  const f = fixture({ decision: 'revision' });
  const r = await createNormalDeletionHandler(f.createClient, config)(req());
  assert.equal(r.status, 202); assert.equal((await r.json()).estado, 'revision');
  assert.equal(f.calls.some(c => c[0] === 'delete' || c[0] === 'signOut' || c[0] === 'admin-rpc'), false);
});
test('validación QA falsa impide revocar o borrar', async () => {
  const f = fixture({ allowed: false });
  assert.equal((await createQaDeletionHandler(f.createClient, config)(req())).status, 202);
  assert.equal(f.calls.some(c => c[0] === 'delete' || c[0] === 'signOut'), false);
});
test('fallo de signOut QA no continúa al borrado', async () => {
  const f = fixture({ signOutError: { message: 'synthetic' } });
  assert.equal((await createQaDeletionHandler(f.createClient, config)(req())).status, 503);
  assert.equal(f.calls.some(c => c[0] === 'delete'), false);
});
test('fallo de Auth DELETE QA no finaliza ni declara éxito', async () => {
  const f = fixture({ deletionError: { message: 'synthetic' } });
  const r = await createQaDeletionHandler(f.createClient, config)(req());
  assert.equal(r.status, 503); assert.equal((await r.json()).estado, 'solicitud_pendiente');
  assert.equal(rpcNames(f).includes('finalizar_eliminacion_cuenta'), false);
});
test('orígenes CORS QA y normal se configuran por separado', async () => {
  const f = fixture(); const origin = 'https://qa.example';
  const qa = createQaDeletionHandler(f.createClient, { ...config, allowedOrigins: origin });
  const normal = createNormalDeletionHandler(f.createClient, config);
  const options = () => new Request('https://edge.example', { method: 'OPTIONS', headers: {
    Origin: origin, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,apikey,content-type',
  } });
  const r = await qa(options()); assert.equal(r.status, 204);
  assert.equal(r.headers.get('Access-Control-Allow-Origin'), origin);
  assert.equal((await normal(options())).status, 403);
  assert.deepEqual(f.calls, []);
});
