import 'package:cercly/features/notificaciones/services/notificacion_local_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _canalNotificaciones = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final llamadas = <String>[];
  var permisoActivo = true;
  var solicitudAceptada = false;

  setUp(() {
    llamadas.clear();
    permisoActivo = true;
    solicitudAceptada = false;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalNotificaciones, (call) async {
          llamadas.add(call.method);
          return switch (call.method) {
            'areNotificationsEnabled' => permisoActivo,
            'requestNotificationsPermission' => solicitudAceptada,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalNotificaciones, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('consulta el permiso del sistema sin inicializar el plugin', () async {
    final servicio = NotificacionLocalService();

    expect(
      await servicio.consultarEstadoDetallado(),
      EstadoPermisoNotificaciones.concedido,
    );
    expect(llamadas, ['areNotificationsEnabled']);
  });

  test(
    'no considera concedido un permiso si el estado real sigue apagado',
    () async {
      permisoActivo = false;
      solicitudAceptada = true;
      final servicio = NotificacionLocalService();

      expect(
        await servicio.solicitarPermisoDetallado(),
        EstadoPermisoNotificaciones.denegado,
      );
      expect(llamadas, [
        'areNotificationsEnabled',
        'requestNotificationsPermission',
        'areNotificationsEnabled',
      ]);
    },
  );

  test('no vuelve a solicitar notificaciones tras una denegación', () async {
    permisoActivo = false;
    final servicio = NotificacionLocalService();

    expect(
      await servicio.solicitarPermisoDetallado(),
      EstadoPermisoNotificaciones.denegado,
    );
    expect(
      await servicio.solicitarPermisoDetallado(),
      EstadoPermisoNotificaciones.denegado,
    );
    expect(
      llamadas.where((llamada) => llamada == 'requestNotificationsPermission'),
      hasLength(1),
    );
  });
}
