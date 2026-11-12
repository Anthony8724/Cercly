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
import 'package:cercly/features/notificaciones/widgets/radar_cercly_panel.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/services/promocion_publica_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  _PromocionesFalsas(this.promociones, {this.error, this.antesDeResponder});

  final List<PromocionDestacadaModel> promociones;
  final Object? error;
  final Future<void> Function()? antesDeResponder;
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
    await antesDeResponder?.call();
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

    test('valores iniciales del radar son configurables', () {
      final inicial = ControlNotificacionesPromocion();
      expect(inicial.cooldown, const Duration(hours: 4));
      expect(inicial.intervaloGlobal, const Duration(minutes: 15));
      expect(inicial.maximoPorDia, 6);
      expect(ConfiguracionAlertasProximidad.radioPredeterminadoMetros, 1500);
      final monitor = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(estado: EstadoUbicacion.permisoDenegado),
        ),
        promocionesService: _PromocionesFalsas([]),
        notificaciones: _NotificacionesFalsas(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
      );
      expect(monitor.intervalo, const Duration(minutes: 3));
      monitor.dispose();
    });

    test('límites exactos de Bajo, Normal y Alto en 24 horas móviles', () {
      for (final nivel in FrecuenciaAlertasProximidad.values) {
        final politica = ControlNotificacionesPromocion();
        for (var i = 0; i < nivel.maximoPorDia; i++) {
          politica.registrarNotificacion(
            'promo-$i',
            establecimientoId: 'negocio-$i',
            ahora: instanteBase.add(Duration(minutes: i * 15)),
          );
        }
        final candidata = promocion(
          id: 'siguiente-${nivel.name}',
          establecimientoId: 'negocio-nuevo',
          fin: instanteBase.add(const Duration(days: 2)),
        );
        expect(
          politica.evaluar(
            [candidata],
            ahora: instanteBase.add(const Duration(hours: 23)),
            maximoPorDia: nivel.maximoPorDia,
          ),
          isEmpty,
        );
        expect(
          politica.evaluar(
            [candidata],
            ahora: instanteBase.add(const Duration(hours: 24)),
            maximoPorDia: nivel.maximoPorDia,
          ),
          hasLength(1),
        );
      }
    });

    test('cambiar nivel aplica el historial existente sin reiniciar', () {
      final politica = ControlNotificacionesPromocion();
      for (var i = 0; i < 6; i++) {
        politica.registrarNotificacion(
          'p$i',
          establecimientoId: 'n$i',
          ahora: instanteBase.add(Duration(minutes: i * 15)),
        );
      }
      final candidata = promocion(
        id: 'nueva',
        establecimientoId: 'nueva',
        fin: instanteBase.add(const Duration(hours: 6)),
      );
      final momento = instanteBase.add(const Duration(hours: 2));
      expect(
        politica.evaluar([candidata], ahora: momento, maximoPorDia: 3),
        isEmpty,
      );
      expect(
        politica.evaluar([candidata], ahora: momento, maximoPorDia: 6),
        isEmpty,
      );
      expect(
        politica.evaluar([candidata], ahora: momento, maximoPorDia: 10),
        hasLength(1),
      );
    });

    test('intervalo global libera exactamente a los quince minutos', () {
      final politica = ControlNotificacionesPromocion();
      politica.registrarNotificacion(
        'primera',
        establecimientoId: 'negocio-1',
        ahora: instanteBase,
      );
      final siguiente = promocion(
        id: 'segunda',
        establecimientoId: 'negocio-2',
      );
      expect(
        politica.evaluar([
          siguiente,
        ], ahora: instanteBase.add(const Duration(minutes: 14, seconds: 59))),
        isEmpty,
      );
      expect(
        politica.evaluar([
          siguiente,
        ], ahora: instanteBase.add(const Duration(minutes: 15))),
        hasLength(1),
      );
    });

    test(
      'descanso local cruza medianoche con inicio inclusivo y fin exclusivo',
      () {
        final politica = ControlNotificacionesPromocion();
        const descanso = HorarioDescanso(
          inicioMinutos: 22 * 60,
          finMinutos: 7 * 60,
        );
        final candidata = promocion(
          inicio: DateTime(2026, 11, 11),
          fin: DateTime(2026, 11, 13),
        );
        for (final instante in [
          DateTime(2026, 11, 11, 22),
          DateTime(2026, 11, 11, 23, 59),
          DateTime(2026, 11, 12),
          DateTime(2026, 11, 12, 6, 59),
        ]) {
          expect(
            politica.evaluar(
              [candidata],
              ahora: instante,
              horarioDescanso: descanso,
            ),
            isEmpty,
          );
        }
        expect(
          politica.evaluar(
            [candidata],
            ahora: DateTime(2026, 11, 12, 7),
            horarioDescanso: descanso,
          ),
          hasLength(1),
        );
      },
    );

    test('descanso local dentro del mismo día respeta ambos límites', () {
      const descanso = HorarioDescanso(
        inicioMinutos: 12 * 60,
        finMinutos: 13 * 60,
      );
      expect(descanso.contiene(DateTime(2026, 11, 11, 11, 59)), isFalse);
      expect(descanso.contiene(DateTime(2026, 11, 11, 12)), isTrue);
      expect(descanso.contiene(DateTime(2026, 11, 11, 12, 59)), isTrue);
      expect(descanso.contiene(DateTime(2026, 11, 11, 13)), isFalse);
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
      control.registrarNotificacion(
        'promo-1',
        establecimientoId: 'establecimiento-1',
        ahora: instanteBase,
      );

      expect(
        control.evaluar([
          promocion(),
        ], ahora: instanteBase.add(const Duration(minutes: 30))),
        isEmpty,
      );
    });

    test('salir y volver antes del cooldown todavía no repite', () {
      expect(control.evaluar([promocion()], ahora: instanteBase), hasLength(1));
      control.registrarNotificacion(
        'promo-1',
        establecimientoId: 'establecimiento-1',
        ahora: instanteBase,
      );

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
      control.registrarNotificacion(
        'promo-1',
        establecimientoId: 'establecimiento-1',
        ahora: instanteBase,
      );

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
      limitado.registrarNotificacion(
        'promo-1',
        establecimientoId: 'establecimiento-1',
        ahora: instanteBase,
      );
      expect(
        limitado.evaluar([
          promocion(id: 'promo-2', establecimientoId: 'establecimiento-2'),
        ], ahora: instanteBase.add(const Duration(minutes: 5))),
        isEmpty,
      );
      expect(
        limitado.evaluar([
          promocion(id: 'promo-2', establecimientoId: 'establecimiento-2'),
        ], ahora: instanteBase.add(const Duration(minutes: 20))),
        hasLength(1),
      );
      limitado.registrarNotificacion(
        'promo-2',
        establecimientoId: 'establecimiento-2',
        ahora: instanteBase.add(const Duration(minutes: 20)),
      );
      expect(
        limitado.evaluar([
          promocion(id: 'promo-3', establecimientoId: 'establecimiento-3'),
        ], ahora: instanteBase.add(const Duration(minutes: 40))),
        isEmpty,
      );
    });

    test('elige el negocio más cercano y resuelve empates por ID', () {
      final politica = ControlNotificacionesPromocion();
      final candidatas = [
        promocion(
          id: 'lejana',
          establecimientoId: 'z',
          distancia: 300,
          radio: 1500,
        ),
        promocion(
          id: 'cercana-b',
          establecimientoId: 'b',
          distancia: 50,
          radio: 1500,
        ),
        promocion(
          id: 'cercana-a',
          establecimientoId: 'a',
          distancia: 50,
          radio: 1500,
        ),
      ];
      expect(
        politica
            .evaluar(candidatas, ahora: instanteBase, radioUsuarioMetros: 1500)
            .single
            .id,
        'cercana-a',
      );
    });

    test('el radio exige caber incluso con la incertidumbre GPS', () {
      final politica = ControlNotificacionesPromocion();
      for (final distancia in [1499.0, 1500.0, 1501.0]) {
        final resultado = politica.evaluar(
          [
            promocion(
              id: 'radio-$distancia',
              distancia: distancia,
              radio: 1500,
            ),
          ],
          ahora: instanteBase,
          radioUsuarioMetros: 1500,
        );
        expect(resultado.isNotEmpty, distancia <= 1500);
      }
      expect(
        politica.evaluar(
          [promocion(id: 'incierta', distancia: 1499, radio: 1500)],
          ahora: instanteBase,
          radioUsuarioMetros: 1500,
          precisionUbicacionMetros: 2,
        ),
        isEmpty,
      );
    });

    test('vigencia incluye exactamente inicio y fin', () {
      final politica = ControlNotificacionesPromocion();
      final exacta = promocion(
        inicio: instanteBase,
        fin: instanteBase.add(const Duration(hours: 1)),
      );
      expect(politica.evaluar([exacta], ahora: instanteBase), hasLength(1));
      expect(
        politica.evaluar([
          exacta,
        ], ahora: instanteBase.add(const Duration(hours: 1))),
        hasLength(1),
      );
      expect(
        politica.evaluar([
          exacta,
        ], ahora: instanteBase.add(const Duration(hours: 1, milliseconds: 1))),
        isEmpty,
      );
    });

    test(
      'cuatro horas por negocio bloquean otra promoción y liberan al límite',
      () {
        final politica = ControlNotificacionesPromocion();
        final primera = promocion(
          id: 'p1',
          establecimientoId: 'negocio',
          fin: instanteBase.add(const Duration(hours: 6)),
        );
        final segunda = promocion(
          id: 'p2',
          establecimientoId: 'negocio',
          fin: instanteBase.add(const Duration(hours: 6)),
        );
        politica.registrarNotificacion(
          primera.id,
          establecimientoId: 'negocio',
          ahora: instanteBase,
        );
        expect(
          politica.evaluar([
            segunda,
          ], ahora: instanteBase.add(const Duration(hours: 3, minutes: 59))),
          isEmpty,
        );
        expect(
          politica.evaluar([
            segunda,
          ], ahora: instanteBase.add(const Duration(hours: 4))),
          hasLength(1),
        );
      },
    );

    test('historial del negocio sobrevive al reinicio del control', () {
      final anterior = ControlNotificacionesPromocion();
      anterior.registrarNotificacion(
        'p1',
        establecimientoId: 'negocio',
        ahora: instanteBase,
      );
      final nuevo = ControlNotificacionesPromocion()
        ..cargarHistorial(anterior.crearHistorial());
      expect(
        nuevo.evaluar([
          promocion(
            id: 'p2',
            establecimientoId: 'negocio',
            fin: instanteBase.add(const Duration(hours: 6)),
          ),
        ], ahora: instanteBase.add(const Duration(hours: 1))),
        isEmpty,
      );
    });

    test('máximo tres en 24 horas móviles y liberación exacta', () {
      final politica = ControlNotificacionesPromocion(maximoPorDia: 3);
      for (var i = 0; i < 3; i++) {
        politica.registrarNotificacion(
          'p$i',
          establecimientoId: 'n$i',
          ahora: instanteBase.add(Duration(hours: i)),
        );
      }
      final cuarta = promocion(
        id: 'p4',
        establecimientoId: 'n4',
        fin: instanteBase.add(const Duration(days: 2)),
      );
      expect(
        politica.evaluar([
          cuarta,
        ], ahora: instanteBase.add(const Duration(hours: 23))),
        isEmpty,
      );
      expect(
        politica.evaluar([
          cuarta,
        ], ahora: instanteBase.add(const Duration(hours: 24))),
        hasLength(1),
      );
    });

    test('misma promoción no se repite durante la permanencia', () {
      final politica = ControlNotificacionesPromocion();
      final vigente = promocion(
        fin: instanteBase.add(const Duration(hours: 6)),
      );
      expect(politica.evaluar([vigente], ahora: instanteBase), hasLength(1));
      politica.registrarNotificacion(
        vigente.id,
        establecimientoId: vigente.establecimientoId,
        ahora: instanteBase,
      );
      expect(
        politica.evaluar([
          vigente,
        ], ahora: instanteBase.add(const Duration(hours: 5))),
        isEmpty,
      );
      politica.evaluar(
        const [],
        ahora: instanteBase.add(const Duration(hours: 5)),
      );
      expect(
        politica.evaluar([
          vigente,
        ], ahora: instanteBase.add(const Duration(hours: 5, minutes: 1))),
        hasLength(1),
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

    test(
      'GPS periódico solo arranca con radar activo y Mapa visible',
      () async {
        final ubicacion = _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase,
            ),
          ),
        );
        final controller = MonitorProximidadController(
          ubicacionService: ubicacion,
          promocionesService: _PromocionesFalsas([]),
          notificaciones: _NotificacionesFalsas(),
          historial: _HistorialFalso(),
          preferencias: _PreferenciasFalsas(),
          usuarioId: () => 'usuario-1',
          ahora: () => instanteBase,
        );
        await controller.iniciar();
        expect(ubicacion.solicitudes, 0);
        controller.setRadarVisible(true);
        await controller.iniciar();
        expect(ubicacion.solicitudes, 0);
        controller.setRadarActivo(true);
        await controller.iniciar();
        expect(ubicacion.solicitudes, greaterThan(0));
        controller.setRadarVisible(false);
        final despuesDeSalir = ubicacion.solicitudes;
        await controller.iniciar();
        expect(ubicacion.solicitudes, despuesDeSalir);
        controller.setRadarVisible(true);
        await controller.iniciar();
        controller.suspenderPorCicloDeVida();
        final durantePausa = ubicacion.solicitudes;
        await controller.iniciar();
        expect(ubicacion.solicitudes, durantePausa);
        await controller.reanudar();
        expect(ubicacion.solicitudes, greaterThan(durantePausa));
        controller.dispose();
      },
    );

    test('radar muestra promociones sin permiso de notificación', () async {
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
        promocionesService: _PromocionesFalsas([
          promocion(id: 'lejana', distancia: 120, radio: 1500),
          promocion(id: 'cercana', distancia: 40, radio: 1500),
          promocion(
            id: 'vencida',
            distancia: 10,
            radio: 1500,
            fin: instanteBase.subtract(const Duration(seconds: 1)),
          ),
        ]),
        notificaciones: _NotificacionesFalsas(permitir: false),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        usuarioId: () => 'usuario-1',
        ahora: () => instanteBase,
      );
      controller.setRadarVisible(true);
      controller.setRadarActivo(true);
      await controller.iniciar();
      expect(controller.promocionesRadar.map((p) => p.id), [
        'cercana',
        'lejana',
      ]);
      controller.dispose();
    });

    test('revocar alertas durante la consulta impide la publicación', () async {
      final preferencias = _PreferenciasFalsas();
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
        promocionesService: _PromocionesFalsas(
          [promocion()],
          antesDeResponder: () =>
              preferencias.guardar(const ConfiguracionAlertasProximidad()),
        ),
        notificaciones: notificaciones,
        historial: _HistorialFalso(),
        preferencias: preferencias,
        ahora: () => instanteBase,
      );
      await controller.verificarAhora();
      expect(notificaciones.mostradas, isEmpty);
      expect(
        controller.ultimoResultadoDiagnostico,
        'alertas_desactivadas_o_permiso_revocado',
      );
      controller.dispose();
    });

    test('cambiar de cuenta carga historial independiente', () async {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      var cuenta = 'usuario-a';
      var reloj = instanteBase;
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
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: notificaciones,
        preferencias: _PreferenciasFalsas(),
        usuarioId: () => cuenta,
        ahora: () => reloj,
      );
      await controller.verificarAhora();
      expect(notificaciones.mostradas, hasLength(1));
      cuenta = 'usuario-b';
      reloj = reloj.add(const Duration(seconds: 30));
      await controller.verificarAhora();
      expect(notificaciones.mostradas, hasLength(2));
      controller.dispose();
    });

    test(
      'motor aplica cambio de frecuencia con historial sin reiniciar',
      () async {
        final historial = _HistorialFalso();
        historial._datos = HistorialNotificacionesPromocionDatos(
          recientes: [
            for (var i = 0; i < 6; i++)
              instanteBase.subtract(Duration(minutes: 15 * (i + 1))),
          ],
        );
        final preferencias = _PreferenciasFalsas();
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
          promocionesService: _PromocionesFalsas([promocion()]),
          notificaciones: notificaciones,
          historial: historial,
          preferencias: preferencias,
          ahora: () => instanteBase,
        );
        await controller.verificarAhora();
        expect(notificaciones.mostradas, isEmpty);
        await preferencias.guardar(
          preferencias.configuracion.copiarCon(
            frecuencia: FrecuenciaAlertasProximidad.alta,
          ),
        );
        await controller.verificarAhora();
        expect(notificaciones.mostradas, hasLength(1));
        controller.dispose();
      },
    );

    test('motor silencia descanso y permite aviso al quitarlo', () async {
      final preferencias = _PreferenciasFalsas(
        configuracion: const ConfiguracionAlertasProximidad(
          activadas: true,
          horarioDescanso: HorarioDescanso(
            inicioMinutos: 11 * 60,
            finMinutos: 13 * 60,
          ),
        ),
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
              capturadaEn: instanteBase,
            ),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: notificaciones,
        historial: _HistorialFalso(),
        preferencias: preferencias,
        ahora: () => instanteBase,
      );
      await controller.verificarAhora();
      expect(controller.ultimoResultadoDiagnostico, 'horario_descanso');
      expect(notificaciones.mostradas, isEmpty);
      await preferencias.guardar(
        preferencias.configuracion.copiarCon(quitarHorarioDescanso: true),
      );
      await controller.verificarAhora();
      expect(notificaciones.mostradas, hasLength(1));
      controller.dispose();
    });

    test(
      'Radar visual funciona con alertas apagadas sin publicar avisos',
      () async {
        final preferencias = _PreferenciasFalsas(
          configuracion: const ConfiguracionAlertasProximidad(),
        );
        final notificaciones = _NotificacionesFalsas();
        final ubicacion = _UbicacionFalsa(
          ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(
              latitud: 0.8116,
              longitud: -77.7172,
              precisionMetros: 10,
              capturadaEn: instanteBase,
            ),
          ),
        );
        final controller = MonitorProximidadController(
          ubicacionService: ubicacion,
          promocionesService: _PromocionesFalsas([promocion()]),
          notificaciones: notificaciones,
          historial: _HistorialFalso(),
          preferencias: preferencias,
          usuarioId: () => 'cuenta-a',
          ahora: () => instanteBase,
        );
        controller.setRadarVisible(true);
        controller.setRadarActivo(true);
        await controller.iniciar();
        expect(controller.promocionesRadar, hasLength(1));
        expect(notificaciones.mostradas, isEmpty);
        expect(preferencias.configuracion.activadas, isFalse);
        controller.setRadarActivo(false);
        expect(controller.promocionesRadar, isEmpty);
        expect(preferencias.configuracion.activadas, isFalse);
        controller.dispose();
      },
    );
  });

  testWidgets('temporizador se detiene al salir de Mapa y al bloquear', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final ubicacion = _UbicacionFalsa(
      ResultadoUbicacion(
        estado: EstadoUbicacion.disponible,
        ubicacion: UbicacionUsuario(
          latitud: 0.8116,
          longitud: -77.7172,
          precisionMetros: 10,
          capturadaEn: instanteBase,
        ),
      ),
    );
    final controller = MonitorProximidadController(
      ubicacionService: ubicacion,
      promocionesService: _PromocionesFalsas([]),
      notificaciones: _NotificacionesFalsas(),
      historial: _HistorialFalso(),
      preferencias: _PreferenciasFalsas(
        configuracion: const ConfiguracionAlertasProximidad(),
      ),
      usuarioId: () => 'cuenta-a',
      ahora: () => instanteBase,
    );
    controller.setRadarVisible(true);
    controller.setRadarActivo(true);
    await controller.iniciar();
    final inicial = ubicacion.solicitudes;
    expect(inicial, greaterThan(0));
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(ubicacion.solicitudes, greaterThan(inicial));
    controller.setRadarVisible(false);
    final fueraDelMapa = ubicacion.solicitudes;
    await tester.pump(const Duration(minutes: 6));
    await tester.pump();
    expect(ubicacion.solicitudes, fueraDelMapa);
    controller.setRadarVisible(true);
    await controller.iniciar();
    controller.suspenderPorCicloDeVida();
    final bloqueado = ubicacion.solicitudes;
    await tester.pump(const Duration(minutes: 6));
    await tester.pump();
    expect(ubicacion.solicitudes, bloqueado);
    controller.dispose();
  });

  testWidgets(
    'panel de Mapa permite activar y detener Radar sin GPS fuera de Mapa',
    (tester) async {
      final ubicacion = _UbicacionFalsa(
        const ResultadoUbicacion(estado: EstadoUbicacion.permisoDenegado),
      );
      final controller = MonitorProximidadController(
        ubicacionService: ubicacion,
        promocionesService: _PromocionesFalsas([]),
        notificaciones: _NotificacionesFalsas(),
        historial: _HistorialFalso(),
        preferencias: _PreferenciasFalsas(),
        usuarioId: () => 'usuario-1',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RadarCerclyPanel(controller: controller)),
        ),
      );
      expect(find.text('Radar Cercly Sky'), findsOneWidget);
      expect(controller.radarActivo, isFalse);
      await tester.tap(find.byKey(const Key('radar-cercly-toggle')));
      await tester.pump();
      expect(controller.radarActivo, isTrue);
      expect(ubicacion.solicitudes, 0);
      await tester.tap(find.byKey(const Key('radar-cercly-toggle')));
      await tester.pump();
      expect(controller.radarActivo, isFalse);
      controller.dispose();
    },
  );
}
