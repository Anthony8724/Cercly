import { createClient } from 'npm:@supabase/supabase-js@2.75.0';
import { parseSolicitud, parseORS, orsDirectionsUrl } from './routing_logic.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const limits = new Map<string, { starts: number; count: number }>();

function json(code: number, data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), {
    status: code, headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

// En Supabase hospedado pueden inyectarse claves nombradas como JSON.
// Nunca se lee ni transmite una clave secret/service_role al cliente.
function resolvePublicKey(): string | undefined {
  const direct = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY');
  if (direct) return direct;
  const named = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS');
  if (!named) return undefined;
  try {
    const parsed: unknown = JSON.parse(named);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return undefined;
    const key = (parsed as Record<string, unknown>).default;
    return typeof key === 'string' && key.startsWith('sb_publishable_')
      ? key : undefined;
  } catch {
    return undefined;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  if (req.method !== 'POST') return json(405, {error:'method_not_allowed'});

  const authHeader = req.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) return json(401, {error:'authentication_required'});
  const token = authHeader.slice(7).trim();
  if (!token || token.length > 10000) return json(401, {error:'invalid_session'});

  const baseUrl = Deno.env.get('SUPABASE_URL');
  const publicKey = resolvePublicKey();
  const orsKey = Deno.env.get('ORS_API_KEY');
  if (!baseUrl || !publicKey || !orsKey) return json(503, {error:'routing_not_configured'});

  // Segunda verificación: no basta con tener una cadena en Authorization.
  const client = createClient(baseUrl, publicKey, {
    global: {headers: {Authorization: authHeader}},
    auth: {persistSession:false, autoRefreshToken:false},
  });
  const {data: {user}, error} = await client.auth.getUser(token);
  if (error || !user) return json(401, {error:'invalid_session'});

  // Límite local por instancia. No sustituye un limitador persistente antes de producción.
  const now = Date.now();
  if (limits.size > 2000) limits.clear();
  const previous = limits.get(user.id);
  const state = !previous || now - previous.starts >= 60000
    ? {starts: now, count: 0} : previous;
  state.count += 1;
  limits.set(user.id, state);
  if (state.count > 10) return json(429, {error:'too_many_requests'});

  let requestData: unknown;
  try {
    const raw = await req.text();
    if (raw.length > 2048) return json(413, {error:'request_too_large'});
    requestData = JSON.parse(raw);
  } catch {
    return json(400, {error:'invalid_json'});
  }
  const r = parseSolicitud(requestData);
  if (!r) return json(400, {error:'invalid_coordinates_or_profile'});

  // Posición usada solo para responder esta solicitud; no se registra.
  try {
    const response = await fetch(
      orsDirectionsUrl(r.perfil),
      {
        method: 'POST',
        headers: {
          Authorization: orsKey,
          'Content-Type': 'application/json',
          Accept: 'application/geo+json, application/json',
        },
        body: JSON.stringify({
          coordinates: [
            [r.origen[1], r.origen[0]],
            [r.destino[1], r.destino[0]],
          ],
        }),
        signal: AbortSignal.timeout(12000),
      },
    );
    if (response.status === 429) return json(429, {error:'provider_limit'});
    if (response.status === 401 || response.status === 403) {
      return json(503, {error:'routing_provider_not_authorized'});
    }
    if ([400,404,422].includes(response.status)) return json(422, {error:'route_not_found'});
    if (!response.ok) return json(502, {error:'provider_unavailable'});
    const raw = await response.text();
    if (raw.length > 2_000_000) return json(502, {error:'provider_response_too_large'});
    const parsed = parseORS(JSON.parse(raw));
    if (!parsed) return json(502, {error:'invalid_provider_response'});
    return json(200, parsed as unknown as Record<string, unknown>);
  } catch {
    return json(502, {error:'provider_unavailable'});
  }
});
