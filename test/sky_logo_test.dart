import 'package:cercly/sky/sky_logo.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el isotipo sigue el ambiente del tema', (tester) async {
    final environment = ValueNotifier(SkyEnvironment.amanecer);
    await tester.pumpWidget(
      ValueListenableBuilder<SkyEnvironment>(
        valueListenable: environment,
        builder: (_, value, _) => MaterialApp(
          theme: skyTheme(SkyPalette.forEnvironment(value)),
          themeAnimationDuration: Duration.zero,
          home: const Scaffold(body: SkyHorizontalLogo()),
        ),
      ),
    );
    for (final value in SkyEnvironment.values) {
      environment.value = value;
      await tester.pump();
      expect(find.byKey(Key('sky-mark-${value.name}')), findsOneWidget);
      expect(find.text('Cercly'), findsOneWidget);
      expect(
        SkyMark.assetFor(value),
        'assets/branding/sky/variants/isotipo-${value.name}.svg',
      );
    }
    environment.dispose();
  });

  testWidgets('el isotipo conserva tamaño y punto a 24, 48 y 96 px', (
    tester,
  ) async {
    for (final size in [24.0, 48.0, 96.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.dia)),
          home: Scaffold(body: SkyMark(size: size)),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(SvgPicture)), Size(size, size));
      expect(tester.takeException(), isNull);
    }
  });
}
