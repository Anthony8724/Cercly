import 'dart:async';

import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/services/establecimiento_publico_service.dart';
import '../../explorar/screens/detalle_establecimiento_screen.dart';
import '../controllers/monitor_proximidad_controller.dart';

class MonitorProximidadApp extends StatefulWidget {
  const MonitorProximidadApp({
    required this.child,
    this.controller,
    this.cargarEstablecimiento,
    super.key,
  });

  final Widget child;
  final MonitorProximidadController? controller;
  final Future<EstablecimientoPublicoModel?> Function(String establecimientoId)?
  cargarEstablecimiento;

  @override
  State<MonitorProximidadApp> createState() => _MonitorProximidadAppState();
}

class _MonitorProximidadAppState extends State<MonitorProximidadApp>
    with WidgetsBindingObserver {
  late final MonitorProximidadController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        MonitorProximidadController(
          alAbrirEstablecimiento: _abrirEstablecimiento,
        );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.iniciar());
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.reanudar());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _controller.pausar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
