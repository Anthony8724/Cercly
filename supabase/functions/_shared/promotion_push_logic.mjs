const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parsePushLocationRequest(value, now = Date.now()) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const observedAtMs = Date.parse(value.observed_at);
  if (
    !UUID.test(value.installation_id ?? '') ||
    !UUID.test(value.event_id ?? '') ||
    !Number.isFinite(value.latitude) || value.latitude < -90 || value.latitude > 90 ||
    !Number.isFinite(value.longitude) || value.longitude < -180 || value.longitude > 180 ||
    !Number.isFinite(value.accuracy_meters) || value.accuracy_meters <= 0 || value.accuracy_meters > 100 ||
    !Number.isFinite(observedAtMs) || observedAtMs < now - 120_000 || observedAtMs > now + 15_000 ||
    !Number.isInteger(value.utc_offset_minutes) || value.utc_offset_minutes < -840 || value.utc_offset_minutes > 840
  ) return null;

  return {
    installationId: value.installation_id.toLowerCase(),
    eventId: value.event_id.toLowerCase(),
    latitude: value.latitude,
    longitude: value.longitude,
    accuracyMeters: value.accuracy_meters,
    observedAt: new Date(observedAtMs).toISOString(),
    utcOffsetMinutes: value.utc_offset_minutes,
  };
}

export function isFcmReservation(value) {
  return Boolean(
    value &&
    UUID.test(value.reservation_id ?? '') &&
    UUID.test(value.event_id ?? '') &&
    UUID.test(value.promotion_id ?? '') &&
    UUID.test(value.establishment_id ?? '') &&
    typeof value.fcm_installation_id === 'string' && value.fcm_installation_id.length >= 16 &&
    typeof value.promotion_title === 'string' && value.promotion_title.length > 0 && value.promotion_title.length <= 120 &&
    typeof value.establishment_name === 'string' && value.establishment_name.length > 0 && value.establishment_name.length <= 120,
  );
}

export function buildFcmMessage(reservation, now = Date.now()) {
  if (!isFcmReservation(reservation)) return null;
  const expiresAt = String(Math.floor(now / 1000) + 120);
  return {
    fid: reservation.fcm_installation_id,
    notification: {
      title: 'Promoción cerca de ti',
      body: `${reservation.promotion_title} en ${reservation.establishment_name}`,
    },
    data: {
      type: 'promotion',
      event_id: reservation.event_id,
      promotion_id: reservation.promotion_id,
      establishment_id: reservation.establishment_id,
      title: reservation.promotion_title,
      body: reservation.establishment_name,
    },
    android: {
      priority: 'HIGH',
      ttl: '120s',
      notification: {
        channel_id: 'promociones_cercanas',
        tag: reservation.event_id,
      },
    },
    apns: {
      headers: {
        'apns-collapse-id': reservation.event_id,
        'apns-expiration': expiresAt,
      },
      payload: { aps: { sound: 'default' } },
    },
  };
}
