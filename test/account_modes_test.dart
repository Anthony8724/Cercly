import 'dart:async';

import 'package:cercly/features/auth/screens/account_mode_selector.dart';
import 'package:cercly/features/auth/screens/auth_gate.dart';
import 'package:cercly/features/auth/services/account_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {'rol': 'administrador'},
  aud: 'authenticated',
  createdAt: '2026-01-01',
);

const _normal = AccountCapabilities(
  role: 'usuario',
  owner: false,
  admin: false,
  superadmin: false,
);
const _super = AccountCapabilities(
  role: 'administrador',
  owner: true,
  admin: true,
  superadmin: true,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('servidor determina capacidades; datos inconsistentes se rechazan', () {
    final parsed = AccountCapabilities.fromServer(const {
      'rol': 'administrador',
      'propietario': false,
      'administrador': true,
      'superadministrador': true,
    });
    expect(parsed.availableModes, [
      AccountMode.usuario,
      AccountMode.administracion,
    ]);
    expect(parsed.allows(AccountMode.propietario), isFalse);
    expect(
      () => AccountCapabilities.fromServer(const {
        'rol': 'usuario',
        'propietario': true,
        'administrador': false,
        'superadministrador': true,
      }),
      throwsFormatException,
    );
    expect(AccountCapabilities.fromRole('administrador').superadmin, isFalse);
  });

  testWidgets('preferencia local no eleva a usuario normal', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cercly_modo_cuenta_normal': 'administracion',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream.value(_user('normal')),
          cargarCapacidades: (_) async => _normal,
          construirNavegacion: (_, destino) => Text(destino.name),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('cuenta'), findsOneWidget);
    expect(find.text('administrador'), findsNothing);
    expect(find.byKey(const Key('selector-modos-cuenta')), findsNothing);
  });

  testWidgets('modo multirrol cambia vista sin cerrar sesión y persiste', (
    tester,
  ) async {
    final sessions = StreamController<User?>();
    addTearDown(sessions.close);
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: sessions.stream,
          cargarCapacidades: (_) async {
            checks++;
            return _super;
          },
          construirNavegacion: (_, destino) => Scaffold(
            body: Column(
              children: [Text(destino.name), const AccountModeSelector()],
            ),
          ),
        ),
      ),
    );
    sessions.add(_user('super'));
    await tester.pumpAndSettle();
    expect(find.text('administrador'), findsOneWidget);
    await tester.tap(find.byKey(const Key('selector-modos-cuenta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Propietario'));
    await tester.pumpAndSettle();
    expect(find.text('negocio'), findsOneWidget);
    expect(checks, greaterThanOrEqualTo(2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cercly_modo_cuenta_super'), 'propietario');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream.value(_user('super')),
          cargarCapacidades: (_) async => _super,
          construirNavegacion: (_, destino) => Text(destino.name),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('negocio'), findsOneWidget);
  });

  testWidgets('revocación se comprueba antes de cambiar modo', (tester) async {
    var current = _super;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream.value(_user('revoked')),
          cargarCapacidades: (_) async => current,
          construirNavegacion: (_, destino) => Scaffold(
            body: Column(
              children: [Text(destino.name), const AccountModeSelector()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('selector-modos-cuenta')));
    await tester.pumpAndSettle();
    current = _normal;
    await tester.tap(find.text('Propietario'));
    await tester.pumpAndSettle();
    expect(find.text('cuenta'), findsOneWidget);
    expect(find.text('negocio'), findsNothing);
    expect(find.byKey(const Key('selector-modos-cuenta')), findsNothing);
  });

  testWidgets('permisos se actualizan al reanudar', (tester) async {
    var current = _super;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream.value(_user('resume')),
          cargarCapacidades: (_) async => current,
          construirNavegacion: (_, destino) => Text(destino.name),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('administrador'), findsOneWidget);
    current = _normal;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('cuenta'), findsOneWidget);
  });
}
