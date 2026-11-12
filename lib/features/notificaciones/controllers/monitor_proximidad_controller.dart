import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class MonitorProximidadController extends ChangeNotifier {
  MonitorProximidadController({
    UbicacionService? ubicacionService,
    PromocionesCercanasRepository? promocionesService,
    NotificacionPromocionGateway? notificaciones,
    ControlNotificacionesPromocion? control,
    HistorialNotificacionesPromocion? historial,
    PreferenciasAlertasProximidadRepository? preferencias,
    Future<void> Function(String establecimientoId)? alAbrirEstablecimiento,
    this.intervalo = const Duration(minutes: 3),
    this.precisionMaximaMetros = 100,
    this.edadMaximaUbicacion = const Duration(minutes: 2),
    DateTime Function()? ahora,
    String? Function()? usuarioId,
    this.stagingQaEnabled = GeofencingExperimentalService.staging,
  }) : _ubicacionService = ubicacionService ?? GeolocatorUbicacionService(),
       _promocionesService = promocionesService ?? PromocionPublicaService(),
       _notificaciones =
           notificaciones ??
           NotificacionLocalService(
             alAbrirEstablecimiento: alAbrirEstablecimiento,
           ),
       _control = control ?? ControlNotificacionesPromocion(),
       _historial =
           historial ??
           HistorialNotificacionesPromocionLocal(
             usuarioId: usuarioId ?? _usuarioActual,
           ),
       _preferencias = preferencias ?? PreferenciasAlertasProximidadLocal(),
       _ahora = ahora ?? DateTime.now,
       _usuarioId = usuarioId ?? _usuarioActual;

  static String? _usuarioActual() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  final UbicacionService _ubicacionService;
  final PromocionesCercanasRepository _promocionesService;
  final NotificacionPromocionGateway _notificaciones;
  final ControlNotificacionesPromocion _control;
  final HistorialNotificacionesPromocion _historial;
  final PreferenciasAlertasProximidadRepository _preferencias;
  final DateTime Function() _ahora;
  final String? Function() _usuarioId;
  final bool stagingQaEnabled;
  final Duration intervalo;
  final Duration edadMaximaUbicacion;
  final double precisionMaximaMetros;

  Timer? _temporizador;
  Future<void>? _inicioPendiente;
  StreamSubscription<ConfiguracionAlertasProximidad>? _preferenciasSuscripcion;
  bool _consultando = false;
  bool _historialCargado = false;
  bool _disposed = false;
  bool _radarActivo = false;
  bool _radarVisible = false;
  bool _appEnPrimerPlano = true;
  int _generacionRadar = 0;
  String? _usuarioCargado;
  List<PromocionDestacadaModel> _promocionesRadar = const [];
  bool _cargandoRadar = false;
  String _ultimoResultadoDiagnostico = 'sin_evaluacion';
  static const _ultimaComprobacionKey =
      'cercly.alertas_proximidad.ultima_comprobacion_ms.v1';

  String get ultimoResultadoDiagnostico => _ultimoResultadoDiagnostico;
  bool get radarActivo => _radarActivo;
  bool get cargandoRadar => _cargandoRadar;
  List<PromocionDestacadaModel> get promocionesRadar => _promocionesRadar;

  void _publicarEstado() {
    if (!_disposed) notifyListeners();
  }

  void setRadarVisible(bool visible) {
    if (_disposed || _radarVisible == visible) return;
    _radarVisible = visible;
    _generacionRadar++;
    if (visible && _radarActivo && _appEnPrimerPlano) {
      unawaited(iniciar());
    } else if (!visible) {
      pausar();
    }
  }

  void setRadarActivo(bool activo) {
    if (_disposed || _radarActivo == activo) return;
    _radarActivo = activo;
    _generacionRadar++;
    if (activo && _radarVisible && _appEnPrimerPlano) {
      unawaited(iniciar());
    } else if (!activo) {
      pausar();
      _promocionesRadar = const [];
    }
    _publicarEstado();
  }

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

  Future<void> iniciar() {
    if (_disposed) return Future.value();
    return _inicioPendiente ??= _iniciarInterno().whenComplete(() {
      _inicioPendiente = null;
    });
  }

  Future<void> _iniciarInterno() async {
    if (_disposed) return;
    _preferenciasSuscripcion ??= _preferencias.cambios.listen((configuracion) {
      if (_radarActivo && _radarVisible && _appEnPrimerPlano) {
        unawaited(iniciar());
      }
    });

    if (_temporizador != null) return;

    // Inicializar callbacks incluso con alertas apagadas permite abrir una
    // notificación ya publicada; un fallo no bloquea el listado del Radar.
    try {
      await _notificaciones.inicializar();
    } catch (_) {
      // La vista del Radar sigue disponible sin el canal de notificaciones.
    }
    try {
      if (!_radarActivo || !_radarVisible || !_appEnPrimerPlano) return;
      await verificarAhora(mostrarEnRadar: true);
    } catch (_) {
      return;
    }

    if (_disposed ||
        _temporizador != null ||
        !_radarActivo ||
        !_radarVisible ||
        !_appEnPrimerPlano) {
      return;
    }
    _temporizador = Timer.periodic(
      intervalo,
      (_) => unawaited(verificarAhora(mostrarEnRadar: true)),
    );
  }

  Future<void> verificarAhora({bool mostrarEnRadar = false}) async {
    if (_disposed) return;
    if (_consultando) {
      _ultimoResultadoDiagnostico = 'evaluacion_en_curso';
      return;
    }
    _consultando = true;
    final generacion = _generacionRadar;

    try {
      final configuracion = await _preferencias.cargar();
      if (!configuracion.activadas && !mostrarEnRadar) {
        _ultimoResultadoDiagnostico = 'alertas_desactivadas';
        return;
      }
      if (mostrarEnRadar &&
          (!_radarActivo ||
              !_radarVisible ||
              !_appEnPrimerPlano ||
              generacion != _generacionRadar)) {
        return;
      }
      if (mostrarEnRadar) {
        _cargandoRadar = true;
        _promocionesRadar = const [];
        _publicarEstado();
      }
      final usuarioAlInicio = _usuarioId();
      final servicioNotificaciones = _notificaciones;
      if (!mostrarEnRadar &&
          servicioNotificaciones is DiagnosticoPermisoNotificaciones) {
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
      } else if (!mostrarEnRadar &&
          !await _notificaciones.tienePermisoParaNotificar()) {
        _ultimoResultadoDiagnostico = 'permiso_notificaciones_pendiente';
        return;
      }
      if (!mostrarEnRadar &&
          servicioNotificaciones is DiagnosticoCanalNotificaciones) {
        final disponible =
            await (servicioNotificaciones as DiagnosticoCanalNotificaciones)
                .canalPromocionesDisponible();
        if (disponible == false) {
          _ultimoResultadoDiagnostico = 'canal_notificaciones_bloqueado';
          return;
        }
      }
      if (configuracion.activadas) await _asegurarHistorialCargado();

      final resultado = await _ubicacionService.obtenerUbicacion();
      if (resultado.estado != EstadoUbicacion.disponible) {
        if (mostrarEnRadar) {
          _promocionesRadar = const [];
          _publicarEstado();
        }
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
        _promocionesRadar = const [];
        _publicarEstado();
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
      if (mostrarEnRadar &&
          (_disposed ||
              !_radarActivo ||
              !_radarVisible ||
              !_appEnPrimerPlano ||
              generacion != _generacionRadar ||
              usuarioAlInicio != _usuarioId())) {
        return;
      }
      if (mostrarEnRadar) {
        final ahora = _ahora();
        _promocionesRadar =
            promociones.where((item) {
              final distancia = item.distanciaMetros;
              return item.activa &&
                  item.estaVigenteEn(ahora) &&
                  distancia != null &&
                  distancia.isFinite &&
                  distancia >= 0 &&
                  distancia + ubicacion.precisionMetros! <=
                      configuracion.radioMetros &&
                  distancia + ubicacion.precisionMetros! <=
                      item.radioAlertaMetros;
            }).toList()..sort((a, b) {
              final orden = a.distanciaMetros!.compareTo(b.distanciaMetros!);
              return orden != 0 ? orden : a.id.compareTo(b.id);
            });
        _publicarEstado();
      }
      if (!configuracion.activadas) return;
      final politica = await _preferencias.cargar();
      if (!politica.activadas) {
        _ultimoResultadoDiagnostico = 'alertas_desactivadas_o_permiso_revocado';
        return;
      }
      if (mostrarEnRadar &&
          (usuarioAlInicio == null ||
              usuarioAlInicio != _usuarioId() ||
              !_radarActivo ||
              !_radarVisible ||
              !_appEnPrimerPlano ||
              generacion != _generacionRadar)) {
        return;
      }
      if (mostrarEnRadar &&
          !await _notificaciones.tienePermisoParaNotificar()) {
        _ultimoResultadoDiagnostico = 'permiso_notificaciones_pendiente';
        return;
      }
      final dentroAntes = _control.promocionesDentro;
      final notificables = _control.evaluar(
        promociones,
        ahora: _ahora(),
        radioUsuarioMetros: politica.radioMetros < configuracion.radioMetros
            ? politica.radioMetros
            : configuracion.radioMetros,
        precisionUbicacionMetros: ubicacion.precisionMetros!,
        maximoPorDia: politica.frecuencia.maximoPorDia,
        horarioDescanso: politica.horarioDescanso,
      );
      var huboCambios = !_mismosElementos(
        dentroAntes,
        _control.promocionesDentro,
      );

      for (final promocion in notificables) {
        if (mostrarEnRadar &&
            (usuarioAlInicio != _usuarioId() ||
                !_radarActivo ||
                !_radarVisible ||
                !_appEnPrimerPlano ||
                generacion != _generacionRadar)) {
          return;
        }
        // Una persona puede revocar consentimiento o permiso mientras se
        // consulta el backend. Verificar justo antes de publicar el aviso.
        final vigente = await _preferencias.cargar();
        if (!vigente.activadas ||
            vigente.horarioDescanso?.contiene(_ahora()) == true ||
            _control.notificacionesRecientes.length >=
                vigente.frecuencia.maximoPorDia ||
            !await _notificaciones.tienePermisoParaNotificar()) {
          _ultimoResultadoDiagnostico =
              'alertas_desactivadas_o_permiso_revocado';
          return;
        }
        final mostrada = await _notificaciones.mostrarPromocion(promocion);
        if (!mostrada) {
          _ultimoResultadoDiagnostico = 'notificacion_bloqueada';
          continue;
        }
        _control.registrarNotificacion(
          promocion.id,
          establecimientoId: promocion.establecimientoId,
          ahora: _ahora(),
        );
        _ultimoResultadoDiagnostico = 'notificacion_enviada';
        huboCambios = true;
      }

      if (promociones.isNotEmpty && notificables.isEmpty) {
        _ultimoResultadoDiagnostico =
            politica.horarioDescanso?.contiene(_ahora()) == true
            ? 'horario_descanso'
            : 'cooldown_limite_o_misma_zona';
      }

      if (huboCambios) {
        await _guardarHistorial(usuarioAlInicio);
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
      if (_cargandoRadar) {
        _cargandoRadar = false;
        _publicarEstado();
      }
      if (mostrarEnRadar &&
          generacion != _generacionRadar &&
          !_disposed &&
          _radarActivo &&
          _radarVisible &&
          _appEnPrimerPlano) {
        unawaited(verificarAhora(mostrarEnRadar: true));
      }
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
        maximoPorDia: configuracion.frecuencia.maximoPorDia,
        horarioDescanso: configuracion.horarioDescanso,
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
      _control.registrarNotificacion(
        promocion.id,
        establecimientoId: promocion.establecimientoId,
        ahora: _ahora(),
      );
      await _guardarHistorial(_usuarioId());
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

  Future<void> _asegurarHistorialCargado() async {
    final actual = _usuarioId();
    if (_usuarioCargado != actual) {
      _control.cargarHistorial(const HistorialNotificacionesPromocionDatos());
      _historialCargado = false;
      _usuarioCargado = actual;
    }
    if (_historialCargado) return;
    try {
      final historial = _historial;
      _control.cargarHistorial(
        historial is HistorialNotificacionesPromocionLocal
            ? await historial.cargarDe(actual)
            : await historial.cargar(),
      );
    } catch (_) {
      // Si el almacenamiento local falla, el monitor continúa en memoria.
    } finally {
      _historialCargado = true;
    }
  }

  Future<void> _guardarHistorial(String? usuario) async {
    final historial = _historial;
    final datos = _control.crearHistorial();
    if (historial is HistorialNotificacionesPromocionLocal) {
      await historial.guardarDe(datos, usuario);
    } else {
      await historial.guardar(datos);
    }
  }

  void pausar() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  Future<void> reanudar() async {
    if (_disposed) return;
    _appEnPrimerPlano = true;
    _generacionRadar++;
    pausar();
    await iniciar();
  }

  void suspenderPorCicloDeVida() {
    _appEnPrimerPlano = false;
    _generacionRadar++;
    pausar();
  }

  @override
  void dispose() {
    _disposed = true;
    pausar();
    unawaited(_preferenciasSuscripcion?.cancel());
    super.dispose();
  }
}
