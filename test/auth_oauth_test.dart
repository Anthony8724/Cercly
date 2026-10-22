import 'dart:async';

import 'package:cercly/features/auth/screens/login_screen.dart';
import 'package:cercly/features/auth/screens/auth_recovery_host.dart';
import 'package:cercly/features/auth/services/auth_service.dart';
import 'package:cercly/features/auth/services/auth_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeOAuth extends AuthService {
  FakeOAuth() : super(options: const AuthOptions(google: true));
  final controller = StreamController<AuthState>.broadcast();
  Completer<bool> launch = Completer<bool>();
  int calls = 0;
  @override
  Stream<AuthState> get events => controller.stream;
  @override
  Future<bool> signInWithProvider(MetodoAcceso metodo) {
    calls++;
    return launch.future;
  }
}

void main() {
  testWidgets('OAuth bloquea doble pulsación y recupera después de error', (
    tester,
  ) async {
    final service = FakeOAuth();
    addTearDown(service.controller.close);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(service: service)));
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(service.calls, 1);
    service.launch.completeError(
      const AuthException('privado', code: 'browser_unavailable'),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudo abrir el navegador'),
      findsOneWidget,
    );
    expect(find.text('privado'), findsNothing);
    service.launch = Completer<bool>();
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    service.launch.complete(true);
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.textContaining('Continúa en el navegador'), findsOneWidget);
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(service.calls, 2); // Navegador abierto también bloquea duplicados.
    await tester.ensureVisible(find.text('Cancelar intento'));
    await tester.tap(find.text('Cancelar intento'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Acceso cancelado'), findsOneWidget);
  });
  testWidgets('OAuth espera sesión válida y vuelve a la raíz', (tester) async {
    final service = FakeOAuth();
    addTearDown(service.controller.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LoginScreen(service: service),
              ),
            ),
            child: const Text('raíz'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('raíz'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    service.launch.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    final user = User(
      id: 'a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );
    service.controller.add(
      AuthState(
        AuthChangeEvent.signedIn,
        Session(accessToken: 'fake', tokenType: 'bearer', user: user),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('raíz'), findsOneWidget);
  });
  testWidgets('OAuth sin callback expira sin reintentar solo', (tester) async {
    final service = FakeOAuth();
    addTearDown(service.controller.close);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(service: service)));
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    service.launch.complete(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('El acceso no se completó'), findsOneWidget);
    expect(service.calls, 1);
    expect(find.text('Cancelar intento'), findsNothing);
  });
  testWidgets('denegación OAuth permite reintento sin detalles privados', (
    tester,
  ) async {
    final service = FakeOAuth();
    addTearDown(service.controller.close);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(service: service)));
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    service.launch.complete(true);
    await tester.pumpAndSettle();
    service.controller.addError(
      const AuthException('token privado', code: 'access_denied'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancelaste el acceso'), findsOneWidget);
    expect(find.textContaining('token privado'), findsNothing);
    expect(find.text('Cancelar intento'), findsNothing);
  });
  testWidgets('sesión vencida avisa y logout voluntario limpia aviso', (
    tester,
  ) async {
    final events = StreamController<AuthState>();
    addTearDown(events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthRecoveryHost(
          events: events.stream,
          child: const Text('público'),
        ),
      ),
    );
    events.add(
      const AuthState(
        AuthChangeEvent.signedOut,
        null,
        signOutReason: SignOutReason.sessionExpired,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu sesión venció'), findsOneWidget);
    events.add(
      const AuthState(
        AuthChangeEvent.signedOut,
        null,
        signOutReason: SignOutReason.userInitiated,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu sesión venció'), findsNothing);
  });
  testWidgets('callback de recuperación abre formulario y no panel', (
    tester,
  ) async {
    final events = StreamController<AuthState>();
    addTearDown(events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthRecoveryHost(
          events: events.stream,
          child: const Text('panel'),
        ),
      ),
    );
    final user = User(
      id: 'a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );
    events.add(
      AuthState(
        AuthChangeEvent.passwordRecovery,
        Session(accessToken: 'fake', tokenType: 'bearer', user: user),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardar contraseña'), findsOneWidget);
    expect(find.text('panel'), findsNothing);
  });
}
