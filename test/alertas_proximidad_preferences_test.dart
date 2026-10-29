import 'package:cercly/features/notificaciones/models/configuracion_alertas_proximidad.dart';
import 'package:cercly/features/notificaciones/services/notificacion_local_service.dart';
import 'package:cercly/features/notificaciones/services/historial_notificaciones_promocion.dart';
import 'package:cercly/features/notificaciones/services/preferencias_alertas_proximidad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('alertas desactivadas por defecto y radio local persistente', () async {
    final preferencias = PreferenciasAlertasProximidadLocal();

    final inicial = await preferencias.cargar();
    expect(inicial.activadas, isFalse);
    expect(
      inicial.radioMetros,
      ConfiguracionAlertasProximidad.radioPredeterminadoMetros,
    );

    await preferencias.guardar(
      const ConfiguracionAlertasProximidad(activadas: true, radioMetros: 3000),
    );

    final recuperadas = await PreferenciasAlertasProximidadLocal().cargar();
    expect(recuperadas.activadas, isTrue);
    expect(recuperadas.radioMetros, 3000);
  });

  test(
    'el repositorio rechaza radios fuera de las opciones permitidas',
    () async {
      final preferencias = PreferenciasAlertasProximidadLocal();

      await expectLater(
        preferencias.guardar(
          const ConfiguracionAlertasProximidad(
            activadas: true,
            radioMetros: 250,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'historial persiste identificadores y tiempos sin coordenadas',
    () async {
      final momento = DateTime.utc(2026, 10, 29, 12);
      final historial = HistorialNotificacionesPromocionLocal();
      await historial.guardar(
        HistorialNotificacionesPromocionDatos(
          ultimaPorPromocion: {'promo-1': momento},
          recientes: [momento],
          promocionesDentro: {'promo-1'},
        ),
      );

      final recuperado = await HistorialNotificacionesPromocionLocal().cargar();
      expect(recuperado.ultimaPorPromocion['promo-1'], momento);
      expect(recuperado.recientes, [momento]);
      expect(recuperado.promocionesDentro, {'promo-1'});
    },
  );

  test('el payload de navegación solo acepta identificadores simples', () {
    expect(
      NotificacionLocalService.establecimientoIdDesdePayload('negocio-123'),
      'negocio-123',
    );
    expect(
      NotificacionLocalService.establecimientoIdDesdePayload(null),
      isNull,
    );
    expect(NotificacionLocalService.establecimientoIdDesdePayload(' '), isNull);
    expect(
      NotificacionLocalService.establecimientoIdDesdePayload('x' * 81),
      isNull,
    );
  });
}
