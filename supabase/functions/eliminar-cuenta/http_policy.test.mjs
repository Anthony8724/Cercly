import assert from 'node:assert/strict';
import test from 'node:test';
import { corsPolicy } from './http_policy.mjs';
const origin = 'https://cercly.example';
const preflight = (headers = {}) => new Request('https://api.example', {
  method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': 'POST',
    'Access-Control-Request-Headers': 'authorization, apikey, content-type', ...headers },
});
test('preflight web aprobado únicamente para origen configurado y POST', () => {
  const r = corsPolicy(preflight(), origin);
  assert.equal(r.preflight, true);
  assert.equal(r.headers['Access-Control-Allow-Origin'], origin);
  assert.equal(r.headers['Cache-Control'], 'no-store');
});
test('origen desconocido o configuración vacía se deniegan', () => {
  assert.equal(corsPolicy(preflight()).rejection, 403);
  assert.equal(corsPolicy(preflight({ Origin: 'https://evil.example' }), origin).rejection, 403);
});
test('HTTP y origen null no se aceptan', () => {
  assert.equal(corsPolicy(preflight({ Origin: 'null' }), 'null').rejection, 403);
  assert.equal(corsPolicy(preflight({ Origin: 'http://cercly.example' }), 'http://cercly.example').rejection, 403);
});
test('no permite métodos ni headers adicionales', () => {
  assert.equal(corsPolicy(preflight({ 'Access-Control-Request-Method': 'DELETE' }), origin).rejection, 403);
  assert.equal(corsPolicy(preflight({ 'Access-Control-Request-Headers': 'x-admin' }), origin).rejection, 403);
});
test('POST móvil sin Origin conserva Auth y respuesta sin caché', () => {
  const r = corsPolicy(new Request('https://api.example', { method: 'POST' }));
  assert.equal(r.rejection, undefined);
  assert.equal(r.headers['Access-Control-Allow-Origin'], undefined);
});
test('POST web conserva CORS en respuestas de éxito y error', () => {
  const r = corsPolicy(new Request('https://api.example', { method: 'POST', headers: { Origin: origin } }), origin);
  assert.equal(r.rejection, undefined);
  assert.equal(r.headers['Access-Control-Allow-Origin'], origin);
});
