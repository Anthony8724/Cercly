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
    expect(inicial.frecuencia, FrecuenciaAlertasProximidad.normal);
    expect(inicial.frecuencia.maximoPorDia, 6);
    expect(inicial.horarioDescanso, isNull);

    await preferencias.guardar(
      const ConfiguracionAlertasProximidad(activadas: true, radioMetros: 3000),
    );

    final recuperadas = await PreferenciasAlertasProximidadLocal().cargar();
    expect(recuperadas.activadas, isTrue);
    expect(recuperadas.radioMetros, 3000);
  });

  test('niveles y descanso persisten por usuario tras reiniciar', () async {
    var usuario = 'cuenta-a';
    final repositorio = PreferenciasAlertasProximidadLocal(
      usuarioId: () => usuario,
    );
    for (final nivel in FrecuenciaAlertasProximidad.values) {
      await repositorio.guardar(
        ConfiguracionAlertasProximidad(
          activadas: true,
          frecuencia: nivel,
          horarioDescanso: const HorarioDescanso(
            inicioMinutos: 22 * 60,
            finMinutos: 7 * 60,
          ),
        ),
      );
      final restaurado = await PreferenciasAlertasProximidadLocal(
        usuarioId: () => usuario,
      ).cargar();
      expect(restaurado.frecuencia, nivel);
      expect(restaurado.frecuencia.maximoPorDia, switch (nivel) {
        FrecuenciaAlertasProximidad.baja => 3,
        FrecuenciaAlertasProximidad.normal => 6,
        FrecuenciaAlertasProximidad.alta => 10,
      });
      expect(restaurado.horarioDescanso?.inicioMinutos, 22 * 60);
    }
    usuario = 'cuenta-b';
    final otra = await repositorio.cargar();
    expect(otra.activadas, isFalse);
    expect(otra.frecuencia, FrecuenciaAlertasProximidad.normal);
    expect(otra.horarioDescanso, isNull);
    await repositorio.guardar(
      otra.copiarCon(frecuencia: FrecuenciaAlertasProximidad.baja),
    );
    usuario = 'cuenta-a';
    expect(
      (await repositorio.cargar()).frecuencia,
      FrecuenciaAlertasProximidad.alta,
    );
    await repositorio.borrarDatosLocales();
    expect((await repositorio.cargar()).activadas, isFalse);
    usuario = 'cuenta-b';
    expect(
      (await repositorio.cargar()).frecuencia,
      FrecuenciaAlertasProximidad.baja,
    );
  });

  test(
    'las claves antiguas no transfieren consentimiento a otra cuenta',
    () async {
      final antiguas = PreferenciasAlertasProximidadLocal(
        usuarioId: () => null,
      );
      await antiguas.guardar(
        const ConfiguracionAlertasProximidad(
          activadas: true,
          frecuencia: FrecuenciaAlertasProximidad.alta,
        ),
      );
      final nuevaCuenta = PreferenciasAlertasProximidadLocal(
        usuarioId: () => 'otra-cuenta',
      );
      expect((await nuevaCuenta.cargar()).activadas, isFalse);
      expect(
        (await nuevaCuenta.cargar()).frecuencia,
        FrecuenciaAlertasProximidad.normal,
      );
    },
  );

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
    'configuración dañada desactiva alertas en vez de omitir descanso',
    () async {
      final preferencias = await SharedPreferences.getInstance();
      const clave = 'cercly.alertas_proximidad.config.v2.usuario.cuenta-a';
      await preferencias.setString(
        clave,
        '{"version":2,"activadas":true,"radio_metros":1500,'
        '"frecuencia":"baja","descanso":{"inicio":1320,"fin":1320}}',
      );
      final repositorio = PreferenciasAlertasProximidadLocal(
        usuarioId: () => 'cuenta-a',
      );
      expect((await repositorio.cargar()).activadas, isFalse);
      await preferencias.setString(
        clave,
        '{"version":2,"activadas":true,"radio_metros":1500,'
        '"frecuencia":"desconocida","descanso":null}',
      );
      expect((await repositorio.cargar()).activadas, isFalse);
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

  test('historial y cooldown quedan separados entre cuentas', () async {
    var cuenta = 'usuario-a';
    final historial = HistorialNotificacionesPromocionLocal(
      usuarioId: () => cuenta,
    );
    final momento = DateTime.utc(2026, 11, 11, 12);
    await historial.guardar(
      HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: {'p1': momento},
        ultimaPorEstablecimiento: {'negocio-1': momento},
        recientes: [momento],
      ),
    );
    cuenta = 'usuario-b';
    expect((await historial.cargar()).ultimaPorPromocion, isEmpty);
    await historial.guardar(
      HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: {'p2': momento},
      ),
    );
    cuenta = 'usuario-a';
    final recuperado = await historial.cargar();
    expect(recuperado.ultimaPorPromocion.keys, ['p1']);
    expect(recuperado.ultimaPorEstablecimiento['negocio-1'], momento);
    await historial.borrarDatosLocales();
    expect((await historial.cargar()).ultimaPorPromocion, isEmpty);
    cuenta = 'usuario-b';
    expect((await historial.cargar()).ultimaPorPromocion.keys, ['p2']);
  });

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
