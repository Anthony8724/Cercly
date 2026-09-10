# Cercly

Aplicación móvil para descubrir establecimientos y promociones cercanas mediante geolocalización.

## Objetivo

Facilitar que los usuarios encuentren restaurantes, cafeterías, tiendas, minimarkets y otros comercios cercanos, junto con sus promociones activas.

## Funciones del MVP

- Obtener la ubicación del usuario mediante GPS.
- Mostrar establecimientos cercanos en un mapa.
- Ordenar establecimientos según la distancia.
- Filtrar establecimientos por categorías.
- Mostrar información y promociones de cada establecimiento.
- Emitir notificaciones y vibración cuando exista una promoción cercana.
- Abrir Google Maps o una aplicación compatible mediante la opción **Cómo llegar**.
- Mantener información básica en caché local cuando sea posible.

## Tecnologías previstas

- Flutter y Dart
- Cloud Firestore
- Firebase Storage
- Google Maps o una alternativa compatible
- `geolocator`
- `permission_handler`
- `flutter_local_notifications`
- Figma
- Git y GitHub

## Equipo

| Integrante | Responsabilidad principal |
|---|---|
| Anthony López | Líder del proyecto, programación e integración |
| Jessica Cuasquén | Diseño, datos y pruebas |
| Carlos Pantoja | Programación e integración |
| Harol Chapi | Documentación, datos y calidad |

## Organización del repositorio

- `main`: versión estable del proyecto.
- `develop`: integración del trabajo del equipo.
- `feature/nombre-corto`: desarrollo de una función específica.
- `docs/`: documentación técnica y académica.
- `test/`: pruebas del proyecto cuando se inicialice Flutter.

## Flujo de trabajo

1. Crear una rama desde `develop`.
2. Realizar cambios pequeños y claros.
3. Subir los cambios a GitHub.
4. Abrir un Pull Request hacia `develop`.
5. Revisar y aprobar antes de fusionar.
6. Integrar `develop` en `main` únicamente cuando la versión sea estable.

## Alcance inicial

El MVP será desarrollado y probado en Tulcán, Carchi, Ecuador, durante cinco semanas. Su arquitectura deberá permitir una futura expansión a otras ciudades.
