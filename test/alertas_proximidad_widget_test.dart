import 'dart:async';

import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/services/ubicacion_service.dart';
import 'package:cercly/features/notificaciones/models/configuracion_alertas_proximidad.dart';
import 'package:cercly/features/notificaciones/services/notificacion_local_service.dart';
import 'package:cercly/features/notificaciones/services/preferencias_alertas_proximidad.dart';
import 'package:cercly/features/notificaciones/widgets/alertas_proximidad_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreferenciasFalsas implements PreferenciasAlertasProximidadRepository {
  _PreferenciasFalsas({
    this.configuracion = const ConfiguracionAlertasProximidad(),
    this.fallarLectura = false,
    this.fallarEscritura = false,
  });

  ConfiguracionAlertasProximidad configuracion;
  final bool fallarLectura;
  final bool fallarEscritura;
  int lecturas = 0;
  int escrituras = 0;
  final StreamController<ConfiguracionAlertasProximidad> _cambios =
      StreamController<ConfiguracionAlertasProximidad>.broadcast();

  @override
  Stream<ConfiguracionAlertasProximidad> get cambios => _cambios.stream;

  @override
  Future<ConfiguracionAlertasProximidad> cargar() async {
    lecturas++;
    if (fallarLectura) throw StateError('storage read failed');
    return configuracion;
  }

  @override
  Future<void> guardar(ConfiguracionAlertasProximidad nueva) async {
    escrituras++;
    if (fallarEscritura) throw StateError('storage write failed');
    configuracion = nueva;
    _cambios.add(nueva);
  }
}

class _UbicacionFalsa implements UbicacionService {
  _UbicacionFalsa({this.resultado});

  final ResultadoUbicacion? resultado;
  int consultasPermiso = 0;
  int obtenciones = 0;

  @override
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  }) async {
    consultasPermiso++;
    return resultado?.estado ?? EstadoUbicacion.permisoDenegado;
  }

  @override
  Future<ResultadoUbicacion> obtenerUbicacion({
    bool solicitarPermiso = false,
  }) async {
    obtenciones++;
    return resultado ??
        ResultadoUbicacion(
          estado: EstadoUbicacion.disponible,
          ubicacion: UbicacionUsuario(
            latitud: 0.81,
            longitud: -77.7,
            precisionMetros: 5,
            capturadaEn: DateTime.now(),
          ),
        );
  }

  @override
  Future<bool> abrirAjustesAplicacion() async => true;

  @override
  Future<bool> abrirAjustesUbicacion() async => true;
}

class _NotificacionesFalsas
    implements
        PermisosNotificacionesProximidad,
        DiagnosticoPermisoNotificaciones {
  _NotificacionesFalsas({
    this.permitir = true,
    this.fallar = false,
    this.estadoSolicitud,
  });

  final bool permitir;
  final bool fallar;
  final EstadoPermisoNotificaciones? estadoSolicitud;
  int lecturasPermiso = 0;
  int solicitudesPermiso = 0;

  @override
  Future<bool> tienePermisoParaNotificar() async {
    lecturasPermiso++;
    return permitir;
  }

  @override
  Future<bool> solicitarPermisoNotificaciones() async {
    solicitudesPermiso++;
    if (fallar) throw StateError('notification permission failed');
    return permitir;
  }

  @override
  Future<EstadoPermisoNotificaciones> consultarEstadoDetallado() async =>
      permitir
      ? EstadoPermisoNotificaciones.concedido
      : EstadoPermisoNotificaciones.desactivadoEnAjustes;

  @override
  Future<EstadoPermisoNotificaciones> solicitarPermisoDetallado() async {
    solicitudesPermiso++;
    if (fallar) return EstadoPermisoNotificaciones.errorTecnico;
    return estadoSolicitud ??
        (permitir
            ? EstadoPermisoNotificaciones.concedido
            : EstadoPermisoNotificaciones.denegado);
  }

  @override
  Future<bool> abrirAjustesNotificaciones() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> montar(
    WidgetTester tester, {
    required _PreferenciasFalsas preferencias,
    required _UbicacionFalsa ubicacion,
    required _NotificacionesFalsas notificaciones,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AlertasProximidadSection(
                preferencias: preferencias,
                ubicacionService: ubicacion,
                notificaciones: notificaciones,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cambiar(WidgetTester tester, bool activas) async {
    final control = tester.widget<SwitchListTile>(
      find.byKey(const Key('alertas-proximidad-switch')),
    );
    control.onChanged!(activas);
    await tester.pumpAndSettle();
  }

  testWidgets('lectura normal mantiene apagado sin consultar permisos', (
    tester,
  ) async {
    final preferencias = _PreferenciasFalsas();
    final ubicacion = _UbicacionFalsa();
    final notificaciones = _NotificacionesFalsas();
    await montar(
      tester,
      preferencias: preferencias,
      ubicacion: ubicacion,
      notificaciones: notificaciones,
    );

    expect(preferencias.lecturas, 1);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('alertas-proximidad-switch')),
          )
          .value,
      isFalse,
    );
    expect(ubicacion.consultasPermiso, 0);
    expect(ubicacion.obtenciones, 0);
    expect(notificaciones.lecturasPermiso, 0);
    expect(notificaciones.solicitudesPermiso, 0);
    expect(
      find.text('No pudimos leer la configuración de alertas.'),
      findsNothing,
    );
  });

  testWidgets('guardar y desactivar persisten ambos estados', (tester) async {
    final preferencias = _PreferenciasFalsas();
    final ubicacion = _UbicacionFalsa();
    final notificaciones = _NotificacionesFalsas();
    await montar(
      tester,
      preferencias: preferencias,
      ubicacion: ubicacion,
      notificaciones: notificaciones,
    );

    await cambiar(tester, true);
    expect(preferencias.configuracion.activadas, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('alertas-proximidad-switch')),
          )
          .value,
      isTrue,
    );
    expect(ubicacion.obtenciones, 1);
    expect(notificaciones.solicitudesPermiso, 1);

    await cambiar(tester, false);
    expect(preferencias.configuracion.activadas, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('alertas-proximidad-switch')),
          )
          .value,
      isFalse,
    );
    expect(preferencias.escrituras, 2);
  });

  testWidgets('permiso de ubicación muestra su mensaje sin guardar', (
    tester,
  ) async {
    final preferencias = _PreferenciasFalsas();
    final ubicacion = _UbicacionFalsa(
      resultado: const ResultadoUbicacion(
        estado: EstadoUbicacion.permisoDenegado,
        mensaje: 'Concede el permiso de ubicación.',
      ),
    );
    final notificaciones = _NotificacionesFalsas();
    await montar(
      tester,
      preferencias: preferencias,
      ubicacion: ubicacion,
      notificaciones: notificaciones,
    );

    await cambiar(tester, true);

    expect(find.text('Concede el permiso de ubicación.'), findsOneWidget);
    expect(preferencias.escrituras, 0);
    expect(notificaciones.solicitudesPermiso, 0);
  });

  testWidgets(
    'falla de permiso de notificaciones no se presenta como fallo de guardado',
    (tester) async {
      final preferencias = _PreferenciasFalsas();
      final notificaciones = _NotificacionesFalsas(fallar: true);
      await montar(
        tester,
        preferencias: preferencias,
        ubicacion: _UbicacionFalsa(),
        notificaciones: notificaciones,
      );

      await cambiar(tester, true);

      expect(
        find.text(
          'Cercly no pudo consultar el permiso del sistema por un error técnico. Inténtalo de nuevo o revisa Ajustes.',
        ),
        findsOneWidget,
      );
      expect(preferencias.escrituras, 0);
    },
  );

  testWidgets(
    'permiso de notificaciones denegado mantiene el control apagado',
    (tester) async {
      final preferencias = _PreferenciasFalsas();
      final notificaciones = _NotificacionesFalsas(permitir: false);
      await montar(
        tester,
        preferencias: preferencias,
        ubicacion: _UbicacionFalsa(),
        notificaciones: notificaciones,
      );

      await cambiar(tester, true);

      expect(
        find.text(
          'No concediste el permiso de notificaciones. Puedes habilitarlo en los ajustes de Cercly.',
        ),
        findsOneWidget,
      );
      expect(preferencias.escrituras, 0);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('alertas-proximidad-switch')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'fallo de almacenamiento identifica que no se guardó localmente',
    (tester) async {
      final preferencias = _PreferenciasFalsas(fallarEscritura: true);
      await montar(
        tester,
        preferencias: preferencias,
        ubicacion: _UbicacionFalsa(),
        notificaciones: _NotificacionesFalsas(),
      );

      await cambiar(tester, true);

      expect(
        find.text(
          'No se pudo guardar la preferencia en el dispositivo. Las alertas siguen desactivadas; vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
      expect(preferencias.configuracion.activadas, isFalse);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('alertas-proximidad-switch')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets('fallo al desactivar conserva el estado anterior claramente', (
    tester,
  ) async {
    final preferencias = _PreferenciasFalsas(
      configuracion: const ConfiguracionAlertasProximidad(activadas: true),
      fallarEscritura: true,
    );
    await montar(
      tester,
      preferencias: preferencias,
      ubicacion: _UbicacionFalsa(),
      notificaciones: _NotificacionesFalsas(),
    );

    await cambiar(tester, false);

    expect(
      find.text(
        'No se pudo guardar el cambio en el dispositivo. El interruptor conserva su estado anterior; inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(preferencias.configuracion.activadas, isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('alertas-proximidad-switch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('notificaciones apagadas en Android tienen mensaje específico', (
    tester,
  ) async {
    final preferencias = _PreferenciasFalsas();
    await montar(
      tester,
      preferencias: preferencias,
      ubicacion: _UbicacionFalsa(),
      notificaciones: _NotificacionesFalsas(
        permitir: false,
        estadoSolicitud: EstadoPermisoNotificaciones.desactivadoEnAjustes,
      ),
    );

    await cambiar(tester, true);

    expect(
      find.text(
        'Las notificaciones de Cercly están desactivadas en Android. Actívalas en Ajustes y vuelve a intentarlo.',
      ),
      findsOneWidget,
    );
    expect(preferencias.configuracion.activadas, isFalse);
  });

  testWidgets('fallo de lectura no solicita permisos ni intenta guardar', (
    tester,
  ) async {
    final preferencias = _PreferenciasFalsas(fallarLectura: true);
    final ubicacion = _UbicacionFalsa();
    final notificaciones = _NotificacionesFalsas();
    await montar(
      tester,
      preferencias: preferencias,
      ubicacion: ubicacion,
      notificaciones: notificaciones,
    );

    expect(
      find.text('No pudimos leer la configuración de alertas.'),
      findsOneWidget,
    );
    expect(ubicacion.obtenciones, 0);
    expect(notificaciones.solicitudesPermiso, 0);
    expect(preferencias.escrituras, 0);
  });
}
