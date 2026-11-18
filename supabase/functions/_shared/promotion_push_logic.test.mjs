import test from 'node:test';
import assert from 'node:assert/strict';
import { buildFcmMessage, isFcmReservation, parsePushLocationRequest } from './promotion_push_logic.mjs';

const now = Date.parse('2026-11-11T12:00:00Z');
const freshLocation = (overrides = {}) => ({
  installation_id: 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  event_id: 'bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  latitude: -0.22,
  longitude: -78.51,
  accuracy_meters: 30,
  observed_at: new Date(now).toISOString(),
  utc_offset_minutes: -300,
  ...overrides,
});

test('accepts a fresh, precise and consent-ready location event', () => {
  const parsed = parsePushLocationRequest(freshLocation(), now);
  assert.equal(parsed?.accuracyMeters, 30);
  assert.equal(parsed?.eventId, 'bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
});

test('accepts exactly the configured freshness boundary and rejects stale fixes', () => {
  assert.ok(parsePushLocationRequest(freshLocation({
    observed_at: new Date(now - 120_000).toISOString(),
  }), now));
  assert.equal(parsePushLocationRequest(freshLocation({
    observed_at: new Date(now - 120_001).toISOString(),
  }), now), null);
  assert.equal(parsePushLocationRequest(freshLocation({
    observed_at: new Date(now + 15_001).toISOString(),
  }), now), null);
});

test('rejects imprecise, invalid-coordinate and malformed installation events', () => {
  assert.equal(parsePushLocationRequest(freshLocation({ accuracy_meters: 100.01 }), now), null);
  assert.equal(parsePushLocationRequest(freshLocation({ latitude: 90.1 }), now), null);
  assert.equal(parsePushLocationRequest(freshLocation({ longitude: -181 }), now), null);
  assert.equal(parsePushLocationRequest(freshLocation({ installation_id: 'not-an-id' }), now), null);
});

test('builds an FID-targeted message with short expiry and bounded IDs', () => {
  const reservation = {
    reservation_id: 'ccccccc3-cccc-4ccc-8ccc-cccccccccccc',
    event_id: 'bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    promotion_id: 'ddddddd4-dddd-4ddd-8ddd-dddddddddddd',
    establishment_id: 'eeeeeee5-eeee-4eee-8eee-eeeeeeeeeeee',
    fcm_installation_id: 'firebase-installation-id-123456',
    promotion_title: '20% de descuento',
    establishment_name: 'Café Cercly',
  };
  assert.equal(isFcmReservation(reservation), true);
  const message = buildFcmMessage(reservation, now);
  assert.equal(message.fid, reservation.fcm_installation_id);
  assert.equal('token' in message, false);
  assert.equal(message.android.ttl, '120s');
  assert.equal(message.apns.headers['apns-expiration'], String(now / 1000 + 120));
  assert.equal(isFcmReservation({ reservation_id: 'not-an-id' }), false);
});
