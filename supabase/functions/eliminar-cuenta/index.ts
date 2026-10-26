import { createClient } from 'npm:@supabase/supabase-js@2.75.0';
import { completeDeletion } from './deletion_flow.mjs';

const url = Deno.env.get('SUPABASE_URL');
const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

function json(status: number, body: Record<string, unknown>): Response {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}

Deno.serve(async (request) => {
  try {
  if (request.method !== 'POST') return json(405, { estado: 'metodo_no_permitido' });
  if (!url || !anonKey || !serviceKey) return json(503, { estado: 'no_disponible' });
  const authorization = request.headers.get('Authorization') ?? '';
  const token = /^Bearer (\S+)$/i.exec(authorization)?.[1];
  if (!token) return json(401, { estado: 'sesion_requerida' });

  // El cuerpo no acepta IDs ni roles. La identidad siempre proviene de Auth.
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json(400, { estado: 'solicitud_invalida' });
  }
  if (body === null || typeof body !== 'object' || Array.isArray(body) ||
      Object.keys(body).length !== 0) {
    return json(400, { estado: 'solicitud_invalida' });
  }

  const publicClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: verified, error: authError } = await publicClient.auth.getUser(token);
  if (authError || !verified.user) return json(401, { estado: 'sesion_invalida' });
  const userId = verified.user.id;

  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: decision, error: requestError } = await userClient.rpc(
    'solicitar_eliminacion_cuenta',
  );
  if (requestError) {
    if (requestError.code === '42501') {
      return json(403, { estado: 'autenticacion_reciente_requerida' });
    }
    if (requestError.code === '28000') return json(401, { estado: 'sesion_invalida' });
    return json(503, { estado: 'estado_desconocido' });
  }
  // La credencial privilegiada existe solo en el runtime de esta función.
  // El flujo no usa la credencial si la solicitud requiere revisión.
  if (decision !== 'pendiente' && decision !== 'revision' && decision !== 'aprobada') {
    return json(503, { estado: 'estado_desconocido' });
  }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const outcome = await completeDeletion(decision, userId, admin);
  return json(outcome.status, outcome.body);
  } catch {
    // El estado puede ser ambiguo si se cortó la red después de deleteUser.
    return json(503, { estado: 'estado_desconocido' });
  }
});
