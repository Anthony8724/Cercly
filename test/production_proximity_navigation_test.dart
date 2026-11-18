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
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/horarios_establecimiento');
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  const channel = MethodChannel(ProductionGeofencingService.channelName);
  const id = '12345678-abcd-abcd-abcd-123456789abc';
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
  for (final coldStart in [true, false]) {
    testWidgets(
      'native business opens public detail ${coldStart ? 'cold' : 'warm'}',
      (tester) async {
        final requested = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'consumePendingNotification' => coldStart ? id : null,
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
              const MethodCall('notificationOpened', id),
            ),
            (_) {},
          );
        }
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(requested, [id]);
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
