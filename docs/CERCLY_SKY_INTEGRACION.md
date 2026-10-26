# Cercly Sky — integración aprobada para evaluación local

## Recursos y comportamiento

El SVG maestro `assets/branding/sky/isotipo-master.svg` sigue siendo la única geometría editable. `tool/generate_cercly_sky_brand.py` genera las cuatro variantes en `assets/branding/sky/variants/` y las vistas de diseño. `SkyMark` selecciona el SVG de Amanecer, Día, Atardecer o Noche desde `SkyPalette`; `SkyWordmark` utiliza Comfortaa Bold, incluida con licencia OFL 1.1. El ambiente automático, la selección manual y la persistencia no cambiaron.

Se reemplazó el símbolo provisional en bienvenida, login, selección y formulario de registro, cabecera de Explorar, Mi cuenta y pantalla de carga de autenticación. El lema aprobado «Descubre lugares cerca de ti» aparece en bienvenida y login. Los iconos que representan acciones, ubicación o perfil siguen siendo iconos funcionales, no logotipos. La cabecera de Explorar conserva por ahora el subtítulo anterior «Tu mundo más cerca» para no alterar su texto funcional en este bloque.

`tool/install_cercly_sky_android.py` genera PNG Android a partir de los SVG aprobados. El lanzador usa Día de forma estable en mipmap mdpi–xxxhdpi. El icono adaptativo utiliza frente y fondo Día, más silueta monocromática. Las otras tres variantes quedan como drawables independientes sin selección automática. El splash usa la misma marca Día sobre fondo claro. La geometría del frente adaptativo se verificó dentro del círculo seguro. El recurso vectorial anterior dejó de estar referenciado.

La lámina de diseño muestra las cuatro variantes a 24, 48 y 96 px. El punto central sigue presente al reducir el frente adaptativo: su píxel central conserva alfa 214/255 a 24 px y 255/255 a 48 y 96 px en las cuatro paletas. La validación final de legibilidad requiere el lanzador real.

## Capturas y límites

`tool/sky_visual_capture_test.dart` produjo 28 capturas de widgets Flutter, con datos sintéticos, a 390 × 844 píxeles y escala de render 2. `tool/montage_sky_captures.py` generó siete láminas comparativas en `design/cercly-sky/capturas/`: bienvenida, login, registro, Mi cuenta, cabecera de Explorar, Explorar completo y mapa sin ubicación. Se cargaron Roboto, Material Icons y Comfortaa para mostrar texto e iconos reales. Las capturas son de widgets, no de un teléfono ni del emulador. El mapa aparece en su estado sin GPS; no representa una prueba de calles, marcadores ni proveedores de mapas.

La referencia de pantallas incluye paisajes y fotografías. Esta integración mantiene gradientes estáticos y no incorpora imágenes de Tulcán ni escenas ficticias. La bienvenida conserva su tarjeta de acceso existente. El refinamiento posterior sustituyó la superficie clara de Noche por superficies azul profundo e índigo, amplió el campo estrellado detrás del contenido y eliminó el truncamiento del título «Descubre cerca de ti». Las estrellas permanecen limitadas a Noche y pueden desactivarse.

## Validación

- `flutter pub get`: correcto.
- `flutter analyze`: sin incidencias.
- `flutter test`: 162 pruebas aprobadas, 9 omitidas por falta de Supabase de integración.
- Capturas Flutter: 20 casos aprobados, uno por pantalla y ambiente.
- APK release de evaluación: compilado con URL HTTPS remota y clave publicable, Google OAuth habilitado y eliminación de cuentas deshabilitada. `apksigner verify` correcto. Flutter assets del APK contienen los cuatro SVG y Comfortaa. Android resources contienen el frente, fondo y monocromo Día.
- Emulador Pixel_7 disponible en configuración local, pero su proceso terminó con código 139 durante el arranque tanto dentro como fuera del sandbox. No se pudo instalar ni iniciar el APK allí. Tampoco se probó en HONOR X8b en esta fase.

APK: `releases/Cercly-Sky-logo-oficial-evaluacion-2026-10-26.apk` (61.317.298 bytes), SHA-256 `699c271bf1d21dfbf038bfe4448980c4aac1c3e9335b57c8e9bed6d4206a3fe0`. Los APK previos siguen intactos y `releases/` está excluido de Git.

Google OAuth y la navegación conservaron su lógica. Las pruebas automatizadas cubren la interfaz y la gestión del retorno OAuth con dobles; el recorrido OAuth real sigue pendiente de prueba en un dispositivo o emulador operativo. No se modificó Supabase ni se desplegó nada. Producción continúa en **NO-GO**.

## Refinamiento visual global — 26 de octubre de 2026

Los componentes de Explorar, filtros, mapa superpuesto, detalle de establecimiento, autenticación, Mi cuenta, Configuración, Apariencia, solicitudes, promociones y paneles de propietario y administración adoptan tokens de `SkyPalette` y controles de `ThemeData`. Noche usa superficies oscuras y contraste claro. `SkySurface` distribuye estrellas estáticas y deterministas por el fondo, detrás de contenido y controles; el mapa conserva sus teselas originales y no recibe estrellas. El título principal de Explorar se muestra completo y puede ocupar dos líneas en 320 px con escala de texto 1,5.

Validación local: `flutter pub get`, `flutter analyze`, `flutter test` (164 correctas, 9 omitidas por falta de Supabase de integración), 28 capturas Flutter y `git diff --check` correctos. El emulador Pixel 7 configurado volvió a terminar con código 139 durante el arranque; no se pudo instalar ni abrir este APK. La comprobación en HONOR X8b y el recorrido OAuth real quedan pendientes.

APK nuevo: `releases/Cercly-Sky-global-evaluacion-2026-10-26.apk` (61.464.594 bytes), SHA-256 `e80ee2e62b16758472c74f4276262ab38220838a8fc6a74c56c9922c4110e418`. Se compiló con URL remota HTTPS y clave publicable, Google habilitado y eliminación de cuentas deshabilitada. Firma verificada con `apksigner`. Los APK previos se conservaron; producción sigue en **NO-GO**.

## Fase 3 — ambientes vivos

`SkyAmbientGeometry` conserva posiciones y fases deterministas. `SkyAmbientPainter` dibuja el mismo sol en Amanecer y Atardecer, nubes vectoriales en Día y estrellas de puntos y cuatro puntas en Noche. `SkySurface` aporta un reloj compartido de 8 Hz a fondo y cabecera; solo se repinta `CustomPaint` dentro de `RepaintBoundary`. El reloj se detiene cuando la pantalla queda oculta por `TickerMode`, al pasar a segundo plano, con movimiento reducido o con Efectos ambientales desactivados. La preferencia anterior de estrellas sigue funcionando. Con movimiento reducido se conserva la composición estática. Los elementos no reciben gestos ni semántica; el mapa no lleva decoraciones.

Las capturas de ejecución de widgets Flutter están en `design/cercly-sky/capturas/`. `comparativa-explorar.png`, `comparativa-bienvenida.png`, `comparativa-login.png`, `comparativa-mi-cuenta.png` y `comparativa-mapa-sin-ubicacion.png` muestran los cuatro ambientes con datos sintéticos o sin GPS. `animacion/comparativa-inicial.png` y `animacion/secuencia-cercly-sky.gif` reúnen fotogramas renderizados a 0, 2, 4 y 6 segundos; los cuatro ambientes cambiaron píxeles entre el primer y último fotograma. `comparativa-noche-antes-despues.png` compara el pintor actual con una **reconstrucción Flutter de los puntos estáticos anteriores**, no con una captura conservada de la aplicación previa. No se probaron el mapa real, el GPS ni el OAuth en estas capturas.

Validación: `flutter pub get`, `flutter analyze` sin incidencias, `flutter test` con 170 pruebas aprobadas y 9 omitidas por ausencia de Supabase de integración, pruebas de capturas y `git diff --check` correctos. APK: `releases/Cercly-Sky-ambientes-vivos-evaluacion-2026-10-26.apk` (61.497.362 bytes), SHA-256 `b0b25c81a05ca20dbcff3557fcb48bc05eee59ae9fb86ce7f5ffc40a7e784b02`. Compilado con URL remota HTTPS, clave publicable, OAuth Google habilitado y eliminación deshabilitada; firma verificada. No había dispositivo ADB conectado, así que faltan instalación, rendimiento, accesibilidad y recorrido real en HONOR X8b. Los APK previos y respaldos se conservaron; producción sigue en **NO-GO**.
