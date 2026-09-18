import 'dart:async';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../services/control_notificaciones_promocion.dart';
import '../services/historial_notificaciones_promocion.dart';
import '../services/notificacion_local_service.dart';

class MonitorProximidadController {
  MonitorProximidadController({
    UbicacionService? ubicacionService,
    PromocionesCercanasRepository? promocionesService,
    NotificacionPromocionGateway? notificaciones,
    ControlNotificacionesPromocion? control,
    HistorialNotificacionesPromocion? historial,
    this.intervalo = const Duration(minutes: 2),
    DateTime Function()? ahora,
  }) : _ubicacionService = ubicacionService ?? GeolocatorUbicacionService(),
       _promocionesService = promocionesService ?? PromocionPublicaService(),
       _notificaciones = notificaciones ?? NotificacionLocalService(),
       _control = control ?? ControlNotificacionesPromocion(),
       _historial =
           historial ?? HistorialNotificacionesPromocionLocal(),
       _ahora = ahora ?? DateTime.now;

  final UbicacionService _ubicacionService;
  final PromocionesCercanasRepository _promocionesService;
  final NotificacionPromocionGateway _notificaciones;
  final ControlNotificacionesPromocion _control;
  final HistorialNotificacionesPromocion _historial;
  final DateTime Function() _ahora;
  final Duration intervalo;

  Timer? _temporizador;
  bool _consultando = false;
  bool _historialCargado = false;
  bool _disposed = false;

  Future<void> iniciar() async {
    if (_disposed || _temporizador != null) return;
    try {
      await _notificaciones.inicializar();
      await _asegurarHistorialCargado();
    } catch (_) {
      return;
    }
    await verificarAhora();
    if (_disposed) return;
    _temporizador = Timer.periodic(
      intervalo,
      (_) => unawaited(verificarAhora()),
    );
  }

  Future<void> verificarAhora() async {
    if (_disposed || _consultando) return;
    _consultando = true;

    try {
      await _asegurarHistorialCargado();

      final resultado = await _ubicacionService.obtenerUbicacion();
      if (resultado.estado != EstadoUbicacion.disponible ||
          resultado.ubicacion == null) {
        return;
      }

      final ubicacion = resultado.ubicacion!;
      final promociones = await _promocionesService.listarCercanas(
        latitudUsuario: ubicacion.latitud,
        longitudUsuario: ubicacion.longitud,
      );
      final ahora = _ahora();
      final notificables = _control.evaluar(promociones, ahora: ahora);

      for (final promocion in notificables) {
        final mostrada = await _notificaciones.mostrarPromocion(promocion);
        if (!mostrada) {
          continue;
        }

        _control.registrarNotificacion(promocion.id, ahora: ahora);
        await _guardarHistorial();
      }
    } catch (_) {
      // La comprobación de proximidad no debe interrumpir la experiencia pública.
    } finally {
      _consultando = false;
    }
  }

  Future<void> _asegurarHistorialCargado() async {
    if (_historialCargado) {
      return;
    }

    try {
      final historial = await _historial.cargar();
      _control.cargarHistorial(historial);
    } finally {
      _historialCargado = true;
    }
  }

  Future<void> _guardarHistorial() async {
    try {
      await _historial.guardar(_control.historialUltimasNotificaciones);
    } catch (_) {
      // Un fallo al persistir no debe impedir mostrar promociones cercanas.
    }
  }

  void pausar() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  Future<void> reanudar() async {
    if (_disposed) return;
    pausar();
    await iniciar();
  }

  void dispose() {
    _disposed = true;
    pausar();
  }
}
