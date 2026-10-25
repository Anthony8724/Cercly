import assert from 'node:assert/strict';
import test from 'node:test';
import { completeDeletion } from './deletion_flow.mjs';

const userId = 'b7000000-0000-0000-0000-000000000001';

function admin({ deletionError = null, finalizeError = null } = {}) {
  const calls = [];
  return {
    calls,
    auth: { admin: { async deleteUser(id, soft) {
      calls.push(['delete', id, soft]);
      return { error: deletionError };
    } } },
    async rpc(name, params) {
      calls.push(['rpc', name, params]);
      return { error: finalizeError };
    },
  };
}

test('cuenta simple elimina Auth y luego limpia el registro', async () => {
  const fake = admin();
  const result = await completeDeletion('pendiente', userId, fake);
  assert.deepEqual(result, { status: 200, body: { estado: 'eliminada' } });
  assert.deepEqual(fake.calls, [
    ['delete', userId, false],
    ['rpc', 'finalizar_eliminacion_cuenta', { p_usuario_id: userId }],
  ]);
});

test('propietario o administrador no dispara borrado', async () => {
  const fake = admin();
  const result = await completeDeletion('revision', userId, fake);
  assert.equal(result.status, 202);
  assert.deepEqual(fake.calls, []);
});

test('fallo de Auth deja solicitud pendiente y no finaliza', async () => {
  const fake = admin({ deletionError: new Error('storage') });
  const result = await completeDeletion('pendiente', userId, fake);
  assert.deepEqual(result, { status: 503, body: { estado: 'solicitud_pendiente' } });
  assert.equal(fake.calls.length, 1);
});

test('fallo después de borrar Auth informa registro pendiente', async () => {
  const fake = admin({ finalizeError: new Error('database') });
  const result = await completeDeletion('pendiente', userId, fake);
  assert.deepEqual(result, {
    status: 200,
    body: { estado: 'eliminada', registro_pendiente: true },
  });
});

test('estado inesperado no hace operaciones privilegiadas', async () => {
  const fake = admin();
  const result = await completeDeletion('otro', userId, fake);
  assert.equal(result.status, 503);
  assert.deepEqual(fake.calls, []);
});
