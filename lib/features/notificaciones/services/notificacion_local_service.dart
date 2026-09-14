import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../promociones/models/promocion_destacada_model.dart';

abstract interface class NotificacionPromocionGateway {
  Future<void> inicializar();

  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion);
}

class NotificacionLocalService implements NotificacionPromocionGateway {
  NotificacionLocalService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _canalId = 'promociones_cercanas';
  static const _canalNombre = 'Promociones cercanas';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _inicializado = false;
  bool? _permisoConcedido;

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

    await _plugin.initialize(settings: ajustes);
    _inicializado = true;
  }

  Future<bool> _solicitarPermisoSiHaceFalta() async {
    if (_permisoConcedido != null) return _permisoConcedido!;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final permisoAndroid = await android?.requestNotificationsPermission();
    final permisoIos = await ios?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );

    _permisoConcedido = permisoAndroid ?? permisoIos ?? true;
    return _permisoConcedido!;
  }

  @override
  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion) async {
    await inicializar();
    if (!await _solicitarPermisoSiHaceFalta()) return false;

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
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        timeoutAfter: 10000,
        category: AndroidNotificationCategory.promo,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );

    await _plugin.show(
      id: promocion.id.hashCode & 0x7fffffff,
      title: 'Promoción cerca de ti',
      body: cuerpo,
      notificationDetails: detalles,
      payload: promocion.establecimientoId,
    );
    return true;
  }

  String _acortar(String texto) {
    if (texto.length <= 90) return texto;
    return '${texto.substring(0, 87)}...';
  }
}
