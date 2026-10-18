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
      expect(find.text('Próximamente'), findsNWidgets(4));
    });
  }
}
