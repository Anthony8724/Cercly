import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/monitor_proximidad_controller.dart';

class MonitorProximidadApp extends StatefulWidget {
  const MonitorProximidadApp({required this.child, this.controller, super.key});

  final Widget child;
  final MonitorProximidadController? controller;

  @override
  State<MonitorProximidadApp> createState() => _MonitorProximidadAppState();
}

class _MonitorProximidadAppState extends State<MonitorProximidadApp>
    with WidgetsBindingObserver {
  late final MonitorProximidadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MonitorProximidadController();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.iniciar());
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
  Widget build(BuildContext context) => widget.child;
}
