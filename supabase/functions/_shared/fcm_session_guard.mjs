const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// JWT identity is authenticated by the caller; the RPC also checks that its
// session still exists in Auth and belongs to that identity.
export async function verifiedFcmSession(client) {
  const { data, error } = await client.rpc('mi_sesion_fcm_activa');
  return !error && typeof data === 'string' && uuid.test(data) ? data : null;
}

// A second check occurs immediately before contacting the provider. It cannot
// retract a message once the provider has accepted it.
export async function maySendReservedFcm(admin, reservationId, sessionId) {
  if (!uuid.test(reservationId) || !uuid.test(sessionId)) return false;
  const { data, error } = await admin.rpc('entrega_fcm_autorizada', {
    p_reservation_id: reservationId,
    p_session_id: sessionId,
  });
  return !error && data === true;
}
