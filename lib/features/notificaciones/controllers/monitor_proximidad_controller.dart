import 'dart:async';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../services/control_notificaciones_promocion.dart';
import '../services/notificacion_local_service.dart';

class MonitorProximidadController {
  MonitorProximidadController({
    UbicacionService? ubicacionService,
    PromocionesCercanasRepository? promocionesService,
    NotificacionPromocionGateway? notificaciones,
    ControlNotificacionesPromocion? control,
    this.intervalo = const Duration(minutes: 2),
    DateTime Function()? ahora,
  }) : _ubicacionService = ubicacionService ?? GeolocatorUbicacionService(),
       _promocionesService = promocionesService ?? PromocionPublicaService(),
       _notificaciones = notificaciones ?? NotificacionLocalService(),
       _control = control ?? ControlNotificacionesPromocion(),
       _ahora = ahora ?? DateTime.now;

  final UbicacionService _ubicacionService;
  final PromocionesCercanasRepository _promocionesService;
  final NotificacionPromocionGateway _notificaciones;
  final ControlNotificacionesPromocion _control;
  final DateTime Function() _ahora;
  final Duration intervalo;

  Timer? _temporizador;
  bool _consultando = false;
  bool _disposed = false;

  Future<void> iniciar() async {
    if (_disposed || _temporizador != null) return;
    try {
      await _notificaciones.inicializar();
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
      final notificables = _control.evaluar(promociones, ahora: _ahora());

      for (final promocion in notificables) {
        await _notificaciones.mostrarPromocion(promocion);
      }
    } catch (_) {
      // La comprobación de proximidad no debe interrumpir la experiencia pública.
    } finally {
      _consultando = false;
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
