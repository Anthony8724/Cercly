import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/screens/mapa_establecimientos_screen.dart';
import 'package:cercly/sky/sky_ambient_geometry.dart';
import 'package:cercly/sky/sky_ambient_painter.dart';
import 'package:cercly/sky/sky_backdrop.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'explorar_establecimientos_test.dart' as fixtures;

void main() {
  test('soles comparten geometría base en lados opuestos', () {
    const size = Size(390, 844);
    final dawn = SkyAmbientGeometry.sunCenter(size, sunset: false);
    final sunset = SkyAmbientGeometry.sunCenter(size, sunset: true);
    expect(dawn.dx, lessThan(size.width / 2));
    expect(sunset.dx, greaterThan(size.width / 2));
    expect(sunset.dy, greaterThan(dawn.dy));
    expect(SkyAmbientMotionMath.sunGlow(0, sunset: false), 1);
    expect(SkyAmbientMotionMath.sunGlow(0, sunset: true), 1);
  });

  test('estrellas tienen formas, fases y distribución deterministas', () {
    const size = Size(390, 844);
    final a = SkyAmbientGeometry.stars(size);
    final b = SkyAmbientGeometry.stars(size);
    expect(a.length, inInclusiveRange(24, 96));
    expect(
      [for (final star in a) star.position],
      [for (final star in b) star.position],
    );
    expect(
      a.where((star) => star.shape == SkyStarShape.micro).length / a.length,
      inInclusiveRange(.55, .85),
    );
    expect(a.any((star) => star.shape == SkyStarShape.fourPoint), isTrue);
    expect(a.any((star) => star.shape == SkyStarShape.accent), isTrue);
    final animated = a.where((star) => !star.almostStatic).take(2).toList();
    expect(animated, hasLength(2));
    expect(animated.first.phase, isNot(animated.last.phase));
    expect(
      SkyAmbientMotionMath.starOpacity(animated.first, 0),
      isNot(SkyAmbientMotionMath.starOpacity(animated.first, 1)),
    );
    expect(
      SkyAmbientMotionMath.starOpacity(animated.first, 1),
      isNot(SkyAmbientMotionMath.starOpacity(animated.last, 1)),
    );
  });

  test(
    'nubes se desplazan horizontalmente sin saltar mientras son visibles',
    () {
      const size = Size(390, 844);
      final clouds = SkyAmbientGeometry.clouds(size);
      expect(clouds, hasLength(4));
      expect(
        [for (final cloud in clouds) cloud.position],
        [for (final cloud in SkyAmbientGeometry.clouds(size)) cloud.position],
      );
      for (final cloud in clouds) {
        final start = SkyAmbientMotionMath.cloudX(cloud, size, 0);
        final next = SkyAmbientMotionMath.cloudX(cloud, size, 1);
        expect(next, greaterThan(start));
        expect(next - start, closeTo(cloud.speed, .001));
      }
    },
  );

  testWidgets('cada ambiente pinta su capa; cambiar tema conserva controles', (
    tester,
  ) async {
    var taps = 0;
    for (final environment in SkyEnvironment.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: skyTheme(SkyPalette.forEnvironment(environment)),
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: SkySurface(
              child: Center(
                child: FilledButton(
                  onPressed: () => taps++,
                  child: const Text('Continuar'),
                ),
              ),
            ),
          ),
        ),
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<SkyAmbientPainter>()
          .single;
      expect(painter.palette.environment, environment);
      await tester.tap(find.text('Continuar'));
      expect(tester.takeException(), isNull);
    }
    expect(taps, 4);
  });

  testWidgets(
    'reloj pausa con TickerMode, ciclo de vida y movimiento reducido',
    (tester) async {
      var visible = true;
      var reduceMotion = false;
      Future<void> render() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.noche)),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: TickerMode(
                enabled: visible,
                child: const Scaffold(
                  body: SkySurface(child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        );
      }

      SkyAmbientPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<SkyAmbientPainter>()
          .single;

      await render();
      await tester.pump(const Duration(milliseconds: 500));
      final running = painter().motion.value;
      expect(running, greaterThan(0));

      visible = false;
      await render();
      await tester.pump(const Duration(seconds: 1));
      expect(painter().motion.value, running);

      visible = true;
      await render();
      await tester.pump(const Duration(milliseconds: 250));
      final resumed = painter().motion.value;
      expect(resumed, greaterThan(running));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(painter().motion.value, resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 250));
      expect(painter().motion.value, greaterThan(resumed));

      reduceMotion = true;
      await render();
      final still = painter().motion.value;
      await tester.pump(const Duration(seconds: 1));
      expect(painter().motion.value, still);
      expect(find.byType(SkyAmbientLayer), findsOneWidget);
    },
  );

  testWidgets('mapa no contiene capas ambientales', (tester) async {
    final controller = fixtures.crearController(
      resultadoUbicacion: const ResultadoUbicacion(
        estado: EstadoUbicacion.inicial,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.noche)),
        home: Scaffold(
          body: MapaEstablecimientosScreen(
            controller: controller,
            mostrarTiles: false,
          ),
        ),
      ),
    );
    expect(find.byType(SkyAmbientLayer), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
