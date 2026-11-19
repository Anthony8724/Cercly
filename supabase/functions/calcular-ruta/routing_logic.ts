// Lógica pura y comprobable sin tocar red, credenciales ni Supabase.
export type PerfilRuta = 'foot-walking' | 'driving-car';

// URL pública vigente: el dominio api.openrouteservice.org fue retirado en 2026.
// Solo un perfil validado por parseSolicitud llega a esta función.
export function orsDirectionsUrl(perfil: PerfilRuta): string {
  return `https://api.heigit.org/openrouteservice/v2/directions/${perfil}/geojson`;
}
export type Coordenada = [number, number]; // [latitud, longitud]
export interface SolicitudRuta {
  origen: Coordenada;
  destino: Coordenada;
  perfil: PerfilRuta;
}

function valido(p: unknown): p is Coordenada {
  return Array.isArray(p) && p.length === 2 &&
    typeof p[0] === 'number' && Number.isFinite(p[0]) && Math.abs(p[0]) <= 90 &&
    typeof p[1] === 'number' && Number.isFinite(p[1]) && Math.abs(p[1]) <= 180;
}

function distanciaRectaKm(a: Coordenada, b: Coordenada): number {
  const rad = Math.PI / 180;
  const dLat = (b[0] - a[0]) * rad;
  const dLon = (b[1] - a[1]) * rad;
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(Math.max(0, 1 - h)));
}

export function parseSolicitud(value: unknown): SolicitudRuta | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const data = value as Record<string, unknown>;
  const { origen, destino, perfil } = data;
  if (!valido(origen) || !valido(destino)) return null;
  if (perfil !== 'foot-walking' && perfil !== 'driving-car') return null;
  // Cercly ofrece rutas cercanas; limitar solicitudes abusivas o accidentales.
  const km = distanciaRectaKm(origen, destino);
  if (km < 0.01 || km > 150) return null;
  return { origen, destino, perfil };
}

export interface RespuestaRuta {
  puntos: Coordenada[];
  distanciaMetros: number;
  duracionSegundos: number;
}

export function parseORS(value: unknown): RespuestaRuta | null {
  try {
    if (!value || typeof value !== 'object') return null;
    const feature = (value as {features?: unknown[]}).features?.[0] as
      {geometry?: {coordinates?: unknown[]}; properties?: {summary?: Record<string, unknown>}} | undefined;
    if (!feature) return null;
    const coords = feature.geometry?.coordinates;
    const summary = feature.properties?.summary;
    if (!Array.isArray(coords) || coords.length < 2 || coords.length > 5000 || !summary) return null;
    const distance = summary.distance;
    const duration = summary.duration;
    if (typeof distance !== 'number' || !Number.isFinite(distance) || distance <= 0 ||
        typeof duration !== 'number' || !Number.isFinite(duration) || duration <= 0) return null;
    const puntos: Coordenada[] = [];
    for (const pair of coords) {
      if (!Array.isArray(pair) || pair.length < 2) return null;
      const punto = [pair[1], pair[0]];
      if (!valido(punto)) return null;
      puntos.push(punto);
    }
    return { puntos, distanciaMetros: distance, duracionSegundos: duration };
  } catch {
    return null;
  }
}
