import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../promociones/models/promocion_destacada_model.dart';

abstract interface class NotificacionPromocionGateway {
  Future<void> inicializar();

  Future<bool> tienePermisoParaNotificar();

  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion);
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

class NotificacionLocalService
    implements
        NotificacionPromocionGateway,
        PermisosNotificacionesProximidad,
        DiagnosticoPermisoNotificaciones {
  NotificacionLocalService({
    FlutterLocalNotificationsPlugin? plugin,
    this.alAbrirEstablecimiento,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _canalId = 'promociones_cercanas';
  static const _canalNombre = 'Promociones cercanas';

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
      } catch (error) {
        _registrarFalloSeguro('launch_details', error);
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
    try {
      await inicializar();
    } catch (error) {
      _registrarFalloSeguro('initialize', error);
      return EstadoPermisoNotificaciones.errorTecnico;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      try {
        final activo = await android.areNotificationsEnabled();
        if (activo == true) return EstadoPermisoNotificaciones.concedido;
        if (activo == null) return EstadoPermisoNotificaciones.noDisponible;
        final solicitud = await android.requestNotificationsPermission();
        final despues = await android.areNotificationsEnabled();
        if (despues == true || solicitud == true) {
          return EstadoPermisoNotificaciones.concedido;
        }
        if (despues == null) {
          return EstadoPermisoNotificaciones.noDisponible;
        }
        return EstadoPermisoNotificaciones.denegado;
      } catch (error) {
        _registrarFalloSeguro('android_request', error);
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
      if (permiso == true) return EstadoPermisoNotificaciones.concedido;
      return permiso == false
          ? EstadoPermisoNotificaciones.denegado
          : EstadoPermisoNotificaciones.noDisponible;
    } catch (error) {
      _registrarFalloSeguro('ios_request', error);
      return EstadoPermisoNotificaciones.errorTecnico;
    }
  }

  @override
  Future<EstadoPermisoNotificaciones> consultarEstadoDetallado() async {
    try {
      await inicializar();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final activo = await android.areNotificationsEnabled();
        if (activo == true) return EstadoPermisoNotificaciones.concedido;
        if (activo == false) {
          return EstadoPermisoNotificaciones.desactivadoEnAjustes;
        }
        return EstadoPermisoNotificaciones.noDisponible;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final permisos = await ios.checkPermissions();
        if (permisos?.isEnabled == true) {
          return EstadoPermisoNotificaciones.concedido;
        }
        if (permisos == null) return EstadoPermisoNotificaciones.noDisponible;
        return EstadoPermisoNotificaciones.denegado;
      }
      return EstadoPermisoNotificaciones.noDisponible;
    } catch (error) {
      _registrarFalloSeguro('permission_check', error);
      return EstadoPermisoNotificaciones.errorTecnico;
    }
  }

  @override
  Future<bool> tienePermisoParaNotificar() async {
    return (await consultarEstadoDetallado()) ==
        EstadoPermisoNotificaciones.concedido;
  }

  @override
  Future<bool> abrirAjustesNotificaciones() async {
    await inicializar();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.openAppNotificationSettings() ?? false;
  }

  @override
  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion) async {
    await inicializar();
    if (!await tienePermisoParaNotificar()) return false;

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
        timeoutAfter: 10000,
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
      title: 'Promoción cerca de ti',
      body: cuerpo,
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

  void _registrarFalloSeguro(String fase, Object error) {
    // No registrar payloads, tokens, coordenadas ni mensajes completos de
    // plataforma. El código permite correlacionar fallos de Android con QA.
    final codigo = error is PlatformException ? error.code : 'no_platform_code';
    developer.log(
      'Notificaciones: fallo tecnico en $fase (codigo=$codigo, tipo=${error.runtimeType}).',
      name: 'cercly.notifications',
    );
  }
}
