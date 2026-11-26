# Bloque A — rutas: decisión técnica para la candidata Play

Base inspeccionada: Android a7f11f2 y web f21b059. Ambos HEAD remotos coinciden al iniciar este bloque. No se fusiona ni despliega.

## Problema y alcance

La candidata anterior remitía GPS y destino a calcular-ruta (Supabase) y luego a api.heigit.org/openrouteservice. La función verifica getUser y cuota, pero consentimiento, HTTPS y retirar UUID/correo no convierten las coordenadas en anónimas ni autorizan una transmisión prohibida. No se acreditan retención del proveedor, excepciones contractuales ni un acuerdo aplicable al proyecto.

La revisión anterior del 19/11 verificó la restricción de datos personales de HeiGIT. La nueva consulta a https://account.heigit.org/info/tos, incluida renderización con Chrome, respondió 503 / no available server: no se presenta como una nueva validación contractual exitosa. Se conserva la decisión de denegar por falta de autorización acreditada. https://heigit.org/privacy-policy/ identifica datos de ubicación dentro de información personal; no demuestra una autorización específica de la API para Cercly.

## Alternativa implementada para Play

Cómo llegar muestra una confirmación para abrir Google Maps. Cancelar no abre enlaces. Confirmar abre una URL HTTPS con api=1 y exclusivamente destination (posición pública del establecimiento). El botón no consulta GPS, no usa el origen previamente obtenido por Explorar, no invoca Supabase y no llama al proveedor bloqueado. Google Maps puede usar su propia ubicación/permisos: no se promete que el servicio externo no recopile datos.

PoliticaRutas está cerrada por código; ninguna variable de compilación o consentimiento la habilita. SupabaseRutaService rechaza antes de acceder a sesión/RPC/red; el adaptador directo ORS rechaza todo endpoint real, incluso con cliente y clave inyectados. Conserva pruebas de protocolo únicamente con transporte inyectado y dominios reservados .test. La pantalla y servicios internos se mantienen reutilizables, sin mostrar rutas simuladas como reales.

Gradle rechaza secretos del servidor en dart-defines para todas las variantes y rutas simuladas en variantes públicas. No se cambian los endpoints ni la Edge Function desplegada. Las versiones antiguas y otras aplicaciones aún podrían llamar al backend existente: este cambio solo asegura el comportamiento de la nueva candidata. No se promete detener el tráfico de clientes previos.

## Opciones para recuperar rutas internas

| Alternativa | Ventaja | Coste/condición sin resolver | Decisión |
|---|---|---|---|
| OSRM propio en infraestructura universitaria autorizada | Software BSD, datos OSM, perfiles configurables; conserva UI y patrón servidor | Se requiere equipo asignado, región/datos, operación, seguridad, actualización, copias y benchmark. No se presupone coste cero ni se aprovisiona | Primera opción a estudiar si hay infraestructura |
| OpenRouteService propio | Reutiliza protocolo actual, sin enviar coordenadas al servicio alojado de HeiGIT | Recursos, licencias/datos, operación y retención bajo responsabilidad propia; medir antes de prometer capacidad | Alternativa de continuidad |
| GraphHopper alojado u otro proveedor con contrato adecuado | API interna gestionada y proveedores con documentación de privacidad | Confirmar DPA, uso de GPS, tratamiento, retención, cuota, licencia, precio y autorización del titular | No contratar ni aceptar condiciones |
| Mapas externos con solo destino | No requiere clave Maps URLs ni servidor de rutas en Cercly; mantiene Cómo llegar | El usuario sale de Cercly y elige/autoriza el servicio externo; no ofrece ruta embebida | Implementada para candidata |
| Servidor demo público OSRM | Útil para demostrar protocolo | Sin garantías ni capacidad reservada; acceso puede retirarse; privacidad/uso deben comprobarse | No usar como sustituto automático en Producción |

No se envían coordenadas de usuarios para investigar servicios. No se activó un plan, una compra o despliegue. Las cuotas/precios requieren comprobación específica; no se inventa presupuesto.

## Reactivación futura

Acreditar contrato y finalidad → definir backend/proveedor y retención → implementar en Staging aislado → probar consentimiento, errores, cuota, ausencia de secretos y borrado → actualizar privacidad/declaraciones → revisión explícita del cambio PoliticaRutas → nueva build/hash/QA → autorización separada de despliegue. No aceptar un simple dart-define como prueba de autorización.

## Fuentes oficiales

- https://account.heigit.org/info/tos (nueva consulta no disponible; ver limitación anterior).
- https://heigit.org/privacy-policy/
- https://project-osrm.org/
- https://github.com/Project-OSRM/osrm-backend/wiki/Api-usage-policy
- https://github.com/GIScience/openrouteservice
- https://docs.graphhopper.com/openapi/routing
- https://developers.google.com/maps/documentation/urls/get-started

## Verificación del bloque

59 pruebas enfocadas de rutas/exploración aprobadas y analyze sin incidencias antes del endurecimiento Gradle. Las pruebas cubren confirmación/cancelación, consentimiento GPS aceptado o denegado, cero consultas de ubicación, cero invocaciones internas, destino sin origen, fallo externo sin fallback y bloqueo de adaptadores reales. Las comprobaciones finales de toda la candidata se registran por separado.
