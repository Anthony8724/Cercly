import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../promociones/models/promocion_destacada_model.dart';
import 'geofencing_experimental_service.dart';
import 'production_geofencing_service.dart';

abstract interface class NotificacionPromocionGateway {
  Future<void> inicializar();

  Future<bool> tienePermisoParaNotificar();

  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion);
}

abstract interface class NotificacionPromocionSimulable {
  Future<bool> mostrarPromocionSimulada(PromocionDestacadaModel promocion);
}

abstract interface class PermisosNotificacionesProximidad {
  Future<bool> tienePermisoParaNotificar();

  Future<bool> solicitarPermisoNotificaciones();

  Future<bool> abrirAjustesNotificaciones();
}

enum EstadoPermisoNotificaciones {
  concedido,
  denegado,
  desactivadoEnAjustes,
  noDisponible,
  errorTecnico,
}

abstract interface class DiagnosticoPermisoNotificaciones {
  Future<EstadoPermisoNotificaciones> consultarEstadoDetallado();

  Future<EstadoPermisoNotificaciones> solicitarPermisoDetallado();
}

abstract interface class DiagnosticoCanalNotificaciones {
  /// `null` indica que el sistema o plugin no pudo informar el estado.
  Future<bool?> canalPromocionesDisponible();
}

class NotificacionLocalService
    implements
        NotificacionPromocionGateway,
        PermisosNotificacionesProximidad,
        DiagnosticoPermisoNotificaciones,
        DiagnosticoCanalNotificaciones,
        NotificacionPromocionSimulable {
  NotificacionLocalService({
    FlutterLocalNotificationsPlugin? plugin,
    this.alAbrirEstablecimiento,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _canalId = 'promociones_cercanas';
  static const _canalNombre = 'Promociones cercanas';
  static const _permisoSolicitadoKey =
      'cercly.permisos.notificaciones.solicitud_resuelta.v1';

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<void> Function(String establecimientoId)? alAbrirEstablecimiento;
  bool _inicializado = false;
  bool _detalleInicioProcesado = false;

  Future<void> cancelarTodas() async {
    await inicializar();
    await _plugin.cancelAll();
  }

  @override
  Future<void> inicializar() async {
    if (_inicializado) return;

    const ajustes = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: ajustes,
      onDidReceiveNotificationResponse: _procesarRespuesta,
    );
    _inicializado = true;

    if (!_detalleInicioProcesado) {
      _detalleInicioProcesado = true;
      // La consulta de un toque de notificación anterior no debe bloquear
      // los permisos ni el envío de alertas si el plugin falla aquí.
      try {
        final detalle = await _plugin.getNotificationAppLaunchDetails();
        if (detalle?.didNotificationLaunchApp ?? false) {
          final id = establecimientoIdDesdePayload(
            detalle?.notificationResponse?.payload,
          );
          if (id != null) await alAbrirEstablecimiento?.call(id);
        }
      } catch (error, stackTrace) {
        _registrarFalloSeguro('launch_details', error, stackTrace);
      }
    }
  }

  /// Solo debe llamarse después de que la persona active expresamente las
  /// alertas. El monitor nunca muestra el diálogo de permisos por su cuenta.
  @override
  Future<bool> solicitarPermisoNotificaciones() async {
    return (await solicitarPermisoDetallado()) ==
        EstadoPermisoNotificaciones.concedido;
  }

  @override
  Future<EstadoPermisoNotificaciones> solicitarPermisoDetallado() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      try {
        // Las consultas y solicitudes del permiso no necesitan inicializar
        // canales ni leer el detalle de una notificación anterior.
        final activo = await android.areNotificationsEnabled();
        if (activo == true) {
          await _marcarSolicitudResuelta();
          return EstadoPermisoNotificaciones.concedido;
        }
        if (activo == null) return EstadoPermisoNotificaciones.noDisponible;
        final preferencias = SharedPreferencesAsync();
        if (await preferencias.getBool(_permisoSolicitadoKey) ?? false) {
          return EstadoPermisoNotificaciones.denegado;
        }
        await android.requestNotificationsPermission();
        final despues = await android.areNotificationsEnabled();
        await _marcarSolicitudResuelta();
        if (despues == true) {
          return EstadoPermisoNotificaciones.concedido;
        }
        if (despues == null) {
          return EstadoPermisoNotificaciones.noDisponible;
        }
        return EstadoPermisoNotificaciones.denegado;
      } catch (error, stackTrace) {
        _registrarFalloSeguro('android_request', error, stackTrace);
        return EstadoPermisoNotificaciones.errorTecnico;
      }
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    try {
      final permiso = await ios?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
      if (ios != null) await _marcarSolicitudResuelta();
      if (permiso == true) return EstadoPermisoNotificaciones.concedido;
      return permiso == false
          ? EstadoPermisoNotificaciones.denegado
          : EstadoPermisoNotificaciones.noDisponible;
    } catch (error, stackTrace) {
      _registrarFalloSeguro('ios_request', error, stackTrace);
      return EstadoPermisoNotificaciones.errorTecnico;
    }
  }

  @override
  Future<EstadoPermisoNotificaciones> consultarEstadoDetallado() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      try {
        final activo = await android.areNotificationsEnabled();
        if (activo == true) return EstadoPermisoNotificaciones.concedido;
        if (activo == false) {
          return EstadoPermisoNotificaciones.desactivadoEnAjustes;
        }
        return EstadoPermisoNotificaciones.noDisponible;
      } catch (error, stackTrace) {
        _registrarFalloSeguro('android_permission_check', error, stackTrace);
        return EstadoPermisoNotificaciones.errorTecnico;
      }
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      try {
        final permisos = await ios.checkPermissions();
        if (permisos?.isEnabled == true) {
          return EstadoPermisoNotificaciones.concedido;
        }
        if (permisos == null) return EstadoPermisoNotificaciones.noDisponible;
        return EstadoPermisoNotificaciones.denegado;
      } catch (error, stackTrace) {
        _registrarFalloSeguro('ios_permission_check', error, stackTrace);
        return EstadoPermisoNotificaciones.errorTecnico;
      }
    }
    return EstadoPermisoNotificaciones.noDisponible;
  }

  @override
  Future<bool> tienePermisoParaNotificar() async {
    return (await consultarEstadoDetallado()) ==
        EstadoPermisoNotificaciones.concedido;
  }

  @override
  Future<bool?> canalPromocionesDisponible() async {
    try {
      await inicializar();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return null;
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _canalId,
          _canalNombre,
          description: 'Avisos cuando hay una promoción cerca de ti',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
      final canales = await android.getNotificationChannels();
      if (canales == null) return null;
      final canal = canales.where((canal) => canal.id == _canalId);
      if (canal.isEmpty) return null;
      return canal.first.importance != Importance.none;
    } catch (error, stackTrace) {
      _registrarFalloSeguro('notification_channel_check', error, stackTrace);
      return null;
    }
  }

  @override
  Future<bool> abrirAjustesNotificaciones() async {
    try {
      await inicializar();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.openAppNotificationSettings() ?? false;
    } catch (error, stackTrace) {
      _registrarFalloSeguro('open_notification_settings', error, stackTrace);
      return false;
    }
  }

  Future<void> _marcarSolicitudResuelta() async {
    await SharedPreferencesAsync().setBool(_permisoSolicitadoKey, true);
  }

  @override
  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion) =>
      _mostrarPromocion(promocion, simulada: false);

  @override
  Future<bool> mostrarPromocionSimulada(PromocionDestacadaModel promocion) =>
      _mostrarPromocion(promocion, simulada: true);

  Future<bool> _mostrarPromocion(
    PromocionDestacadaModel promocion, {
    required bool simulada,
  }) async {
    await inicializar();
    if (!await tienePermisoParaNotificar()) return false;

    if (GeofencingExperimentalService.staging ||
        ProductionGeofencingService.enabledBuild) {
      try {
        final reserva =
            await const MethodChannel(
              ProductionGeofencingService.enabledBuild
                  ? ProductionGeofencingService.channelName
                  : 'cercly/geofence_experiment',
            ).invokeMethod<String>('reserveForegroundSlot', {
              'promotionId': promocion.id,
            });
        if (ProductionGeofencingService.enabledBuild && reserva != 'reserved') {
          return false;
        }
        if (reserva == 'cooldown' || reserva == 'blocked') return false;
      } on MissingPluginException {
        if (ProductionGeofencingService.enabledBuild) return false;
        // Tests y plataformas sin el módulo nativo conservan el control Dart.
      } on PlatformException catch (error, stackTrace) {
        _registrarFalloSeguro('geofence_shared_cooldown', error, stackTrace);
        return false;
      }
    }

    final descripcion = promocion.descripcion.trim();
    final cuerpo = descripcion.isEmpty
        ? '${promocion.titulo} en ${promocion.establecimientoNombre}'
        : '${promocion.titulo} en ${promocion.establecimientoNombre}. '
              '${_acortar(descripcion)}';

    const detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNombre,
        channelDescription: 'Avisos cuando hay una promoción cerca de ti',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        category: AndroidNotificationCategory.promo,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );

    await _plugin.show(
      id: _idEstable(promocion.id),
      title: simulada
          ? '[PRUEBA SIMULADA] Promoción cerca de ti'
          : 'Promoción cerca de ti',
      body: simulada ? 'SIMULACIÓN QA · $cuerpo' : cuerpo,
      notificationDetails: detalles,
      payload: promocion.establecimientoId,
    );
    return true;
  }

  static String? establecimientoIdDesdePayload(String? payload) {
    final id = payload?.trim();
    if (id == null || id.isEmpty || id.length > 80) return null;
    return id;
  }

  void _procesarRespuesta(NotificationResponse respuesta) {
    final id = establecimientoIdDesdePayload(respuesta.payload);
    if (id != null && alAbrirEstablecimiento != null) {
      unawaited(alAbrirEstablecimiento!(id));
    }
  }

  int _idEstable(String valor) {
    // FNV-1a: String.hashCode puede cambiar entre procesos.
    var hash = 0x811c9dc5;
    for (final unidad in valor.codeUnits) {
      hash ^= unidad;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  String _acortar(String texto) {
    if (texto.length <= 90) return texto;
    return '${texto.substring(0, 87)}...';
  }

  void _registrarFalloSeguro(String fase, Object error, StackTrace stackTrace) {
    // La traza permite diagnosticar el fallo sin registrar el mensaje de
    // plataforma, payloads, tokens ni coordenadas.
    final codigo = error is PlatformException ? error.code : 'no_platform_code';
    developer.log(
      'Notificaciones: fallo tecnico en $fase (codigo=$codigo, tipo=${error.runtimeType}).',
      name: 'cercly.notifications',
      stackTrace: stackTrace,
    );
  }
}
