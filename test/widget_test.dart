import 'package:cercly/features/auth/screens/auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el acceso cuando no existe una sesión', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream<User?>.value(null),
          unauthenticatedBuilder: (_) =>
              const Text('Acceso para establecimientos'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Acceso para establecimientos'), findsOneWidget);
  });
}
