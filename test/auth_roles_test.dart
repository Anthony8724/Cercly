import 'dart:async';

import 'package:cercly/features/auth/screens/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {'tipo_cuenta': 'administrador'},
  aud: 'authenticated',
  createdAt: '2026-01-01',
);
void main() {
  for (final role in [
    'usuario',
    'propietario',
    'administrador',
    'desconocido',
  ]) {
    testWidgets('rol autorizado $role ignora metadatos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: Stream.value(user('a')),
            cargarRol: (_) async => role,
            construirNavegacion: (_, destino) => Text(destino.name),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          role == 'administrador'
              ? 'administrador'
              : role == 'propietario'
              ? 'negocio'
              : 'cuenta',
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('fallo de rol bloquea panel y permite reintentar', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream.value(user('a')),
          cargarRol: (_) async {
            if (attempts++ == 0) throw Exception('privado');
            return 'usuario';
          },
          construirNavegacion: (_, destino) => Text(destino.name),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('privado'), findsNothing);
    expect(find.text('cuenta'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('cuenta'), findsOneWidget);
  });
  testWidgets('cambio de identidad recarga rol', (tester) async {
    final sessions = StreamController<User?>();
    addTearDown(sessions.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: sessions.stream,
          cargarRol: (id) async => id == 'a' ? 'administrador' : 'usuario',
          construirNavegacion: (_, destino) => Text(destino.name),
        ),
      ),
    );
    sessions.add(user('a'));
    await tester.pumpAndSettle();
    expect(find.text('administrador'), findsOneWidget);
    sessions.add(user('b'));
    await tester.pumpAndSettle();
    expect(find.text('cuenta'), findsOneWidget);
  });
}
