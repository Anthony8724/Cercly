// Navegador: orígenes explícitos de despliegue; clientes móviles sin Origin.
// Ningún origen se infiere de la petición ni se permite con '*'.
export function corsPolicy(request, configuredOrigins = '') {
  const origin = request.headers.get('Origin');
  const allowed = new Set(configuredOrigins.split(',').map(s => s.trim()).filter(Boolean));
  const headers = { 'Cache-Control': 'no-store', Vary: 'Origin' };
  if (origin) {
    let valid = false;
    try {
      const parsed = new URL(origin);
      valid = parsed.protocol === 'https:' && parsed.origin === origin && allowed.has(origin);
    } catch { /* Entrada no válida: denegar. */ }
    if (!valid) return { rejection: 403, headers };
    headers['Access-Control-Allow-Origin'] = origin;
  }
  if (request.method === 'OPTIONS') {
    if (!origin || request.headers.get('Access-Control-Request-Method') !== 'POST') {
      return { rejection: 403, headers };
    }
    const permitted = ['authorization', 'apikey', 'x-client-info', 'content-type'];
    const requested = (request.headers.get('Access-Control-Request-Headers') || '')
      .split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
    if (requested.some(s => !permitted.includes(s))) return { rejection: 403, headers };
    headers['Access-Control-Allow-Methods'] = 'POST';
    headers['Access-Control-Allow-Headers'] = permitted.join(', ');
    return { preflight: true, headers };
  }
  return { headers };
}
