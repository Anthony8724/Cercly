import 'dart:async';

import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/services/ubicacion_service.dart';
import 'package:cercly/features/notificaciones/controllers/monitor_proximidad_controller.dart';
import 'package:cercly/features/notificaciones/models/configuracion_alertas_proximidad.dart';
import 'package:cercly/features/notificaciones/services/control_notificaciones_promocion.dart';
import 'package:cercly/features/notificaciones/services/geofencing_experimental_service.dart';
import 'package:cercly/features/notificaciones/services/historial_notificaciones_promocion.dart';
import 'package:cercly/features/notificaciones/services/notificacion_local_service.dart';
import 'package:cercly/features/notificaciones/services/preferencias_alertas_proximidad.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/services/promocion_publica_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final instanteBase = DateTime(2026, 9, 14, 12);

PromocionDestacadaModel promocion({
  String id = 'promo-1',
  String establecimientoId = 'establecimiento-1',
  bool activa = true,
  double distancia = 50,
  int radio = 100,
  DateTime? inicio,
  DateTime? fin,
}) {
  return PromocionDestacadaModel(
    id: id,
    establecimientoId: establecimientoId,
    establecimientoNombre: 'Café Ejemplo',
    categoriaNombre: 'Comida y bebidas',
    titulo: '20% de descuento',
    descripcion: 'Promoción de prueba',
    fechaInicio: inicio ?? instanteBase.subtract(const Duration(hours: 1)),
    fechaFin: fin ?? instanteBase.add(const Duration(hours: 1)),
    radioAlertaMetros: radio,
    latitud: 0.8116,
    longitud: -77.7172,
    distanciaMetros: distancia,
    activa: activa,
  );
}

class _UbicacionFalsa implements UbicacionService {
  _UbicacionFalsa(this.resultado);

  final ResultadoUbicacion resultado;
  int solicitudes = 0;

  @override
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  }) async => resultado.estado;

  @override
  Future<bool> abrirAjustesAplicacion() async => true;

  @override
  Future<bool> abrirAjustesUbicacion() async => true;

  @override
  Future<ResultadoUbicacion> obtenerUbicacion({
    bool solicitarPermiso = false,
  }) async {
    solicitudes++;
    return resultado;
  }
}

class _PromocionesFalsas implements PromocionesCercanasRepository {
  _PromocionesFalsas(this.promociones, {this.error});

  final List<PromocionDestacadaModel> promociones;
  final Object? error;
  int consultas = 0;
  double? ultimaLatitud;
  double? ultimaLongitud;

  @override
  Future<List<PromocionDestacadaModel>> listarCercanas({
    required double latitudUsuario,
    required double longitudUsuario,
    int radioUsuarioMetros = 500,
  }) async {
    consultas++;
    ultimaLatitud = latitudUsuario;
    ultimaLongitud = longitudUsuario;
    if (error case final error?) throw error;
    return promociones;
  }
}

class _NotificacionesFalsas
    implements NotificacionPromocionGateway, NotificacionPromocionSimulable {
  _NotificacionesFalsas({this.permitir = true});

  final bool permitir;
  final mostradas = <PromocionDestacadaModel>[];
  final simuladas = <PromocionDestacadaModel>[];
  int inicializaciones = 0;

  @override
  Future<void> inicializar() async => inicializaciones++;

  @override
  Future<bool> tienePermisoParaNotificar() async => permitir;

  @override
  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion) async {
    if (!permitir) {
      return false;
    }

    mostradas.add(promocion);
    return true;
  }

  @override
  Future<bool> mostrarPromocionSimulada(
    PromocionDestacadaModel promocion,
  ) async {
    if (!permitir) return false;
    simuladas.add(promocion);
    return true;
  }
}

class _HistorialFalso
    implements
        HistorialNotificacionesPromocion,
        BorradoHistorialLocalNotificaciones {
  _HistorialFalso([Map<String, DateTime>? inicial])
    : _datos = HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: Map<String, DateTime>.from(inicial ?? const {}),
        recientes: (inicial?.values.toList() ?? <DateTime>[])..sort(),
      );

  HistorialNotificacionesPromocionDatos _datos;
  int guardados = 0;

  Map<String, DateTime> get datos =>
      Map.unmodifiable(_datos.ultimaPorPromocion);

  @override
  Future<HistorialNotificacionesPromocionDatos> cargar() async => _datos;

  @override
  Future<void> guardar(HistorialNotificacionesPromocionDatos historial) async {
    guardados++;
    _datos = historial;
  }

  @override
  Future<void> borrarDatosLocales() async {
    _datos = const HistorialNotificacionesPromocionDatos();
  }
}

class _PreferenciasFalsas implements PreferenciasAlertasProximidadRepository {
  _PreferenciasFalsas({
    this.configuracion = const ConfiguracionAlertasProximidad(activadas: true),
  });

  ConfiguracionAlertasProximidad configuracion;
  final StreamController<ConfiguracionAlertasProximidad> _cambios =
      StreamController<ConfiguracionAlertasProximidad>.broadcast();

  @override
  Stream<ConfiguracionAlertasProximidad> get cambios => _cambios.stream;

  @override
  Future<ConfiguracionAlertasProximidad> cargar() async => configuracion;

  @override
  Future<void> guardar(ConfiguracionAlertasProximidad nueva) async {
    configuracion = nueva;
    _cambios.add(nueva);
  }
}

void main() {
  group('ControlNotificacionesPromocion', () {
    late ControlNotificacionesPromocion control;

    setUp(() {
      control = ControlNotificacionesPromocion(
        cooldown: const Duration(hours: 2),
      );
    });

    test('promoción dentro del radio puede notificarse', () {
      final resultado = control.evaluar([promocion()], ahora: instanteBase);

      expect(resultado.map((item) => item.id), ['promo-1']);
    });

    test('promoción fuera del radio no se notifica', () {
      final resultado = control.evaluar([
        promocion(distancia: 101),
      ], ahora: instanteBase);

      expect(resultado, isEmpty);
    });

    test('promoción inactiva no se notifica', () {
      final resultado = control.evaluar([
        promocion(activa: false),
      ], ahora: instanteBase);

      expect(resultado, isEmpty);
    });

    test('promoción vencida no se notifica', () {
      final resultado = control.evaluar([
        promocion(
          inicio: instanteBase.subtract(const Duration(hours: 2)),
          fin: instanteBase.subtract(const Duration(minutes: 1)),
        ),
      ], ahora: instanteBase);

      expect(resultado, isEmpty);
    });

    test('permanecer dentro no repite durante el cooldown', () {
      expect(control.evaluar([promocion()], ahora: instanteBase), hasLength(1));
      control.registrarNotificacion('promo-1', ahora: instanteBase);

      expect(
        control.evaluar([
          promocion(),
        ], ahora: instanteBase.add(const Duration(minutes: 30))),
        isEmpty,
      );
    });

    test('salir y volver antes del cooldown todavía no repite', () {
      expect(control.evaluar([promocion()], ahora: instanteBase), hasLength(1));
      control.registrarNotificacion('promo-1', ahora: instanteBase);

      control.evaluar([
        promocion(distancia: 500),
      ], ahora: instanteBase.add(const Duration(minutes: 15)));

      final resultado = control.evaluar([
        promocion(),
      ], ahora: instanteBase.add(const Duration(hours: 1)));

      expect(resultado, isEmpty);
    });

    test('salir y volver después del cooldown permite notificar', () {
      final promocionVigente = promocion(
        fin: instanteBase.add(const Duration(hours: 4)),
      );

      expect(
        control.evaluar([promocionVigente], ahora: instanteBase),
        hasLength(1),
      );
      control.registrarNotificacion('promo-1', ahora: instanteBase);

      control.evaluar([
        promocion(
          distancia: 500,
          fin: instanteBase.add(const Duration(hours: 4)),
        ),
      ], ahora: instanteBase.add(const Duration(minutes: 30)));

      final resultado = control.evaluar([
        promocionVigente,
      ], ahora: instanteBase.add(const Duration(hours: 3)));

      expect(resultado, hasLength(1));
    });

    test('solo genera una alerta por ciclo aunque haya varias promociones', () {
      final resultado = control.evaluar([
        promocion(),
        promocion(id: 'promo-2'),
      ], ahora: instanteBase);

      expect(resultado, hasLength(1));
    });

    test('historial previo mantiene el cooldown tras reiniciar', () {
      final nuevoControl = ControlNotificacionesPromocion(
        cooldown: const Duration(hours: 2),
      );
      nuevoControl.cargarHistorial(
        HistorialNotificacionesPromocionDatos(
          ultimaPorPromocion: {'promo-1': instanteBase},
          recientes: [instanteBase],
        ),
      );

      final resultado = nuevoControl.evaluar([
        promocion(),
      ], ahora: instanteBase.add(const Duration(minutes: 30)));

      expect(resultado, isEmpty);
    });

    test('límite global respeta intervalo y máximo diario', () {
      final limitado = ControlNotificacionesPromocion(
        intervaloGlobal: const Duration(minutes: 15),
        maximoPorDia: 2,
      );
      expect(
        limitado.evaluar([promocion()], ahora: instanteBase),
        hasLength(1),
      );
      limitado.registrarNotificacion('promo-1', ahora: instanteBase);
      expect(
        limitado.evaluar([
          promocion(id: 'promo-2'),
        ], ahora: instanteBase.add(const Duration(minutes: 5))),
        isEmpty,
      );
      expect(
        limitado.evaluar([
          promocion(id: 'promo-2'),
        ], ahora: instanteBase.add(const Duration(minutes: 20))),
        hasLength(1),
      );
      limitado.registrarNotificacion(
        'promo-2',
        ahora: instanteBase.add(const Duration(minutes: 20)),
      );
      expect(
        limitado.evaluar([
          promocion(id: 'promo-3'),
        ], ahora: instanteBase.add(const Duration(minutes: 40))),
        isEmpty,
      );
    });
  });

  group('MonitorProximidadController', () {
    test('no consulta ubicación hasta aceptar el aviso de cercanía', () async {
      SharedPreferences.setMockInitialValues({});
      final ubicacion = _UbicacionFalsa(
        const ResultadoUbicacion(estado: EstadoUbicacion.permisoDenegado),
      );
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: ubicacion,
        promocionesService: _PromocionesFalsas([]),
        notificaciones: notificaciones,
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(
          configuracion: const ConfiguracionAlertasProximidad(),
        ),
      );

      await controller.iniciar();

      expect(ubicacion.solicitudes, 0);
      expect(notificaciones.inicializaciones, 1);
      controller.dispose();
    });

    test('consulta ubicación, promociones y envía notificables', () async {
      final promociones = _PromocionesFalsas([promocion()]);
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase,
            ),
          ),
        ),
        promocionesService: promociones,
        notificaciones: notificaciones,
        control: ControlNotificacionesPromocion(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(promociones.consultas, 1);
      expect(notificaciones.mostradas, hasLength(1));
      expect(controller.ultimoResultadoDiagnostico, 'notificacion_enviada');
    });

    test('alertas desactivadas no consultan ubicación', () async {
      final ubicacion = _UbicacionFalsa(
        const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
      );
      final promociones = _PromocionesFalsas([promocion()]);
      final controller = MonitorProximidadController(
        ubicacionService: ubicacion,
        promocionesService: promociones,
        notificaciones: _NotificacionesFalsas(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(
          configuracion: const ConfiguracionAlertasProximidad(),
        ),
      );

      await controller.verificarAhora();

      expect(ubicacion.solicitudes, 0);
      expect(promociones.consultas, 0);
      expect(controller.ultimoResultadoDiagnostico, 'alertas_desactivadas');
      controller.dispose();
    });

    test('GPS impreciso y antiguo no consulta promociones', () async {
      final ubicacion = _UbicacionFalsa(
        ResultadoUbicacion(
          estado: EstadoUbicacion.disponible,
          ubicacion: UbicacionUsuario(
            latitud: 0.8116,
            longitud: -77.7172,
            precisionMetros: 250,
            capturadaEn: instanteBase.subtract(const Duration(minutes: 3)),
          ),
        ),
      );
      final promociones = _PromocionesFalsas([promocion()]);
      final controller = MonitorProximidadController(
        ubicacionService: ubicacion,
        promocionesService: promociones,
        notificaciones: _NotificacionesFalsas(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(ubicacion.solicitudes, 1);
      expect(promociones.consultas, 0);
      expect(
        controller.ultimoResultadoDiagnostico,
        'ubicacion_imprecisa_o_desactualizada',
      );
      controller.dispose();
    });

    test('notificaciones deshabilitadas no consultan ubicación', () async {
      final ubicacion = _UbicacionFalsa(
        const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
      );
      final promociones = _PromocionesFalsas([promocion()]);
      final controller = MonitorProximidadController(
        ubicacionService: ubicacion,
        promocionesService: promociones,
        notificaciones: _NotificacionesFalsas(permitir: false),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
      );

      await controller.verificarAhora();

      expect(ubicacion.solicitudes, 0);
      expect(promociones.consultas, 0);
      controller.dispose();
    });

    test('error de red no genera alertas ni rompe el monitor', () async {
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase,
            ),
          ),
        ),
        promocionesService: _PromocionesFalsas(
          const [],
          error: StateError('offline'),
        ),
        notificaciones: _NotificacionesFalsas(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase,
      );

      await expectLater(controller.verificarAhora(), completes);
      controller.dispose();
    });

    test('permiso de ubicación denegado no consulta promociones', () async {
      final promociones = _PromocionesFalsas([promocion()]);
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(estado: EstadoUbicacion.permisoDenegado),
        ),
        promocionesService: promociones,
        notificaciones: notificaciones,
        control: ControlNotificacionesPromocion(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(promociones.consultas, 0);
      expect(notificaciones.mostradas, isEmpty);
    });

    test('notificación exitosa guarda el cooldown local', () async {
      final historial = _HistorialFalso();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase,
            ),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: _NotificacionesFalsas(),
        control: ControlNotificacionesPromocion(),
        historial: historial,
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(historial.guardados, 1);
      expect(historial.datos['promo-1'], instanteBase);
    });

    test('notificación no mostrada no consume el cooldown', () async {
      final historial = _HistorialFalso();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase,
            ),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: _NotificacionesFalsas(permitir: false),
        control: ControlNotificacionesPromocion(),
        historial: historial,
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(historial.guardados, 0);
      expect(historial.datos, isEmpty);
    });

    test('historial cargado evita repetir después de reiniciar', () async {
      final historial = _HistorialFalso({'promo-1': instanteBase});
      historial._datos = HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: {'promo-1': instanteBase},
        recientes: [instanteBase],
        promocionesDentro: {'promo-1'},
      );
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase.add(const Duration(minutes: 30)),
            ),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: notificaciones,
        control: ControlNotificacionesPromocion(
          cooldown: const Duration(hours: 2),
        ),
        historial: historial,
        preferencias: _PreferenciasFalsas(),
        ahora: () => instanteBase.add(const Duration(minutes: 30)),
      );

      await controller.verificarAhora();

      expect(notificaciones.mostradas, isEmpty);
      expect(historial.guardados, 0);
      expect(
        controller.ultimoResultadoDiagnostico,
        'cooldown_limite_o_misma_zona',
      );
    });

    test(
      'simulación Staging reutiliza elegibilidad y notifica con marca QA',
      () async {
        if (!GeofencingExperimentalService.staging) return;
        final promociones = _PromocionesFalsas([
          promocion(
            id: 'f14a1f14-14b0-4b14-8a14-140000000002',
            establecimientoId: 'f14a1f14-14b0-4b14-8a14-140000000001',
            distancia: 0,
          ),
        ]);
        final notificaciones = _NotificacionesFalsas();
        final historial = _HistorialFalso();
        final ubicacion = _UbicacionFalsa(
          const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
        );
        final controller = MonitorProximidadController(
          ubicacionService: ubicacion,
          promocionesService: promociones,
          notificaciones: notificaciones,
          historial: historial,
          preferencias: _PreferenciasFalsas(),
          stagingQaEnabled: true,
          ahora: () => instanteBase,
        );

        final result = await controller.simularEntradaUpec();

        expect(result, 'simulacion_notificacion_enviada');
        expect(promociones.ultimaLatitud, 0.80525);
        expect(promociones.ultimaLongitud, -77.73434);
        expect(
          ubicacion.solicitudes,
          0,
          reason: 'No lee ni falsifica la ubicación del dispositivo.',
        );
        expect(notificaciones.simuladas, hasLength(1));
        expect(notificaciones.mostradas, isEmpty);
        expect(
          notificaciones.simuladas.single.establecimientoId,
          'f14a1f14-14b0-4b14-8a14-140000000001',
        );
        expect(historial.guardados, 1);
        expect(
          controller.ultimoResultadoDiagnostico,
          'simulacion_notificacion_enviada',
        );
      },
    );

    test('simulación no limpia ni ignora un cooldown existente', () async {
      if (!GeofencingExperimentalService.staging) return;
      final id = 'f14a1f14-14b0-4b14-8a14-140000000002';
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
        ),
        promocionesService: _PromocionesFalsas([
          promocion(
            id: id,
            establecimientoId: 'f14a1f14-14b0-4b14-8a14-140000000001',
            distancia: 0,
          ),
        ]),
        notificaciones: notificaciones,
        historial: _HistorialFalso({id: instanteBase}),
        preferencias: _PreferenciasFalsas(),
        stagingQaEnabled: true,
        ahora: () => instanteBase.add(const Duration(minutes: 20)),
      );

      expect(
        await controller.simularEntradaUpec(),
        'simulacion_bloqueada_cooldown_o_radio',
      );
      expect(notificaciones.simuladas, isEmpty);
    });

    test('simulación rechaza promoción vencida', () async {
      if (!GeofencingExperimentalService.staging) return;
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
        ),
        promocionesService: _PromocionesFalsas([
          promocion(
            id: 'f14a1f14-14b0-4b14-8a14-140000000002',
            establecimientoId: 'f14a1f14-14b0-4b14-8a14-140000000001',
            distancia: 0,
            fin: instanteBase.subtract(const Duration(seconds: 1)),
          ),
        ]),
        notificaciones: _NotificacionesFalsas(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        stagingQaEnabled: true,
        ahora: () => instanteBase,
      );

      expect(
        await controller.simularEntradaUpec(),
        'simulacion_sin_promocion_vigente',
      );
    });

    test(
      'simulación respeta permisos denegados y consentimiento apagado',
      () async {
        if (!GeofencingExperimentalService.staging) return;
        final promociones = _PromocionesFalsas([]);
        final notifications = _NotificacionesFalsas();
        final sinConsentimiento = MonitorProximidadController(
          ubicacionService: _UbicacionFalsa(
            const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
          ),
          promocionesService: promociones,
          notificaciones: notifications,
          historial: _HistorialFalso(),
          preferencias: _PreferenciasFalsas(
            configuracion: const ConfiguracionAlertasProximidad(
              activadas: false,
            ),
          ),
          stagingQaEnabled: true,
          ahora: () => instanteBase,
        );
        expect(
          await sinConsentimiento.simularEntradaUpec(),
          'simulacion_sin_consentimiento',
        );
        expect(promociones.consultas, 0);

        final sinPermiso = MonitorProximidadController(
          ubicacionService: _UbicacionFalsa(
            const ResultadoUbicacion(estado: EstadoUbicacion.permisoDenegado),
          ),
          promocionesService: promociones,
          notificaciones: notifications,
          historial: _HistorialFalso(),
          preferencias: _PreferenciasFalsas(),
          stagingQaEnabled: true,
          ahora: () => instanteBase,
        );
        expect(
          await sinPermiso.simularEntradaUpec(),
          'simulacion_permiso_ubicacion_denegado',
        );
        expect(promociones.consultas, 0);

        final sinNotificaciones = MonitorProximidadController(
          ubicacionService: _UbicacionFalsa(
            const ResultadoUbicacion(estado: EstadoUbicacion.disponible),
          ),
          promocionesService: promociones,
          notificaciones: _NotificacionesFalsas(permitir: false),
          historial: _HistorialFalso(),
          preferencias: _PreferenciasFalsas(),
          stagingQaEnabled: true,
          ahora: () => instanteBase,
        );
        expect(
          await sinNotificaciones.simularEntradaUpec(),
          'simulacion_permiso_notificaciones_denegado',
        );
        expect(promociones.consultas, 0);
      },
    );

    test(
      'el motor de simulación retorna no disponible fuera de Staging',
      () async {
        final promociones = _PromocionesFalsas([]);
        final controller = MonitorProximidadController(
          promocionesService: promociones,
          notificaciones: _NotificacionesFalsas(),
          historial: _HistorialFalso(),
          preferencias: _PreferenciasFalsas(),
          stagingQaEnabled: false,
        );
        expect(
          await controller.simularEntradaUpec(),
          'simulacion_no_disponible',
        );
        expect(promociones.consultas, 0);
      },
    );

    test('reiniciar historial QA limpia cooldown e ids dentro sin cambiar permisos', () async {
      final id = 'f14a1f14-14b0-4b14-8a14-140000000002';
      final historial = _HistorialFalso({id: instanteBase});
      historial._datos = HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: {id: instanteBase},
        recientes: [instanteBase],
        promocionesDentro: {id},
      );
      final preferencias = _PreferenciasFalsas();
      final controller = MonitorProximidadController(
        historial: historial,
        promocionesService: _PromocionesFalsas([]),
        preferencias: preferencias,
        stagingQaEnabled: false,
      );

      await controller.reiniciarHistorialLocalDiagnostico();

      expect(historial.datos, isEmpty);
      expect((await historial.cargar()).recientes, isEmpty);
      expect((await historial.cargar()).promocionesDentro, isEmpty);
      expect(preferencias.configuracion.activadas, isTrue);
      expect(
        controller.ultimoResultadoDiagnostico,
        'historial_local_reiniciado',
      );
    });
  });
}
