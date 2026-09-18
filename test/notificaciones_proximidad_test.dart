import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/services/ubicacion_service.dart';
import 'package:cercly/features/notificaciones/controllers/monitor_proximidad_controller.dart';
import 'package:cercly/features/notificaciones/services/control_notificaciones_promocion.dart';
import 'package:cercly/features/notificaciones/services/historial_notificaciones_promocion.dart';
import 'package:cercly/features/notificaciones/services/notificacion_local_service.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/services/promocion_publica_service.dart';
import 'package:flutter_test/flutter_test.dart';

final instanteBase = DateTime(2026, 9, 14, 12);

PromocionDestacadaModel promocion({
  String id = 'promo-1',
  bool activa = true,
  double distancia = 50,
  int radio = 100,
  DateTime? inicio,
  DateTime? fin,
}) {
  return PromocionDestacadaModel(
    id: id,
    establecimientoId: 'establecimiento-1',
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

  @override
  Future<bool> abrirAjustesAplicacion() async => true;

  @override
  Future<bool> abrirAjustesUbicacion() async => true;

  @override
  Future<ResultadoUbicacion> obtenerUbicacion() async => resultado;
}

class _PromocionesFalsas implements PromocionesCercanasRepository {
  _PromocionesFalsas(this.promociones);

  final List<PromocionDestacadaModel> promociones;
  int consultas = 0;

  @override
  Future<List<PromocionDestacadaModel>> listarCercanas({
    required double latitudUsuario,
    required double longitudUsuario,
  }) async {
    consultas++;
    return promociones;
  }
}

class _NotificacionesFalsas implements NotificacionPromocionGateway {
  _NotificacionesFalsas({this.permitir = true});

  final bool permitir;
  final mostradas = <PromocionDestacadaModel>[];

  @override
  Future<void> inicializar() async {}

  @override
  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion) async {
    if (!permitir) {
      return false;
    }

    mostradas.add(promocion);
    return true;
  }
}

class _HistorialFalso implements HistorialNotificacionesPromocion {
  _HistorialFalso([Map<String, DateTime>? inicial])
    : _datos = Map<String, DateTime>.from(inicial ?? const {});

  Map<String, DateTime> _datos;
  int guardados = 0;

  Map<String, DateTime> get datos => Map.unmodifiable(_datos);

  @override
  Future<Map<String, DateTime>> cargar() async {
    return Map<String, DateTime>.from(_datos);
  }

  @override
  Future<void> guardar(Map<String, DateTime> historial) async {
    guardados++;
    _datos = Map<String, DateTime>.from(historial);
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

    test('varias promociones cercanas se evalúan independientemente', () {
      final resultado = control.evaluar([
        promocion(),
        promocion(id: 'promo-2'),
      ], ahora: instanteBase);

      expect(resultado, hasLength(2));
    });

    test('historial previo mantiene el cooldown tras reiniciar', () {
      final nuevoControl = ControlNotificacionesPromocion(
        cooldown: const Duration(hours: 2),
      );
      nuevoControl.cargarHistorial({'promo-1': instanteBase});

      final resultado = nuevoControl.evaluar(
        [promocion()],
        ahora: instanteBase.add(const Duration(minutes: 30)),
      );

      expect(resultado, isEmpty);
    });
  });

  group('MonitorProximidadController', () {
    test('consulta ubicación, promociones y envía notificables', () async {
      final promociones = _PromocionesFalsas([promocion()]);
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(latitud: 0.8116, longitud: -77.7172),
          ),
        ),
        promocionesService: promociones,
        notificaciones: notificaciones,
        control: ControlNotificacionesPromocion(),
        historial: _HistorialFalso(),
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(promociones.consultas, 1);
      expect(notificaciones.mostradas, hasLength(1));
    });

    test('permiso de ubicación denegado no consulta promociones', () async {
      final promociones = _PromocionesFalsas([promocion()]);
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(
            estado: EstadoUbicacion.permisoDenegado,
          ),
        ),
        promocionesService: promociones,
        notificaciones: notificaciones,
        control: ControlNotificacionesPromocion(),
        historial: _HistorialFalso(),
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
          const ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(latitud: 0.8116, longitud: -77.7172),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: _NotificacionesFalsas(),
        control: ControlNotificacionesPromocion(),
        historial: historial,
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
          const ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(latitud: 0.8116, longitud: -77.7172),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: _NotificacionesFalsas(permitir: false),
        control: ControlNotificacionesPromocion(),
        historial: historial,
        ahora: () => instanteBase,
      );

      await controller.verificarAhora();

      expect(historial.guardados, 0);
      expect(historial.datos, isEmpty);
    });

    test('historial cargado evita repetir después de reiniciar', () async {
      final historial = _HistorialFalso({'promo-1': instanteBase});
      final notificaciones = _NotificacionesFalsas();
      final controller = MonitorProximidadController(
        ubicacionService: _UbicacionFalsa(
          const ResultadoUbicacion(
            estado: EstadoUbicacion.disponible,
            ubicacion: UbicacionUsuario(latitud: 0.8116, longitud: -77.7172),
          ),
        ),
        promocionesService: _PromocionesFalsas([promocion()]),
        notificaciones: notificaciones,
        control: ControlNotificacionesPromocion(
          cooldown: const Duration(hours: 2),
        ),
        historial: historial,
        ahora: () => instanteBase.add(const Duration(minutes: 30)),
      );

      await controller.verificarAhora();

      expect(notificaciones.mostradas, isEmpty);
      expect(historial.guardados, 0);
    });
  });
}
