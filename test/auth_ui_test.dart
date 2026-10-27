import 'package:cercly/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('acceso adaptable $size y disponibilidad explícita', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      expect(find.text('Cercly'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
      for (final name in ['Google', 'Microsoft', 'Facebook', 'Celular']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Próximamente'), findsNWidgets(3));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google'),
            )
            .onPressed,
        isNotNull,
      );
      for (final name in ['Microsoft', 'Facebook', 'Celular']) {
        expect(
          tester
              .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, name))
              .onPressed,
          isNull,
        );
      }
    });
  }

  testWidgets('login compacto restaura la cabecera al cerrar el teclado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 26, bottom: 16);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final controller = scroll.controller!;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(0, 0.5));
    expect(
      tester.getTopLeft(find.text('¡Hola de nuevo!')).dy,
      greaterThan(tester.getBottomLeft(find.byType(AppBar)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
