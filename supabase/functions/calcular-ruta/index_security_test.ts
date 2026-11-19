import { assertEquals, assert } from 'jsr:@std/assert@1.0.14';

// Ejecuta el entrypoint real con HTTP interceptado; no abre sockets ni consume cuota.
type Handler = (request: Request) => Promise<Response>;
let handler: Handler;
const serve = Deno.serve;
Deno.serve = ((fn: Handler) => { handler = fn; }) as unknown as typeof Deno.serve;
try {
  await import('./index.ts');
} finally {
  Deno.serve = serve;
}

const valid = {origen: [0.8116, -77.7172], destino: [0.815, -77.72], perfil: 'foot-walking'};
const geometry = {features: [{geometry: {coordinates: [[-77.7172, 0.8116], [-77.72, 0.815]]}, properties: {summary: {distance: 493, duration: 354}}}]};

interface Scenario {
  name: string; expected: number; auth?: boolean; method?: string; body?: string;
  userStatus?: number; quota?: boolean | null; providerStatus?: number;
  providerBody?: unknown; offline?: boolean;
}

for (const scenario of [
  {name: 'sin sesión no consulta red', auth: false, expected: 401},
  {name: 'rechaza método GET', method: 'GET', expected: 405},
  {name: 'sesión inválida', userStatus: 401, expected: 401},
  {name: 'JSON inválido', body: '{', expected: 400},
  {name: 'payload excesivo', body: 'x'.repeat(2049), expected: 413},
  {name: 'coordenadas inválidas', body: JSON.stringify({...valid, origen: [200, 0]}), expected: 400},
  {name: 'cuota agotada no llama al proveedor', quota: false, expected: 429},
  {name: 'cuota indisponible falla cerrado', quota: null, expected: 503},
  {name: 'límite del proveedor', providerStatus: 429, expected: 429},
  {name: 'proveedor sin autorización 401', providerStatus: 401, expected: 503},
  {name: 'proveedor sin autorización 403', providerStatus: 403, expected: 503},
  {name: 'sin recorrido', providerStatus: 422, expected: 422},
  {name: 'proveedor con error', providerStatus: 500, expected: 502},
  {name: 'fallo de red', offline: true, expected: 502},
  {name: 'respuesta malformada', providerBody: {}, expected: 502},
  {name: 'ruta válida envía solo coordenadas', expected: 200},
] satisfies Scenario[]) {
  Deno.test(scenario.name, async () => {
    const c: Scenario = scenario;
    const variables = {SUPABASE_URL: 'https://supabase.invalid', SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test', ORS_API_KEY: 'server-only-test'};
    const saved = new Map(Object.keys(variables).map(key => [key, Deno.env.get(key)]));
    for (const [key, value] of Object.entries(variables)) Deno.env.set(key, value);
    const fetch = globalThis.fetch;
    const calls: string[] = [];
    globalThis.fetch = async (input, init) => {
      const url = input instanceof Request ? input.url : String(input);
      calls.push(url);
      if (url.includes('/auth/v1/user')) return Response.json({id: 'test-user'}, {status: c.userStatus ?? 200});
      if (url.includes('/rest/v1/rpc/consumir_cuota_rutas')) return Response.json(c.quota === undefined ? true : c.quota);
      assertEquals(url, 'https://api.heigit.org/openrouteservice/v2/directions/foot-walking/geojson');
      assertEquals(new Headers(init?.headers).get('authorization'), 'server-only-test');
      assertEquals(JSON.parse(String(init?.body)), {coordinates: [[-77.7172, 0.8116], [-77.72, 0.815]]});
      if (c.offline) throw new TypeError('network unavailable');
      return Response.json(c.providerBody ?? geometry, {status: c.providerStatus ?? 200});
    };
    try {
      const response = await handler!(new Request('https://edge.invalid', {
        method: c.method ?? 'POST',
        headers: c.auth === false ? {} : {authorization: 'Bearer test-session'},
        ...((c.method ?? 'POST') === 'POST' ? {body: c.body ?? JSON.stringify(valid)} : {}),
      }));
      assertEquals(response.status, c.expected);
      const text = await response.text();
      assert(!text.includes('server-only-test'));
      if (c.auth === false || c.method === 'GET') assertEquals(calls.length, 0);
      if (c.quota === false || c.quota === null) assert(!calls.some(url => url.includes('api.heigit.org')));
    } finally {
      globalThis.fetch = fetch;
      for (const [key, value] of saved) {
        if (value === undefined) Deno.env.delete(key); else Deno.env.set(key, value);
      }
    }
  });
}
