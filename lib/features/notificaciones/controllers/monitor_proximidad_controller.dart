import 'dart:async';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../models/configuracion_alertas_proximidad.dart';
import '../services/control_notificaciones_promocion.dart';
import '../services/historial_notificaciones_promocion.dart';
import '../services/notificacion_local_service.dart';
import '../services/preferencias_alertas_proximidad.dart';

class MonitorProximidadController {
  MonitorProximidadController({
    UbicacionService? ubicacionService,
    PromocionesCercanasRepository? promocionesService,
    NotificacionPromocionGateway? notificaciones,
    ControlNotificacionesPromocion? control,
    HistorialNotificacionesPromocion? historial,
    PreferenciasAlertasProximidadRepository? preferencias,
    Future<void> Function(String establecimientoId)? alAbrirEstablecimiento,
    this.intervalo = const Duration(minutes: 5),
    this.precisionMaximaMetros = 100,
    this.edadMaximaUbicacion = const Duration(minutes: 2),
    DateTime Function()? ahora,
  }) : _ubicacionService = ubicacionService ?? GeolocatorUbicacionService(),
       _promocionesService = promocionesService ?? PromocionPublicaService(),
       _notificaciones =
           notificaciones ??
           NotificacionLocalService(
             alAbrirEstablecimiento: alAbrirEstablecimiento,
           ),
       _control = control ?? ControlNotificacionesPromocion(),
       _historial = historial ?? HistorialNotificacionesPromocionLocal(),
       _preferencias = preferencias ?? PreferenciasAlertasProximidadLocal(),
       _ahora = ahora ?? DateTime.now;

  final UbicacionService _ubicacionService;
  final PromocionesCercanasRepository _promocionesService;
  final NotificacionPromocionGateway _notificaciones;
  final ControlNotificacionesPromocion _control;
  final HistorialNotificacionesPromocion _historial;
  final PreferenciasAlertasProximidadRepository _preferencias;
  final DateTime Function() _ahora;
  final Duration intervalo;
  final Duration edadMaximaUbicacion;
  final double precisionMaximaMetros;

  Timer? _temporizador;
  StreamSubscription<ConfiguracionAlertasProximidad>? _preferenciasSuscripcion;
  bool _consultando = false;
  bool _historialCargado = false;
  bool _disposed = false;
  String _ultimoResultadoDiagnostico = 'sin_evaluacion';

  String get ultimoResultadoDiagnostico => _ultimoResultadoDiagnostico;

  Future<EstadoPermisoNotificaciones> consultarPermisoNotificaciones() async {
    final servicio = _notificaciones;
    if (servicio is DiagnosticoPermisoNotificaciones) {
      return (servicio as DiagnosticoPermisoNotificaciones)
          .consultarEstadoDetallado();
    }
    try {
      return await servicio.tienePermisoParaNotificar()
          ? EstadoPermisoNotificaciones.concedido
          : EstadoPermisoNotificaciones.desactivadoEnAjustes;
    } catch (_) {
      return EstadoPermisoNotificaciones.errorTecnico;
    }
  }

  Future<void> iniciar() async {
    if (_disposed) return;
    _preferenciasSuscripcion ??= _preferencias.cambios.listen((configuracion) {
      if (configuracion.activadas) {
        unawaited(iniciar());
      } else {
        pausar();
      }
    });

    if (_temporizador != null) return;

    try {
      // Inicializar callbacks incluso con alertas apagadas permite abrir una
      // notificación ya publicada; no solicita permisos ni lee ubicación.
      await _notificaciones.inicializar();
      final configuracion = await _preferencias.cargar();
      if (!configuracion.activadas) return;
      if (await _ubicacionService.consultarEstadoPermiso() !=
          EstadoUbicacion.disponible) {
        return;
      }
      if (!await _notificaciones.tienePermisoParaNotificar()) return;
      await _asegurarHistorialCargado();
      await verificarAhora();
    } catch (_) {
      return;
    }

    if (_disposed || _temporizador != null) return;
    _temporizador = Timer.periodic(
      intervalo,
      (_) => unawaited(verificarAhora()),
    );
  }

  Future<void> verificarAhora() async {
    if (_disposed) return;
    if (_consultando) {
      _ultimoResultadoDiagnostico = 'evaluacion_en_curso';
      return;
    }
    _consultando = true;

    try {
      final configuracion = await _preferencias.cargar();
      if (!configuracion.activadas) {
        _ultimoResultadoDiagnostico = 'alertas_desactivadas';
        return;
      }
      if (await _ubicacionService.consultarEstadoPermiso() !=
          EstadoUbicacion.disponible) {
        _ultimoResultadoDiagnostico = 'permiso_ubicacion_pendiente';
        return;
      }
      if (!await _notificaciones.tienePermisoParaNotificar()) {
        _ultimoResultadoDiagnostico = 'permiso_notificaciones_pendiente';
        return;
      }
      await _asegurarHistorialCargado();

      final resultado = await _ubicacionService.obtenerUbicacion();
      if (resultado.estado != EstadoUbicacion.disponible ||
          resultado.ubicacion == null ||
          !_ubicacionEsSuficientementePrecisa(resultado.ubicacion!)) {
        _ultimoResultadoDiagnostico = 'ubicacion_imprecisa_o_desactualizada';
        return;
      }

      final ubicacion = resultado.ubicacion!;
      final promociones = await _promocionesService.listarCercanas(
        latitudUsuario: ubicacion.latitud,
        longitudUsuario: ubicacion.longitud,
        radioUsuarioMetros: configuracion.radioMetros,
      );
      final dentroAntes = _control.promocionesDentro;
      if (promociones.isEmpty) {
        _ultimoResultadoDiagnostico = 'sin_promociones_elegibles';
      }
      final notificables = _control.evaluar(
        promociones,
        ahora: _ahora(),
        radioUsuarioMetros: configuracion.radioMetros,
      );
      var huboCambios = !_mismosElementos(
        dentroAntes,
        _control.promocionesDentro,
      );

      for (final promocion in notificables) {
        final mostrada = await _notificaciones.mostrarPromocion(promocion);
        if (!mostrada) {
          _ultimoResultadoDiagnostico = 'notificacion_bloqueada';
          continue;
        }
        _control.registrarNotificacion(promocion.id, ahora: _ahora());
        _ultimoResultadoDiagnostico = 'notificacion_enviada';
        huboCambios = true;
      }

      if (promociones.isNotEmpty && notificables.isEmpty) {
        _ultimoResultadoDiagnostico = 'cooldown_limite_o_misma_zona';
      }

      if (huboCambios) {
        await _historial.guardar(_control.crearHistorial());
      }
    } catch (_) {
      // Una falla de red, ubicación o sistema de notificaciones no bloquea la app.
      _ultimoResultadoDiagnostico = 'error_evaluacion';
    } finally {
      _consultando = false;
    }
  }

  Future<void> reiniciarHistorialLocalDiagnostico() async {
    if (_consultando) return;
    final historial = _historial;
    if (historial is! BorradoHistorialLocalNotificaciones) {
      throw StateError('El historial no admite restablecimiento local.');
    }
    await (historial as BorradoHistorialLocalNotificaciones)
        .borrarDatosLocales();
    _control.cargarHistorial(const HistorialNotificacionesPromocionDatos());
    _historialCargado = true;
    _ultimoResultadoDiagnostico = 'historial_local_reiniciado';
  }

  bool _ubicacionEsSuficientementePrecisa(UbicacionUsuario ubicacion) {
    final precision = ubicacion.precisionMetros;
    final capturadaEn = ubicacion.capturadaEn;
    if (!ubicacion.latitud.isFinite ||
        !ubicacion.longitud.isFinite ||
        ubicacion.latitud < -90 ||
        ubicacion.latitud > 90 ||
        ubicacion.longitud < -180 ||
        ubicacion.longitud > 180 ||
        precision == null ||
        !precision.isFinite ||
        precision <= 0 ||
        precision > precisionMaximaMetros ||
        capturadaEn == null) {
      return false;
    }
    final antiguedad = _ahora().difference(capturadaEn);
    return !antiguedad.isNegative && antiguedad <= edadMaximaUbicacion;
  }

  bool _mismosElementos(Set<String> primero, Set<String> segundo) {
    if (primero.length != segundo.length) return false;
    return primero.containsAll(segundo);
  }

  Future<void> _asegurarHistorialCargado() async {
    if (_historialCargado) return;
    try {
      _control.cargarHistorial(await _historial.cargar());
    } catch (_) {
      // Si el almacenamiento local falla, el monitor continúa en memoria.
    } finally {
      _historialCargado = true;
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
    unawaited(_preferenciasSuscripcion?.cancel());
  }
}
