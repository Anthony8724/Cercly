import 'package:cercly/features/auth/screens/account_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const deletionEnabled = bool.fromEnvironment(
    'ACCOUNT_DELETION_ENABLED',
    defaultValue: true,
  );

  testWidgets('el APK de evaluación no ofrece la eliminación de cuentas', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CuentaScreen()));

    final option = tester.widget<ListTile>(
      find.byKey(const Key('abrir-eliminar-cuenta')),
    );
    expect(option.onTap, isNull);
    expect(find.textContaining('validación del servicio'), findsOneWidget);
    expect(find.byType(EliminarCuentaScreen), findsNothing);
  }, skip: deletionEnabled);
}
