import { completeDeletion, completeQaDeletion } from './account_deletion_flow.mjs';
import { corsPolicy } from './account_deletion_cors.mjs';

const STAGING_URL = 'https://dlajxviqhkdcqnmczhvr.supabase.co';
const json = (status, body) => Response.json(body, {
  status, headers: { 'Cache-Control': 'no-store' },
});

// Configuración decidida en los entrypoints, nunca en body/query/headers.
function createHandler(createClient, config, qa) {
  const requestRpc = qa ? 'solicitar_eliminacion_cuenta_qa' : 'solicitar_eliminacion_cuenta';
  const complete = qa ? completeQaDeletion : completeDeletion;
  async function handle(request) {
    try {
      if (request.method !== 'POST') return json(405, { estado: 'metodo_no_permitido' });
      const { url, anonKey, serviceKey } = config;
      if (!url || !anonKey || !serviceKey || (qa && url !== STAGING_URL)) {
        return json(503, { estado: 'no_disponible' });
      }
      const token = /^Bearer (\S+)$/i.exec(request.headers.get('Authorization') ?? '')?.[1];
      if (!token) return json(401, { estado: 'sesion_requerida' });
      let body;
      try { body = await request.json(); }
      catch { return json(400, { estado: 'solicitud_invalida' }); }
      if (body === null || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).length) {
        return json(400, { estado: 'solicitud_invalida' });
      }
      const auth = { persistSession: false, autoRefreshToken: false };
      const verifier = createClient(url, anonKey, { auth });
      const { data: verified, error: authError } = await verifier.auth.getUser(token);
      if (authError || !verified.user) return json(401, { estado: 'sesion_invalida' });
      const userId = verified.user.id;
      const userClient = createClient(url, anonKey, {
        auth, global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const { data: decision, error } = await userClient.rpc(requestRpc);
      if (error) {
        if (error.code === '28000') return json(401, { estado: 'sesion_invalida' });
        if (error.code === '42501') return json(403, {
          estado: qa ? 'qa_no_autorizada' : 'autenticacion_reciente_requerida',
        });
        return json(503, { estado: 'estado_desconocido' });
      }
      if (!['pendiente', 'revision', 'aprobada'].includes(decision)) {
        return json(503, { estado: 'estado_desconocido' });
      }
      const admin = createClient(url, serviceKey, { auth });
      const result = await complete(decision, userId, admin, token);
      return json(result.status, result.body);
    } catch {
      return json(503, { estado: 'estado_desconocido' });
    }
  }
  return async request => {
    const cors = corsPolicy(request, config.allowedOrigins ?? '');
    if (cors.rejection) return new Response(null, { status: cors.rejection, headers: cors.headers });
    if (cors.preflight) return new Response(null, { status: 204, headers: cors.headers });
    const response = await handle(request);
    for (const [name, value] of Object.entries(cors.headers)) response.headers.set(name, value);
    return response;
  };
}

export const createNormalDeletionHandler = (createClient, config) => createHandler(createClient, config, false);
export const createQaDeletionHandler = (createClient, config) => createHandler(createClient, config, true);
