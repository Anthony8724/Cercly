import 'package:cercly/sky/sky_controller.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySkyStore implements SkyPreferenceStore {
  String? mode;
  bool? decorations;

  @override
  Future<String?> getMode() async => mode;
  @override
  Future<void> setMode(String value) async => mode = value;
  @override
  Future<bool?> getDecorationsEnabled() async => decorations;
  @override
  Future<void> setDecorationsEnabled(bool value) async => decorations = value;
}

void main() {
  test('las cuatro franjas respetan todos sus límites', () {
    final cases = <(int, int, SkyEnvironment)>[
      (4, 59, SkyEnvironment.noche),
      (5, 0, SkyEnvironment.amanecer),
      (7, 59, SkyEnvironment.amanecer),
      (8, 0, SkyEnvironment.dia),
      (16, 29, SkyEnvironment.dia),
      (16, 30, SkyEnvironment.atardecer),
      (18, 59, SkyEnvironment.atardecer),
      (19, 0, SkyEnvironment.noche),
      (23, 59, SkyEnvironment.noche),
      (0, 0, SkyEnvironment.noche),
    ];
    for (final (hour, minute, expected) in cases) {
      expect(skyEnvironmentAt(DateTime(2026, 10, 25, hour, minute)), expected);
    }
  });

  testWidgets(
    'la hora local nueva y el regreso a primer plano actualizan el ambiente',
    (tester) async {
      var localTime = DateTime(2026, 10, 25, 7, 59);
      final controller = SkyController(
        store: _MemorySkyStore(),
        clock: () => localTime,
      );
      await controller.start();
      expect(controller.environment, SkyEnvironment.amanecer);

      localTime = DateTime(2026, 10, 25, 8);
      controller.refresh();
      expect(controller.environment, SkyEnvironment.dia);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      localTime = DateTime(2026, 10, 25, 19);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.environment, SkyEnvironment.noche);
      controller.dispose();
    },
  );

  testWidgets('zona horaria simulada se detecta durante primer plano', (
    tester,
  ) async {
    // Una nueva zona horaria cambia el resultado de DateTime.now() local.
    var localTime = DateTime(2026, 10, 25, 15);
    final controller = SkyController(
      store: _MemorySkyStore(),
      clock: () => localTime,
    );
    await controller.start();
    expect(controller.environment, SkyEnvironment.dia);
    localTime = DateTime(2026, 10, 25, 20);
    await tester.pump(const Duration(seconds: 31));
    expect(controller.environment, SkyEnvironment.noche);
    controller.dispose();
  });

  testWidgets('selección manual y efectos persisten y no siguen el reloj', (
    tester,
  ) async {
    final store = _MemorySkyStore();
    var localTime = DateTime(2026, 10, 25, 12);
    final first = SkyController(store: store, clock: () => localTime);
    await first.start();
    await first.selectMode(SkyMode.atardecer);
    await first.setDecorationsEnabled(false);
    first.dispose();

    localTime = DateTime(2026, 10, 25, 23);
    final restored = SkyController(store: store, clock: () => localTime);
    await restored.start();
    expect(restored.mode, SkyMode.atardecer);
    expect(restored.environment, SkyEnvironment.atardecer);
    expect(restored.decorationsEnabled, isFalse);
    restored.dispose();
  });

  test('texto y botones mantienen contraste WCAG AA en las cuatro paletas', () {
    double luminance(Color color) => color.computeLuminance();
    double ratio(Color a, Color b) {
      final light = luminance(a) > luminance(b) ? luminance(a) : luminance(b);
      final dark = luminance(a) > luminance(b) ? luminance(b) : luminance(a);
      return (light + .05) / (dark + .05);
    }

    for (final environment in SkyEnvironment.values) {
      final palette = SkyPalette.forEnvironment(environment);
      expect(
        ratio(palette.text, palette.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(ratio(palette.text, palette.surface), greaterThanOrEqualTo(4.5));
      expect(ratio(Colors.white, palette.primary), greaterThanOrEqualTo(4.5));
      expect(ratio(palette.interactive, palette.surface), greaterThanOrEqualTo(4.5));
      for (final color in [
        palette.headerStart,
        palette.headerMiddle,
        palette.headerEnd,
      ]) {
        expect(ratio(Colors.white, color), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('superficies y controles usan los tokens de cada ambiente', () {
    final surfaces = <Color>{};
    for (final environment in SkyEnvironment.values) {
      final palette = SkyPalette.forEnvironment(environment);
      final theme = skyTheme(palette);
      surfaces.add(theme.colorScheme.surface);
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.colorScheme.surface, palette.surface);
      expect(theme.colorScheme.onSurface, palette.text);
      expect(theme.cardTheme.color, palette.surface);
      expect(theme.inputDecorationTheme.fillColor, palette.inputFill);
      expect(theme.navigationBarTheme.backgroundColor, palette.surface);
      expect(
        theme.brightness,
        environment == SkyEnvironment.noche ? Brightness.dark : Brightness.light,
      );
    }
    expect(surfaces, hasLength(4));
  });
}
