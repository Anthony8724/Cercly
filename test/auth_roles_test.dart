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
  for (final role in ['usuario', 'propietario', 'administrador']) {
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
  testWidgets('rol desconocido bloquea el acceso y explica revisión', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream.value(user('a')),
          cargarRol: (_) async => 'desconocido',
          construirNavegacion: (_, destino) => Text(destino.name),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('necesita revisión'), findsOneWidget);
    expect(find.text('cuenta'), findsNothing);
  });
  testWidgets(
    'consulta lenta termina y descarta resultado tardío tras cambiar usuario',
    (tester) async {
      final sessions = StreamController<User?>();
      addTearDown(sessions.close);
      final pending = Completer<String>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: sessions.stream,
            cargarRol: (id) {
              calls++;
              return id == 'a' ? pending.future : Future.value('usuario');
            },
            construirNavegacion: (_, destino) => Text(destino.name),
          ),
        ),
      );
      sessions.add(user('a'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Cargando tu perfil…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.textContaining('tardando demasiado'), findsOneWidget);
      expect(calls, 1);
      sessions.add(user('b'));
      await tester.pumpAndSettle();
      pending.complete('administrador');
      await tester.pumpAndSettle();
      expect(find.text('cuenta'), findsOneWidget);
      expect(find.text('administrador'), findsNothing);
    },
  );
  testWidgets(
    'error del stream no muestra panel y siguiente sesión se recupera',
    (tester) async {
      final sessions = StreamController<User?>();
      addTearDown(sessions.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: sessions.stream,
            cargarRol: (_) async => 'usuario',
            construirNavegacion: (_, destino) => Text(destino.name),
          ),
        ),
      );
      sessions.addError(
        const AuthException('secreto', code: 'session_not_found'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu sesión venció'), findsOneWidget);
      expect(find.text('secreto'), findsNothing);
      sessions.add(user('a'));
      await tester.pumpAndSettle();
      expect(find.text('cuenta'), findsOneWidget);
    },
  );
  testWidgets('inicio sin evento no queda cargando indefinidamente', (
    tester,
  ) async {
    final sessions = StreamController<User?>();
    addTearDown(sessions.close);
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authStateChanges: sessions.stream)),
    );
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.textContaining('tardando demasiado'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
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
