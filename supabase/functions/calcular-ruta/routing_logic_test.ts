import { assertEquals, assert } from 'jsr:@std/assert@1.0.14';
import { parseORS, parseSolicitud } from './routing_logic.ts';

Deno.test('acepta solicitud cercana de Tulcán', () => {
  const r = parseSolicitud({
    origen: [0.8116, -77.7172], destino: [0.8150, -77.7200], perfil: 'foot-walking',
  });
  assertEquals(r?.perfil, 'foot-walking');
});
Deno.test('rechaza coordenadas invalidas y perfil arbitrario', () => {
  assertEquals(parseSolicitud({ origen:[200,-77], destino:[0,-77], perfil:'driving-car'}), null);
  assertEquals(parseSolicitud({ origen:[0.8116,-77.7172], destino:[0.815,-77.72], perfil:'hiking'}), null);
  assertEquals(parseSolicitud({ origen:[0.8116,-77.7172], destino:[0.8116,-77.7172], perfil:'driving-car'}), null);
});
Deno.test('extrae ruta ORS en orden latitud, longitud', () => {
  const result = parseORS({features:[{geometry:{coordinates:[[-77.7172,0.8116],[-77.72,0.815]]},properties:{summary:{distance:625,duration:500}}}]});
  assert(result !== null);
  assertEquals(result?.puntos[0],[0.8116,-77.7172]);
  assertEquals(result?.distanciaMetros,625);
});
Deno.test('rechaza respuesta ORS malformada', () => {
  assertEquals(parseORS({features:[]}), null);
  assertEquals(parseORS({features:[{geometry:{coordinates:[[-77,0]]},properties:{summary:{distance:0,duration:0}}}]}), null);
});
