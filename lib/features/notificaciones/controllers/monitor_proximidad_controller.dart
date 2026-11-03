import 'dart:async';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../../promociones/models/promocion_destacada_model.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../models/configuracion_alertas_proximidad.dart';
import '../services/control_notificaciones_promocion.dart';
import '../services/geofencing_experimental_service.dart';
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
    this.stagingQaEnabled = GeofencingExperimentalService.staging,
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
  final bool stagingQaEnabled;
  final Duration intervalo;
  final Duration edadMaximaUbicacion;
  final double precisionMaximaMetros;

  Timer? _temporizador;
  StreamSubscription<ConfiguracionAlertasProximidad>? _preferenciasSuscripcion;
  bool _consultando = false;
  bool _historialCargado = false;
  bool _disposed = false;
  String _ultimoResultadoDiagnostico = 'sin_evaluacion';
  static const _ultimaComprobacionKey =
      'cercly.alertas_proximidad.ultima_comprobacion_ms.v1';

  String get ultimoResultadoDiagnostico => _ultimoResultadoDiagnostico;

  Future<DateTime?> cargarUltimaComprobacion() async {
    try {
      final milisegundos = await SharedPreferencesAsync().getInt(
        _ultimaComprobacionKey,
      );
      return milisegundos == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(milisegundos, isUtc: true);
    } catch (_) {
      return null;
    }
  }

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
      await _asegurarHistorialCargado();
      await verificarAhora();
      if (_requierePermisosAntesDeProgramar(_ultimoResultadoDiagnostico)) {
        return;
      }
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
      final servicioNotificaciones = _notificaciones;
      if (servicioNotificaciones is DiagnosticoPermisoNotificaciones) {
        final estado =
            await (servicioNotificaciones as DiagnosticoPermisoNotificaciones)
                .consultarEstadoDetallado();
        if (estado != EstadoPermisoNotificaciones.concedido) {
          _ultimoResultadoDiagnostico = switch (estado) {
            EstadoPermisoNotificaciones.denegado ||
            EstadoPermisoNotificaciones.desactivadoEnAjustes =>
              'permiso_notificaciones_pendiente',
            EstadoPermisoNotificaciones.noDisponible =>
              'permiso_notificaciones_indeterminado',
            EstadoPermisoNotificaciones.errorTecnico =>
              'error_permiso_notificaciones',
            EstadoPermisoNotificaciones.concedido => 'sin_evaluacion',
          };
          return;
        }
      } else if (!await _notificaciones.tienePermisoParaNotificar()) {
        _ultimoResultadoDiagnostico = 'permiso_notificaciones_pendiente';
        return;
      }
      if (servicioNotificaciones is DiagnosticoCanalNotificaciones) {
        final disponible =
            await (servicioNotificaciones as DiagnosticoCanalNotificaciones)
                .canalPromocionesDisponible();
        if (disponible == false) {
          _ultimoResultadoDiagnostico = 'canal_notificaciones_bloqueado';
          return;
        }
      }
      await _asegurarHistorialCargado();

      final resultado = await _ubicacionService.obtenerUbicacion();
      if (resultado.estado != EstadoUbicacion.disponible) {
        _ultimoResultadoDiagnostico = switch (resultado.estado) {
          EstadoUbicacion.servicioDesactivado =>
            'ubicacion_servicio_desactivado',
          EstadoUbicacion.permisoDenegado => 'permiso_ubicacion_pendiente',
          EstadoUbicacion.permisoDenegadoPermanentemente =>
            'permiso_ubicacion_revocado',
          _ => 'error_ubicacion',
        };
        return;
      }
      if (resultado.ubicacion == null ||
          !_ubicacionEsSuficientementePrecisa(resultado.ubicacion!)) {
        _ultimoResultadoDiagnostico = 'ubicacion_imprecisa_o_desactualizada';
        return;
      }

      final ubicacion = resultado.ubicacion!;
      late final List<PromocionDestacadaModel> promociones;
      final servicioPromociones = _promocionesService;
      if (servicioPromociones is PromocionesCercanasDiagnosticoRepository) {
        final diagnostico =
            await (servicioPromociones
                    as PromocionesCercanasDiagnosticoRepository)
                .diagnosticarCercanas(
                  latitudUsuario: ubicacion.latitud,
                  longitudUsuario: ubicacion.longitud,
                  radioUsuarioMetros: configuracion.radioMetros,
                );
        promociones = diagnostico.promocionesEnRadio;
        if (diagnostico.promocionesVigentes == 0) {
          _ultimoResultadoDiagnostico = 'sin_promociones_vigentes';
        } else if (promociones.isEmpty) {
          _ultimoResultadoDiagnostico = 'sin_promociones_en_radio';
        }
      } else {
        promociones = await _promocionesService.listarCercanas(
          latitudUsuario: ubicacion.latitud,
          longitudUsuario: ubicacion.longitud,
          radioUsuarioMetros: configuracion.radioMetros,
        );
        if (promociones.isEmpty) {
          _ultimoResultadoDiagnostico = 'sin_promociones_elegibles';
        }
      }
      final dentroAntes = _control.promocionesDentro;
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
    } catch (error, stackTrace) {
      // Una falla de red, ubicación o sistema de notificaciones no bloquea la app.
      _ultimoResultadoDiagnostico = 'error_evaluacion';
      developer.log(
        'Proximidad: evaluación fallida (tipo=${error.runtimeType}).',
        name: 'cercly.proximity',
        stackTrace: stackTrace,
      );
    } finally {
      try {
        await SharedPreferencesAsync().setInt(
          _ultimaComprobacionKey,
          _ahora().toUtc().millisecondsSinceEpoch,
        );
      } catch (_) {
        // Es un dato informativo; su fallo no afecta el envío ni el estado.
      }
      _consultando = false;
    }
  }

  Future<void> reiniciarHistorialLocalDiagnostico() async {
    if (_consultando) return;
    final historial = _historial;
    if (historial is! BorradoHistorialLocalNotificaciones) {
      throw StateError('El historial no admite restablecimiento local.');
    }
    if (stagingQaEnabled &&
        !await GeofencingExperimentalService().resetQaCooldown()) {
      throw StateError('No se reinició el cooldown nativo de Staging.');
    }
    await (historial as BorradoHistorialLocalNotificaciones)
        .borrarDatosLocales();
    _control.cargarHistorial(const HistorialNotificacionesPromocionDatos());
    _historialCargado = true;
    _ultimoResultadoDiagnostico = 'historial_local_reiniciado';
  }

  Future<String> simularEntradaUpec() async {
    if (!GeofencingExperimentalService.staging || !stagingQaEnabled) {
      return 'simulacion_no_disponible';
    }
    if (_consultando) return 'evaluacion_en_curso';
    _consultando = true;
    try {
      final configuracion = await _preferencias.cargar();
      if (!configuracion.activadas) {
        return _ultimoResultadoDiagnostico = 'simulacion_sin_consentimiento';
      }
      final permisoUbicacion = await _ubicacionService.consultarEstadoPermiso(
        solicitarPermiso: false,
      );
      if (permisoUbicacion != EstadoUbicacion.disponible) {
        return _ultimoResultadoDiagnostico =
            'simulacion_permiso_ubicacion_denegado';
      }

      final notificaciones = _notificaciones;
      if (notificaciones is DiagnosticoPermisoNotificaciones) {
        final estado =
            await (notificaciones as DiagnosticoPermisoNotificaciones)
                .consultarEstadoDetallado();
        if (estado != EstadoPermisoNotificaciones.concedido) {
          return _ultimoResultadoDiagnostico =
              'simulacion_permiso_notificaciones_denegado';
        }
      } else if (!await notificaciones.tienePermisoParaNotificar()) {
        return _ultimoResultadoDiagnostico =
            'simulacion_permiso_notificaciones_denegado';
      }
      if (notificaciones is DiagnosticoCanalNotificaciones &&
          await (notificaciones as DiagnosticoCanalNotificaciones)
                  .canalPromocionesDisponible() ==
              false) {
        return _ultimoResultadoDiagnostico =
            'simulacion_canal_notificaciones_bloqueado';
      }

      await _asegurarHistorialCargado();
      final candidatas = await _promocionesService.listarCercanas(
        latitudUsuario: 0.80525,
        longitudUsuario: -77.73434,
        radioUsuarioMetros: configuracion.radioMetros,
      );
      final ahora = _ahora();
      final elegibles = candidatas
          .where(
            (item) =>
                item.id == GeofencingExperimentalService.promotionId &&
                item.establecimientoId ==
                    GeofencingExperimentalService.establishmentId &&
                item.activa &&
                item.estaVigenteEn(ahora),
          )
          .toList(growable: false);
      if (elegibles.isEmpty) {
        return _ultimoResultadoDiagnostico = 'simulacion_sin_promocion_vigente';
      }
      final promocion = elegibles.first;

      final notificables = _control.evaluar(
        [promocion],
        ahora: ahora,
        radioUsuarioMetros: configuracion.radioMetros,
        conservarPromocionesDentro: true,
      );
      if (notificables.isEmpty) {
        return _ultimoResultadoDiagnostico =
            'simulacion_bloqueada_cooldown_o_radio';
      }
      if (notificaciones is! NotificacionPromocionSimulable) {
        return _ultimoResultadoDiagnostico =
            'simulacion_notificacion_no_disponible';
      }
      final mostrada = await (notificaciones as NotificacionPromocionSimulable)
          .mostrarPromocionSimulada(promocion);
      if (!mostrada) {
        return _ultimoResultadoDiagnostico =
            'simulacion_notificacion_bloqueada';
      }
      _control.registrarNotificacion(promocion.id, ahora: _ahora());
      await _historial.guardar(_control.crearHistorial());
      return _ultimoResultadoDiagnostico = 'simulacion_notificacion_enviada';
    } catch (_) {
      return _ultimoResultadoDiagnostico = 'simulacion_error_evaluacion';
    } finally {
      _consultando = false;
    }
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

  bool _requierePermisosAntesDeProgramar(String resultado) => const {
    'alertas_desactivadas',
    'permiso_ubicacion_pendiente',
    'permiso_ubicacion_revocado',
    'ubicacion_servicio_desactivado',
    'error_ubicacion',
    'permiso_notificaciones_pendiente',
    'permiso_notificaciones_indeterminado',
    'error_permiso_notificaciones',
    'canal_notificaciones_bloqueado',
    'ubicacion_imprecisa_o_desactualizada',
  }.contains(resultado);

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
