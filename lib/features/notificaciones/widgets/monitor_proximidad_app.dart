import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/services/establecimiento_publico_service.dart';
import '../../explorar/screens/detalle_establecimiento_screen.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../controllers/monitor_proximidad_controller.dart';
import '../services/production_geofencing_service.dart';
import '../services/session_notification_barrier.dart';
import '../push/fcm_promotion_message.dart';
import '../push/fcm_push_service.dart';

class MonitorProximidadApp extends StatefulWidget {
  const MonitorProximidadApp({
    required this.child,
    this.controller,
    this.pushService,
    this.cargarEstablecimiento,
    super.key,
  });

  final Widget child;
  final MonitorProximidadController? controller;
  final FcmPushService? pushService;
  final Future<EstablecimientoPublicoModel?> Function(String establecimientoId)?
  cargarEstablecimiento;

  @override
  State<MonitorProximidadApp> createState() => _MonitorProximidadAppState();
}

class _MonitorProximidadAppState extends State<MonitorProximidadApp>
    with WidgetsBindingObserver {
  late final MonitorProximidadController _controller;
  late final FcmPushService _pushService =
      widget.pushService ?? FcmPushService.shared;
  StreamSubscription<AuthState>? _authSubscription;
  static const _geofenceChannel = MethodChannel(
    ProductionGeofencingService.channelName,
  );

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        MonitorProximidadController(
          alAbrirEstablecimiento: _abrirEstablecimiento,
        );
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedIn) {
        SessionNotificationBarrier.signedIn(state.session);
      }
      if (ProductionGeofencingService.enabledBuild) {
        unawaited(_synchronizeGeofenceAccount(state.session?.user.id));
      }
    });
    try {
      _pushService.observeAuthentication(
        openPromotion: _abrirPromocionPush,
        showForegroundMessage: _mostrarPushEnPrimerPlano,
      );
    } catch (_) {
      // The push service remains dormant until Supabase has an authenticated
      // client and the user explicitly enables promotional push.
    }
    unawaited(_start());
    if (ProductionGeofencingService.enabledBuild) {
      _geofenceChannel.setMethodCallHandler(_onNativeMethod);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_consumeNativeNotification());
      });
    }
  }

  Future<void> _synchronizeGeofenceAccount(String? userId) async {
    final service = ProductionGeofencingService();
    await service.accountChanged(userId);
    if (userId != null) await service.prepareHistory();
  }

  Future<void> _start() async {
    if (ProductionGeofencingService.enabledBuild) {
      try {
        await ProductionGeofencingService().accountChanged(
          Supabase.instance.client.auth.currentUser?.id,
        );
        await ProductionGeofencingService().prepareHistory();
      } catch (_) {
        /* Native delivery fails closed until imported. */
      }
    }
    if (!mounted) return;
    await _controller.iniciar();
    if (ProductionGeofencingService.enabledBuild) {
      await ProductionGeofencingService().synchronize(automatic: true);
    }
  }

  Future<void> _onNativeMethod(MethodCall call) async {
    if (call.method != 'notificationOpened') return;
    final args = call.arguments;
    if (args is Map) {
      final promotionId = args['promotionId'];
      final establishmentId = args['establishmentId'];
      if (promotionId is String && establishmentId is String) {
        await _abrirPromocionPush(
          FcmPromotionMessage(
            eventId: promotionId,
            promotionId: promotionId,
            establishmentId: establishmentId,
            title: 'Promoción cercana',
            body: '',
          ),
        );
      }
    } else if (args is String) {
      await _abrirEstablecimiento(args);
    }
  }

  Future<void> _consumeNativeNotification() async {
    try {
      final payload = await _geofenceChannel.invokeMethod<Object?>(
        'consumePendingNotification',
      );
      if (payload is Map) {
        await _onNativeMethod(MethodCall('notificationOpened', payload));
      }
    } on PlatformException {
      // El canal solo existe en Android y el build experimental de Staging.
    } on MissingPluginException {
      // Facilita pruebas Flutter y otras plataformas.
    }
  }

  Future<void> _abrirEstablecimiento(String id) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final cargar =
          widget.cargarEstablecimiento ??
          EstablecimientoPublicoService().obtenerPorId;
      final establecimiento = await cargar(id);
      if (!mounted) return;
      if (establecimiento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este establecimiento ya no está disponible.'),
          ),
        );
        return;
      }
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              DetalleEstablecimientoScreen(establecimiento: establecimiento),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos abrir el establecimiento. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _abrirPromocionPush(FcmPromotionMessage message) async {
    try {
      final promocion = await PromocionPublicaService().obtenerPorId(
        message.promotionId,
      );
      if (!mounted) return;
      final ahora = DateTime.now();
      if (promocion == null ||
          promocion.establecimientoId != message.establishmentId ||
          !promocion.activa ||
          promocion.fechaInicio.isAfter(ahora) ||
          !promocion.fechaFin.isAfter(ahora)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta promoción ya no está disponible.'),
          ),
        );
        return;
      }
      await _abrirEstablecimiento(promocion.establecimientoId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos validar esta promoción.')),
      );
    }
  }

  void _mostrarPushEnPrimerPlano(FcmPromotionMessage message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.body.isEmpty
              ? message.title
              : '${message.title}: ${message.body}',
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reanudarServicios());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _controller.suspenderPorCicloDeVida();
    }
  }

  Future<void> _reanudarServicios() async {
    try {
      await _pushService.reconcileAfterResume();
    } catch (_) {
      // Push registration must not keep the foreground Radar paused.
    }
    if (!mounted) return;
    await _controller.reanudar();
    if (ProductionGeofencingService.enabledBuild) {
      await ProductionGeofencingService().synchronize(automatic: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MonitorProximidadScope(controller: _controller, child: widget.child);
}

class MonitorProximidadScope extends InheritedWidget {
  const MonitorProximidadScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final MonitorProximidadController controller;

  static MonitorProximidadController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MonitorProximidadScope>()
      ?.controller;

  static Widget wrapRouteIfAvailable({
    required BuildContext context,
    required Widget child,
  }) {
    final controller = maybeOf(context);
    if (controller == null) return child;
    return MonitorProximidadScope(controller: controller, child: child);
  }

  @override
  bool updateShouldNotify(MonitorProximidadScope oldWidget) =>
      controller != oldWidget.controller;
}
