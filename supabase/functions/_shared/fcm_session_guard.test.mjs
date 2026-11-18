import test from 'node:test';
import assert from 'node:assert/strict';
import { verifiedFcmSession, maySendReservedFcm } from './fcm_session_guard.mjs';

const session = '12345678-abcd-4abc-8abc-123456789abc';
const reservation = '22345678-abcd-4abc-8abc-123456789abc';

test('sesión se acepta únicamente si Auth la confirma', async () => {
  assert.equal(await verifiedFcmSession({ rpc: async () => ({ data: session, error: null }) }), session);
  assert.equal(await verifiedFcmSession({ rpc: async () => ({ data: session, error: { code: '28000' } }) }), null);
  assert.equal(await verifiedFcmSession({ rpc: async () => ({ data: 'invalid', error: null }) }), null);
});

test('envío exige autorización explícita y comprueba ambos identificadores', async () => {
  let parameters;
  const admin = { rpc: async (name, params) => { parameters = { name, ...params }; return { data: true, error: null }; } };
  assert.equal(await maySendReservedFcm(admin, reservation, session), true);
  assert.deepEqual(parameters, { name: 'entrega_fcm_autorizada', p_reservation_id: reservation, p_session_id: session });
  assert.equal(await maySendReservedFcm(admin, 'invalid', session), false);
  assert.equal(await maySendReservedFcm({ rpc: async () => ({ data: false, error: null }) }, reservation, session), false);
  assert.equal(await maySendReservedFcm({ rpc: async () => ({ data: true, error: { code: 'offline' } }) }, reservation, session), false);
});
