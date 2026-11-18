import 'dart:convert';

import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/explorar/screens/detalle_establecimiento_screen.dart';
import 'package:cercly/features/notificaciones/controllers/monitor_proximidad_controller.dart';
import 'package:cercly/features/notificaciones/services/production_geofencing_service.dart';
import 'package:cercly/features/notificaciones/widgets/monitor_proximidad_app.dart';
import 'package:cercly/features/notificaciones/push/fcm_push_service.dart';
import 'package:cercly/features/notificaciones/push/fcm_promotion_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Monitor extends Fake implements MonitorProximidadController {
  @override
  Future<void> iniciar() async {}
  @override
  Future<void> reanudar() async {}
  @override
  void pausar() {}
  @override
  void dispose() {}
}

class _Push extends Fake implements FcmPushService {
  @override
  void observeAuthentication({
    required Future<void> Function(FcmPromotionMessage message) openPromotion,
    required void Function(FcmPromotionMessage message) showForegroundMessage,
  }) {}

  @override
  Future<void> reconcileAfterResume() async {}
}

void main() {
  const id = '12345678-abcd-abcd-abcd-123456789abc';
  const promotionId = '22345678-abcd-abcd-abcd-123456789abc';
  var promotionState = 'valid';
  final promotionRequests = <http.Request>[];
  setUp(() {
    promotionState = 'valid';
    promotionRequests.clear();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
      // Platform callbacks run outside the pump guard; use synchronous assertions.
      httpClient: MockClient((request) async {
        expectSync(request.method, 'GET');
        if (request.url.path == '/rest/v1/promociones') {
          promotionRequests.add(request);
          expectSync(request.url.queryParameters['id'], 'eq.$promotionId');
          expectSync(request.url.queryParameters['activa'], 'eq.true');
          expectSync(
            request.url.queryParameters['establecimientos.estado'],
            'eq.aprobado',
          );
          expectSync(
            request.url.queryParameters['establecimientos.publicable'],
            'eq.true',
          );
          final now = DateTime.now().toUtc();
          return http.Response(
            jsonEncode(
              promotionState == 'missing'
                  ? null
                  : {
                      'id': promotionId,
                      'titulo': 'Promoción pública',
                      'fecha_inicio': now
                          .subtract(const Duration(days: 1))
                          .toIso8601String(),
                      'fecha_fin':
                          (promotionState == 'expired'
                                  ? now.subtract(const Duration(hours: 1))
                                  : now.add(const Duration(days: 1)))
                              .toIso8601String(),
                      'activa': promotionState != 'inactive',
                      'establecimientos': {
                        'id': promotionState == 'mismatched'
                            ? 'otro-negocio'
                            : id,
                        'nombre': 'Negocio público',
                        'latitud': 0,
                        'longitud': 0,
                        'categorias': {'nombre': 'Comercio'},
                      },
                    },
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expectSync(request.url.path, '/rest/v1/horarios_establecimiento');
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  const channel = MethodChannel(ProductionGeofencingService.channelName);
  const establishment = EstablecimientoPublicoModel(
    id: id,
    nombre: 'Negocio público',
    descripcion: '',
    direccion: '',
    latitud: 0,
    longitud: 0,
    telefonoPublico: '',
    zonaHoraria: 'America/Guayaquil',
    categoria: CategoriaPublicaModel(
      id: 'cat',
      nombre: 'Comercio',
      slug: 'comercio',
      icono: 'store',
    ),
    promociones: [],
  );
  for (final structured in [false, true]) {
    for (final coldStart in [true, false]) {
      testWidgets(
        'native ${structured ? 'promotion' : 'business'} opens public detail ${coldStart ? 'cold' : 'warm'}',
        (tester) async {
          final requested = <String>[];
          final Object payload = structured
              ? {'establishmentId': id, 'promotionId': promotionId}
              : id;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async => switch (call.method) {
              'consumePendingNotification' => coldStart ? payload : null,
              'status' => <String, Object>{'consent': false},
              _ => true,
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              home: MonitorProximidadApp(
                controller: _Monitor(),
                pushService: _Push(),
                cargarEstablecimiento: (value) async {
                  requested.add(value);
                  return establishment;
                },
                child: const Scaffold(body: Text('Inicio')),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          if (!coldStart) {
            tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              channel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('notificationOpened', payload),
              ),
              (_) {},
            );
          }
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(
            requested,
            [id],
            reason:
                'promotion requests: ${promotionRequests.length}; texts: ${tester.widgetList<Text>(find.byType(Text)).map((e) => e.data).toList()}',
          );
          expect(promotionRequests.length, structured ? 1 : 0);
          expect(find.byType(DetalleEstablecimientoScreen), findsOneWidget);
          expect(find.text('Negocio público'), findsWidgets);
          await tester.pumpWidget(const SizedBox());
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        },
        skip: !ProductionGeofencingService.enabledBuild,
      );
    }
  }
  for (final scenario in [
    'missing',
    'inactive',
    'expired',
    'mismatched',
    'malformed-map',
    'wrong-type',
    'absent',
  ]) {
    testWidgets('cold notification rejects $scenario', (tester) async {
      promotionState = scenario;
      final requested = <String>[];
      final Object? payload = switch (scenario) {
        'malformed-map' => {'establishmentId': id},
        'wrong-type' => 123,
        'absent' => null,
        _ => {'establishmentId': id, 'promotionId': promotionId},
      };
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'consumePendingNotification' => payload,
          'status' => <String, Object>{'consent': false},
          _ => true,
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MonitorProximidadApp(
            controller: _Monitor(),
            pushService: _Push(),
            cargarEstablecimiento: (value) async {
              requested.add(value);
              return establishment;
            },
            child: const Scaffold(body: Text('Inicio')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requested, isEmpty);
      expect(find.text('No pudimos validar esta promoción.'), findsNothing);
      if (!['malformed-map', 'wrong-type', 'absent'].contains(scenario)) {
        expect(
          find.text('Esta promoción ya no está disponible.'),
          findsOneWidget,
        );
      }
      expect(find.byType(DetalleEstablecimientoScreen), findsNothing);
      expect(
        promotionRequests.length,
        ['malformed-map', 'wrong-type', 'absent'].contains(scenario) ? 0 : 1,
      );
      await tester.pumpWidget(const SizedBox());
    }, skip: !ProductionGeofencingService.enabledBuild);
  }
}
