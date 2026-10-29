import 'dart:io' show SocketException;

import 'package:cercly/features/auth/screens/password_screen.dart';
import 'package:cercly/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakePassword extends AuthService {
  String? email, password;
  bool fail = true;
  Object? updateError;
  @override
  Future<void> resetPassword(String value) async {
    email = value;
    if (fail) throw const SocketException('private');
  }

  @override
  Future<void> updatePassword(String value) async {
    if (updateError != null) throw updateError!;
    password = value;
  }
}

void main() {
  testWidgets('recuperación valida email y permite reintentar', (tester) async {
    final service = FakePassword();
    await tester.pumpWidget(
      MaterialApp(home: PasswordScreen(service: service)),
    );
    await tester.enterText(find.byType(TextFormField), 'incorrecto');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(service.email, isNull);
    await tester.enterText(find.byType(TextFormField), 'persona@example.com');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Comprueba tu conexión'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Si el correo está registrado'), findsOneWidget);
  });
  testWidgets('cambio de contraseña exige confirmación', (tester) async {
    final service = FakePassword();
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordScreen(
          service: service,
          recovery: true,
          onComplete: () => completed = true,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'different');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(service.password, isNull);
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(service.password, 'new-password');
    expect(completed, true);
  });
  testWidgets('enlace vencido muestra guía sin filtrar detalle de Auth', (
    tester,
  ) async {
    final service = FakePassword()
      ..fail = false
      ..updateError = const AuthException(
        'private provider detail',
        code: 'flow_state_expired',
      );
    await tester.pumpWidget(
      MaterialApp(home: PasswordScreen(service: service, recovery: true)),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('El enlace de recuperación venció'),
      findsOneWidget,
    );
    expect(find.textContaining('private provider detail'), findsNothing);
  });
}
