import 'dart:async';

import 'package:cercly/features/auth/screens/account_mode_selector.dart';
import 'package:cercly/features/auth/screens/auth_gate.dart';
import 'package:cercly/features/auth/services/account_capabilities.dart';
import 'package:cercly/features/auth/services/profile_service.dart';
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

  test('clasifica errores de capacidades sin exponer sus mensajes', () {
    expect(
      ProfileService.diagnosticCategory(TimeoutException('private detail')),
      ProfileDiagnosticCategory.timeout,
    );
    expect(
      ProfileService.diagnosticCategory(
        const PostgrestException(message: 'private detail', code: 'PGRST202'),
      ),
      ProfileDiagnosticCategory.rpc,
    );
    expect(
      ProfileService.diagnosticCategory(
        const PostgrestException(message: 'private detail', code: '08006'),
      ),
      ProfileDiagnosticCategory.http,
    );
    expect(
      ProfileService.diagnosticCategory(
        const AuthException('private detail', statusCode: '401'),
      ),
      ProfileDiagnosticCategory.sessionExpired,
    );
    expect(
      ProfileService.diagnosticCategory(AuthSessionMissingException()),
      ProfileDiagnosticCategory.sessionExpired,
    );
    expect(
      ProfileService.diagnosticCategory(
        const AuthException('private detail', statusCode: '503'),
      ),
      ProfileDiagnosticCategory.http,
    );
    expect(
      ProfileService.diagnosticCategory(
        const PostgrestException(message: 'private detail', code: '42501'),
      ),
      ProfileDiagnosticCategory.authorization,
    );
    expect(
      ProfileService.diagnosticCategory(
        const FormatException('private detail'),
      ),
      ProfileDiagnosticCategory.decoding,
    );
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
    expect(
      find.text('No pudimos verificar tus permisos. Inténtalo de nuevo.'),
      findsNothing,
    );
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

  testWidgets(
    'una recarga exitosa al reanudar descarta un error obsoleto de cambio de modo',
    (tester) async {
      final pendingModeCheck = Completer<AccountCapabilities>();
      var checks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStateChanges: Stream.value(_user('race')),
            cargarCapacidades: (_) {
              checks++;
              return checks == 2
                  ? pendingModeCheck.future
                  : Future.value(_super);
            },
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
      await tester.tap(find.text('Propietario'));
      await tester.pump();
      expect(checks, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 3);
      pendingModeCheck.completeError(
        TimeoutException('private transport detail'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('No pudimos verificar tus permisos. Inténtalo de nuevo.'),
        findsNothing,
      );
      expect(find.text('administrador'), findsOneWidget);
    },
  );
}
