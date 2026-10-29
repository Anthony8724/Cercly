import 'dart:async';

import 'package:cercly/features/auth/screens/account_settings_screen.dart';
import 'package:cercly/features/auth/services/account_deletion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDeletionService extends AccountDeletionService {
  FakeDeletionService({this.session = true, this.handler});
  bool session;
  Future<AccountDeletionOutcome> Function()? handler;
  int requests = 0;

  @override
  bool get hasSession => session;

  @override
  Future<AccountDeletionOutcome> requestDeletion() {
    requests++;
    return handler?.call() ?? Future.value(AccountDeletionOutcome.deleted);
  }

  @override
  Future<void> signOutForReauthentication() async => session = false;
}

Future<void> openDeletion(
  WidgetTester tester,
  FakeDeletionService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: ConfiguracionCuentaScreen(deletionService: service)),
  );
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('abrir-eliminar-cuenta')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Configuración abre política, contacto y eliminación web', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionCuentaScreen(
          abrirEnlace: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('abrir-politica-privacidad')),
      100,
    );
    expect(find.byKey(const Key('abrir-politica-privacidad')), findsOneWidget);
    expect(find.text('Política de privacidad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('abrir-contacto-cercly')),
      100,
    );
    expect(find.byKey(const Key('abrir-contacto-cercly')), findsOneWidget);

    await tester.tap(find.byKey(const Key('abrir-contacto-cercly')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('abrir-eliminacion-web')),
      100,
    );
    await tester.tap(find.byKey(const Key('abrir-eliminacion-web')));
    await tester.pump();

    expect(opened[0].toString(), endsWith('/privacidad#responsable'));
    expect(opened[1].toString(), endsWith('/eliminar-cuenta'));
  });

  testWidgets('registro desde Configuración funciona a 320 px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ConfiguracionCuentaScreen(
          registroScreenBuilder: (_) =>
              const Scaffold(body: Text('Formulario de registro')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('registrar-mi-negocio-configuracion')),
      100,
    );
    await tester.tap(
      find.byKey(const Key('registrar-mi-negocio-configuracion')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Formulario de registro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Perfil → Configuración → Cuenta muestra consecuencias', (
    tester,
  ) async {
    final service = FakeDeletionService();
    await openDeletion(tester, service);
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    expect(find.textContaining('identidad de Supabase Auth'), findsOneWidget);
    expect(find.textContaining('negocios compartidos'), findsOneWidget);
    expect(service.requests, 0);
  });

  testWidgets('sin sesión no abre confirmación ni envía solicitud', (
    tester,
  ) async {
    final service = FakeDeletionService(session: false);
    await openDeletion(tester, service);
    await tester.tap(find.byKey(const Key('solicitar-eliminacion')));
    await tester.pump();
    expect(find.textContaining('No hay una sesión válida'), findsOneWidget);
    expect(find.byKey(const Key('confirmar-eliminacion')), findsNothing);
    expect(service.requests, 0);
  });

  testWidgets('cancelar confirmación no solicita eliminación', (tester) async {
    final service = FakeDeletionService();
    await openDeletion(tester, service);
    await tester.tap(find.byKey(const Key('solicitar-eliminacion')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Esta acción no se puede deshacer'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cancelar-eliminacion')));
    await tester.pumpAndSettle();
    expect(service.requests, 0);
  });

  testWidgets('confirmación muestra carga e impide segunda solicitud', (
    tester,
  ) async {
    final pending = Completer<AccountDeletionOutcome>();
    final service = FakeDeletionService(handler: () => pending.future);
    await openDeletion(tester, service);
    await tester.tap(find.byKey(const Key('solicitar-eliminacion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-eliminacion')));
    await tester.pump();
    expect(find.byKey(const Key('eliminacion-cargando')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('solicitar-eliminacion')))
          .onPressed,
      isNull,
    );
    expect(service.requests, 1);
    pending.complete(AccountDeletionOutcome.deleted);
    await tester.pumpAndSettle();
    expect(find.textContaining('cerramos la sesión'), findsOneWidget);
    expect(find.byKey(const Key('solicitar-eliminacion')), findsNothing);
  });

  testWidgets('propietario recibe revisión sin afirmar borrado', (
    tester,
  ) async {
    final service = FakeDeletionService(
      handler: () async => AccountDeletionOutcome.review,
    );
    await openDeletion(tester, service);
    await tester.tap(find.byKey(const Key('solicitar-eliminacion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-eliminacion')));
    await tester.pumpAndSettle();
    expect(find.textContaining('aún no está eliminada'), findsOneWidget);
  });

  testWidgets('fallo de red y fallo parcial permiten reintento explícito', (
    tester,
  ) async {
    var attempt = 0;
    final service = FakeDeletionService(
      handler: () async {
        attempt++;
        throw AccountDeletionException(
          attempt == 1
              ? AccountDeletionFailure.network
              : AccountDeletionFailure.pending,
        );
      },
    );
    await openDeletion(tester, service);
    for (final expected in [
      'No podemos confirmar el estado',
      'solicitud quedó pendiente',
    ]) {
      await tester.tap(find.byKey(const Key('solicitar-eliminacion')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-eliminacion')));
      await tester.pumpAndSettle();
      expect(find.textContaining(expected), findsOneWidget);
    }
    expect(service.requests, 2);
  });

  testWidgets('sesión antigua solicita nuevo inicio', (tester) async {
    final service = FakeDeletionService(
      handler: () async {
        throw const AccountDeletionException(AccountDeletionFailure.recentAuth);
      },
    );
    await openDeletion(tester, service);
    await tester.tap(find.byKey(const Key('solicitar-eliminacion')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-eliminacion')));
    await tester.pumpAndSettle();
    expect(find.textContaining('vuelve a iniciar sesión'), findsWidgets);
    await tester.tap(find.text('Cerrar sesión para volver a entrar'));
    await tester.pump();
    expect(service.session, isFalse);
  });
}
