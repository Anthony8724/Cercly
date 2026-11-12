// Reproducción LOCAL: servicios y pantallas reales, servidor HTTP sintético.
// No valida Auth/RLS de STAGING y no acepta una URL remota.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cercly/features/auth/services/auth_service.dart';
import 'package:cercly/features/establecimientos/screens/editar_informacion_establecimiento_screen.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_service.dart';
import 'package:cercly/features/solicitudes_establecimientos/screens/solicitudes_administrador_screen.dart';
import 'package:cercly/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile_service_test.dart' show sessionJson;
import 'qa_http_client.dart';

void main() {
  const live = bool.fromEnvironment('CERCLY_REPRO_LIVE');
  if (live) {
    LiveTestWidgetsFlutterBinding.ensureInitialized();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
  late HttpServer server;
  late StreamSubscription<HttpRequest> subscription;
  late QaHttpClient transport;
  final rows = <Map<String, dynamic>>[];
  var name = 'Nombre inicial';
  var stage = 'setup';
  var denyNextCreation = false;
  final paths = <String>[];
  Map<String, Object?> business() => {
    'id': 'e',
    'propietario_id': 'u',
    'nombre': name,
    'descripcion': '',
    'direccion': 'Dirección sintética',
    'categoria_id': 'cat',
    'latitud': 0.8,
    'longitud': -77.7,
    'estado': 'aprobado',
    'publicable': true,
  };
  Map<String, dynamic> detail(Map<String, dynamic> row) => {
    ...row,
    'solicitante': {'nombre': 'QA local'},
    'establecimiento': {'nombre': name, 'direccion': 'Dirección sintética'},
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    subscription = server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final path = request.uri.path;
      paths.add('${request.method} $path');
      Object? value;
      final single =
          request.headers.value('accept')?.contains('vnd.pgrst.object') == true;
      if (path == '/auth/v1/token') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        value = {
          ...sessionJson(id: body['email'] == 'admin@local.test' ? 'a' : 'u'),
          'expires_in': 3600,
        };
      } else if (path == '/auth/v1/logout') {
        request.response.statusCode = 204;
      } else if (path == '/rest/v1/categorias') {
        value = [
          {'id': 'cat', 'nombre': 'Local', 'activa': true},
        ];
      } else if (path == '/rest/v1/miembros_establecimiento') {
        value = [];
      } else if (path == '/rest/v1/establecimientos') {
        value = single ? business() : [business()];
      } else if (path == '/rest/v1/solicitudes_establecimientos') {
        if (request.method == 'POST') {
          final row = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          if (denyNextCreation) {
            denyNextCreation = false;
            request.response.statusCode = 403;
            value = {'code': '42501', 'message': 'Permiso QA local revocado'};
          } else {
            row.addAll({
              'id': 's${rows.length}',
              'estado': 'pendiente',
              'creado_en': '2026-11-08T00:00:00Z',
            });
            rows.add(row);
            request.response.statusCode = 201;
            value = {'id': row['id']};
          }
        } else {
          final id = request.uri.queryParameters['id']?.replaceFirst('eq.', '');
          value = single
              ? detail(rows.singleWhere((row) => row['id'] == id))
              : [
                  ...rows.reversed.map(detail),
                  if (!request.uri.queryParameters.containsKey(
                    'solicitante_id',
                  ))
                    ...List.generate(
                      40,
                      (i) => {
                        ...detail(rows.first),
                        'id': 'closed-$i',
                        'estado': 'rechazada',
                        'mensaje': List.filled(500, 'x').join(),
                        'aplicacion': null,
                      },
                    ),
                ];
        }
      } else if (path == '/rest/v1/rpc/aplicar_correccion_establecimiento') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final row = rows.singleWhere((r) => r['id'] == body['p_solicitud_id']);
        final old = name;
        name =
            ((row['datos_propuestos'] as Map)['cambios']
                    as Map)['nombre']['nuevo']
                as String;
        row['estado'] = 'aprobada';
        row['aplicacion'] = {
          'solicitud_id': row['id'],
          'antes': {'nombre': old},
          'despues': {'nombre': name},
        };
        request.response.statusCode = 204;
      } else {
        throw StateError('Unexpected LOCAL route: $path');
      }
      if (request.response.statusCode != 204) {
        request.response.headers.contentType = ContentType.json;
        final body = jsonEncode(value);
        final middle = body.length ~/ 2;
        request.response.write(body.substring(0, middle));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        request.response.write(body.substring(middle));
      }
      await request.response.close();
    });
  });
  tearDownAll(() async {
    await server.close(force: true);
    await subscription.cancel();
  });
  testWidgets('HTTP local completa dos envíos con cambio de cuenta y reloj real', (
    tester,
  ) async {
    transport = QaHttpClient(record: (_) {});
    Future<T> network<T>(String label, Future<T> Function() action) async {
      stage = label;
      debugPrint('LOCAL_STAGE_START $label');
      final value = live
          ? await action().timeout(const Duration(seconds: 6))
          : await tester.runAsync(
              () => action().timeout(const Duration(seconds: 6)),
            );
      debugPrint('LOCAL_STAGE_END $label');
      return value as T;
    }

    Future<void> waitFor(String label, Finder finder) async {
      stage = label;
      debugPrint('LOCAL_STAGE_START $label');
      for (var i = 0; i < 150; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (finder.evaluate().isNotEmpty) {
          debugPrint('LOCAL_STAGE_END $label');
          return;
        }
      }
      debugPrint(
        'LOCAL_VISIBLE_MESSAGES ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).where((text) => text != null && (text.contains('confirm') || text.contains('No se') || text.contains('aplicad'))).join(' | ')}',
      );
      debugPrint(
        'LOCAL_ROW_STATES ${rows.map((r) => '${r['id']}:${r['estado']}:${r['aplicacion'] != null}').join(',')}',
      );
      throw StateError('LOCAL_UI_STATE_MISSING $label');
    }

    await network(
      'initialize',
      () => Supabase.initialize(
        url: 'http://127.0.0.1:${server.port}',
        publishableKey: 'local-synthetic',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          localStorage: EmptyLocalStorage(),
          detectSessionInUri: false,
        ),
        httpClient: transport,
      ),
    );
    final client = Supabase.instance.client;
    final service = SolicitudEstablecimientoService();
    Future<void> login(String role) async {
      if (client.auth.currentSession != null) {
        await network(
          'logout-$role',
          () => client.auth.signOut(scope: SignOutScope.global),
        );
      }
      await network(
        'login-$role',
        () => AuthService().signIn(
          email: '$role@local.test',
          password: 'synthetic-only',
        ),
      );
    }

    Future<void> submit(int index) async {
      final model = await network(
        'business-$index',
        () => EstablecimientoService().obtenerPorId('e'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditarInformacionEstablecimientoScreen(
                      establecimiento: model!,
                    ),
                  ),
                ),
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Editar'));
      await waitFor(
        'form-$index',
        find.byKey(const ValueKey('seleccionar-nombre')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('seleccionar-nombre')),
      );
      await tester.tap(find.byKey(const ValueKey('seleccionar-nombre')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('nuevo-nombre')),
        'Nombre propuesto $index',
      );
      await tester.ensureVisible(find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await waitFor(
        'snackbar-$index',
        find.text('Solicitud enviada correctamente.'),
      );
      await network('list-$index', service.listarDelUsuarioActual);
    }

    try {
      await login('owner');
      await submit(1);
      await login('admin');
      await tester.pumpWidget(
        const MaterialApp(home: SolicitudesAdministradorScreen()),
      );
      await waitFor('admin-screen', find.text('Aprobar y aplicar'));
      await tester.tap(find.text('Aprobar y aplicar').first);
      await waitFor('admin-dialog', find.byType(AlertDialog));
      await tester.enterText(find.byType(TextFormField).last, 'Revisión local');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Aprobar y aplicar'),
        ),
      );
      await waitFor(
        'applied-snackbar',
        find.text('Corrección aplicada y registrada.'),
      );
      await login('owner');
      await submit(2);
      expect(rows.length, 2);
      expect(rows.last['estado'], 'pendiente');
    } finally {
      debugPrint('LOCAL_LAST_STAGE $stage; LOCAL_HTTP ${paths.join(', ')}');
      transport.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await network('dispose', () => Supabase.instance.dispose());
    }
  }, timeout: const Timeout(Duration(seconds: 35)));
  testWidgets(
    'Flutter conserva la propuesta al recibir 403 real por HTTP local',
    (tester) async {
      final before = rows.length;
      final events = <Map<String, Object>>[];
      transport = QaHttpClient(record: events.add);
      Future<T> network<T>(Future<T> Function() action) async {
        return (await tester.runAsync(
          () => action().timeout(const Duration(seconds: 6)),
        )) as T;
      }

      Future<void> waitFor(Finder finder) async {
        final watch = Stopwatch()..start();
        while (watch.elapsed < const Duration(seconds: 10)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (finder.evaluate().isNotEmpty) return;
        }
        throw StateError('LOCAL_ERROR_UI_DID_NOT_SETTLE');
      }

      await network(
        () => Supabase.initialize(
          url: 'http://127.0.0.1:${server.port}',
          publishableKey: 'local-synthetic',
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            localStorage: EmptyLocalStorage(),
            detectSessionInUri: false,
          ),
          httpClient: transport,
        ),
      );
      try {
        await network(
          () => AuthService().signIn(
            email: 'owner@local.test',
            password: 'synthetic-only',
          ),
        );
        final model = await network(
          () => EstablecimientoService().obtenerPorId('e'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditarInformacionEstablecimientoScreen(
                        establecimiento: model!,
                      ),
                    ),
                  ),
                  child: const Text('Corregir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Corregir'));
        await waitFor(find.byKey(const ValueKey('seleccionar-nombre')));
        await tester.ensureVisible(
          find.byKey(const ValueKey('seleccionar-nombre')),
        );
        await tester.tap(find.byKey(const ValueKey('seleccionar-nombre')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('nuevo-nombre')),
          'Propuesta denegada localmente',
        );
        denyNextCreation = true;
        await tester.ensureVisible(find.text('Enviar solicitud'));
        await tester.tap(find.text('Enviar solicitud'));
        await waitFor(
          find.text('Supabase rechazó la solicitud: Permiso QA local revocado'),
        );
        expect(rows.length, before);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('nuevo-nombre')))
              .controller
              ?.text,
          'Propuesta denegada localmente',
        );
        expect(
          events.where(
            (event) =>
                event['method'] == 'POST' &&
                event['path'] == '/rest/v1/solicitudes_establecimientos' &&
                event['event'] == 'body_completed' &&
                event['status'] == 403,
          ),
          hasLength(1),
        );
        expect(transport.activeRequests, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        transport.close();
        await network(() => Supabase.instance.dispose());
      }
    },
    timeout: const Timeout(Duration(seconds: 35)),
  );
}
