# Cercly — rutas reales (preparación local)

**Estado:** código preparado en rama independiente, no desplegado. No publicar el AAB anterior como si incluyera estas rutas.

## Diseño

- La pantalla `RutaEstablecimientoScreen` invoca `SupabaseRutaService` por defecto.
- El cliente invoca la Edge Function `calcular-ruta` con la sesión Supabase del usuario (si no hay sesión, muestra error y ofrece mapa externo).
- `calcular-ruta` verifica la sesión con `auth.getUser()`, valida perfil y coordenadas, y consulta OpenRouteService con `ORS_API_KEY` guardada **solo** en secretos del servidor.
- Respuesta normalizada: `puntos` como `[latitud,longitud]`, `distanciaMetros`, `duracionSegundos`.
- La app muestra rutas reales (no navegación GPS paso a paso) y conserva la alternativa Google Maps.

## Validación previa a cualquier despliegue

1. Correr `flutter analyze` y pruebas Flutter; si existe Deno: `deno test supabase/functions/calcular-ruta/routing_logic_test.ts`.
2. Probar la Edge Function en **Staging**, con `ORS_API_KEY` creada en el proveedor y guardada exclusivamente en **Staging Secrets**. Nunca mostrarla, commitearla ni usar `--dart-define=ORS_API_KEY`.
3. Ejecutar solicitudes válidas, inválidas, sin sesión y con límite de cuota; confirmar errores, latencia y costes.
4. Implementar **límite de peticiones persistente y compartido** (el límite en memoria incluido por ahora es insuficiente en múltiples instancias). Proteger cuota ORS y monitorizar uso antes de exponer a producción.
5. Verificar la base de usuarios: la función requiere una sesión Supabase; cuentas anónimas/sin login solo tendrán mapa externo.
6. Revisar consentimiento y política de privacidad: las coordenadas de origen y destino se transmiten a Supabase y a OpenRouteService para calcular el recorrido. Explicar esto antes de producción.
7. Verificar reglas de servicio y atribuciones de OpenRouteService/OpenStreetMap.
8. Desplegar recién después de aprobación; nunca ejecutar `supabase functions deploy` apuntando a producción sin confirmación.

## Comandos de comprobación (locales, sin despliegue)

```bash
flutter analyze
flutter test --no-pub test/features/explorar/supabase_ruta_service_test.dart \
  test/features/explorar/ruta_establecimiento_screen_test.dart \
  test/features/explorar/detalle_ruta_navegacion_test.dart
command -v deno && deno test supabase/functions/calcular-ruta/routing_logic_test.ts
```

## Estado actual

Ni `SUPABASE_URL` ni la clave pública de tu app son la clave privada `ORS_API_KEY`. El servicio ORS no se encuentra desplegado todavía. **No considerarlo funcional con rutas reales hasta que pase las pruebas de Staging.**

## Corrección de proveedor (noviembre de 2026)

- `api.openrouteservice.org` está deprecado/cerrado; usar `https://api.heigit.org/openrouteservice/v2/directions/{profile}/geojson`.
- Se conservó la pantalla original y el diseño interno de rutas.
- La Edge Function acepta únicamente sesiones Supabase válidas; una cuenta sin sesión recibe la opción de mapa externo.
- Este cambio NO configura `ORS_API_KEY` en Staging ni demuestra una respuesta real del proveedor.
- Antes de habilitar usuarios externos: limitador distribuido/persistente (el Map en memoria actual NO sirve como control global), presupuesto/cuotas, privacidad y pruebas reales del proveedor en Staging.
- La función no tiene permiso para publicar sola: no ejecutar despliegue a Producción.
