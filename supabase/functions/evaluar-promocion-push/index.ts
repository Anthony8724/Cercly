import { createClient } from 'npm:@supabase/supabase-js@2.75.0';
import {
  buildFcmMessage,
  isFcmReservation,
  parsePushLocationRequest,
} from '../_shared/promotion_push_logic.mjs';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

let cachedAccessToken: { value: string; expiresAt: number } | undefined;

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') return response(405, { error: 'method_not_allowed' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const accountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!supabaseUrl || !publishableKey || !serviceRoleKey || !accountJson) {
    return response(503, { error: 'push_sender_not_configured' });
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return response(401, { error: 'authentication_required' });
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) return response(401, { error: 'invalid_session' });

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return response(400, { error: 'invalid_json' });
  }
  const location = parsePushLocationRequest(raw);
  if (!location) return response(400, { error: 'invalid_or_stale_location' });

  let serviceAccount: Record<string, unknown>;
  try {
    serviceAccount = JSON.parse(accountJson);
  } catch {
    return response(503, { error: 'push_sender_not_configured' });
  }
  if (
    serviceAccount.type !== 'service_account' ||
    typeof serviceAccount.client_email !== 'string' ||
    typeof serviceAccount.private_key !== 'string' ||
    typeof serviceAccount.project_id !== 'string' ||
    !/^[a-z0-9-]{4,80}$/.test(serviceAccount.project_id)
  ) {
    return response(503, { error: 'push_sender_not_configured' });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc('reservar_promocion_push_reciente', {
    p_user_id: authData.user.id,
    p_installation_id: location.installationId,
    p_event_id: location.eventId,
    p_latitude: location.latitude,
    p_longitude: location.longitude,
    p_accuracy_meters: location.accuracyMeters,
    p_observed_at: location.observedAt,
    p_utc_offset_minutes: location.utcOffsetMinutes,
  });
  if (error) {
    console.error('push reservation failed', error.code ?? 'database_error');
    return response(500, { error: 'reservation_failed' });
  }
  const reservation = Array.isArray(data) ? data[0] : data;
  if (!reservation) return response(200, { reserved: false });
  if (!isFcmReservation(reservation)) {
    return response(500, { error: 'invalid_reservation' });
  }

  try {
    const accessToken = await googleAccessToken(serviceAccount);
    const fcmMessage = buildFcmMessage(reservation);
    if (!fcmMessage) throw new Error('invalid_fcm_reservation');
    const payload = { message: fcmMessage };
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      },
    );
    const result = await fcmResponse.json().catch(() => ({}));
    if (!fcmResponse.ok) {
      const providerCode = result?.error?.details?.[0]?.errorCode;
      const status = providerCode === 'UNREGISTERED' ? 'invalid_token' : 'failed';
      await admin.rpc('finalizar_reserva_promocion_push', {
        p_reservation_id: reservation.reservation_id,
        p_status: status,
        p_provider_message_id: null,
      });
      return response(502, { error: 'push_delivery_failed' });
    }
    await admin.rpc('finalizar_reserva_promocion_push', {
      p_reservation_id: reservation.reservation_id,
      p_status: 'sent',
      p_provider_message_id: result?.name ?? null,
    });
    return response(200, { reserved: true, sent: true });
  } catch (error) {
    console.error('push delivery failed', error instanceof Error ? error.name : 'unknown');
    await admin.rpc('finalizar_reserva_promocion_push', {
      p_reservation_id: reservation.reservation_id,
      p_status: 'failed',
      p_provider_message_id: null,
    });
    return response(502, { error: 'push_delivery_failed' });
  }
});

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function googleAccessToken(account: Record<string, unknown>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.value;
  }
  const email = account.client_email as string;
  const privateKey = account.private_key as string;
  const tokenUri = account.token_uri === 'https://oauth2.googleapis.com/token'
    ? account.token_uri
    : 'https://oauth2.googleapis.com/token';
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const keyData = pemBytes(privateKey);
  const key = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`;
  const tokenResponse = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const tokenData = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || typeof tokenData.access_token !== 'string') {
    throw new Error('google_oauth_failed');
  }
  cachedAccessToken = {
    value: tokenData.access_token,
    expiresAt: now + Math.min(Number(tokenData.expires_in) || 3600, 3600),
  };
  return cachedAccessToken.value;
}

function pemBytes(pem: string): Uint8Array {
  const base64 = pem.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function base64Url(value: string): string {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(value: Uint8Array): string {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
