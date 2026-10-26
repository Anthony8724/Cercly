import 'package:cercly/sky/apariencia_screen.dart';
import 'package:cercly/sky/sky_backdrop.dart';
import 'package:cercly/sky/sky_ambient_painter.dart';
import 'package:cercly/sky/sky_controller.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements SkyPreferenceStore {
  String? mode;
  bool? effects;

  @override
  Future<String?> getMode() async => mode;
  @override
  Future<bool?> getDecorationsEnabled() async => effects;
  @override
  Future<void> setMode(String value) async => mode = value;
  @override
  Future<void> setDecorationsEnabled(bool value) async => effects = value;
}

void main() {
  testWidgets('Apariencia cambia ambiente y conserva la selección', (
    tester,
  ) async {
    final store = _Store();
    final controller = SkyController(
      store: store,
      clock: () => DateTime(2026, 10, 25, 12),
    );
    await controller.start();
    await tester.pumpWidget(
      MaterialApp(home: AparienciaScreen(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('ambiente-noche')));
    await tester.pump();
    expect(controller.environment, SkyEnvironment.noche);
    expect(store.mode, 'noche');

    await tester.tap(find.byKey(const Key('efectos-decorativos')));
    await tester.pump();
    expect(controller.decorationsEnabled, isFalse);
    expect(store.effects, isFalse);
    controller.dispose();
  });

  testWidgets('los efectos respetan ambiente, movimiento reducido y gestos', (
    tester,
  ) async {
    var taps = 0;
    Future<void> show(
      SkyEnvironment environment,
      bool reduceMotion, {
      bool effects = true,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: skyTheme(
          SkyPalette.forEnvironment(environment)
              .copyWith(decorationsEnabled: effects),
        ),
        themeAnimationDuration: Duration.zero,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
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
      ),
    );

    SkyAmbientPainter? painter() {
      for (final paint in tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      )) {
        if (paint.painter is SkyAmbientPainter) {
          return paint.painter! as SkyAmbientPainter;
        }
      }
      return null;
    }

    await show(SkyEnvironment.dia, false);
    expect(painter()?.palette.environment, SkyEnvironment.dia);
    await show(SkyEnvironment.noche, true);
    final still = painter()!;
    await tester.pump(const Duration(seconds: 1));
    expect(still.motion.value, 0);
    await show(SkyEnvironment.noche, false);
    final moving = painter()!;
    await tester.pump(const Duration(milliseconds: 250));
    expect(moving.motion.value, greaterThan(0));
    await tester.tap(find.text('Continuar'));
    expect(taps, 1);
    await show(SkyEnvironment.noche, false, effects: false);
    expect(painter(), isNull);
  });
}
