import 'dart:async';

import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../../notificaciones/controllers/monitor_proximidad_controller.dart';
import '../../notificaciones/widgets/monitor_proximidad_app.dart';
import '../../notificaciones/widgets/radar_cercly_panel.dart';

import '../controllers/explorar_controller.dart';
import '../widgets/promociones_explorar.dart';
import 'explorar_screen.dart';
import 'mapa_establecimientos_screen.dart';

class NavegacionPrincipalScreen extends StatefulWidget {
  const NavegacionPrincipalScreen({
    required this.terceraOpcionBuilder,
    required this.terceraOpcionLabel,
    required this.terceraOpcionIcon,
    required this.terceraOpcionSelectedIcon,
    this.controller,
    this.inicializarController = true,
    this.mostrarTilesMapa = true,
    this.cargarPromociones,
    this.crearDetalle,
    super.key,
  });

  final WidgetBuilder terceraOpcionBuilder;
  final String terceraOpcionLabel;
  final IconData terceraOpcionIcon;
  final IconData terceraOpcionSelectedIcon;
  final ExplorarController? controller;
  final bool inicializarController;
  final bool mostrarTilesMapa;
  final CargarPromocionesExplorar? cargarPromociones;
  final CrearDetalleEstablecimiento? crearDetalle;

  @override
  State<NavegacionPrincipalScreen> createState() =>
      _NavegacionPrincipalScreenState();
}

class _NavegacionPrincipalScreenState extends State<NavegacionPrincipalScreen>
    with WidgetsBindingObserver {
  late final ExplorarController _controller;
  late final bool _esPropio;
  int _indice = 0;
  MonitorProximidadController? _monitor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _esPropio = widget.controller == null;
    _controller = widget.controller ?? ExplorarController();
    if (widget.inicializarController) {
      unawaited(_controller.inicializar());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.restaurarUbicacionConsentida(alReanudar: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitor?.setRadarVisible(false);
    if (_esPropio) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    _monitor = MonitorProximidadScope.maybeOf(context);
    final radarVisible =
        _indice == 1 && (ModalRoute.of(context)?.isCurrent ?? true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _monitor?.setRadarVisible(radarVisible);
    });
    return Scaffold(
      backgroundColor: sky.background,
      body: IndexedStack(
        index: _indice,
        children: [
          ExplorarScreen(
            controller: _controller,
            onPerfil: () => setState(() => _indice = 2),
            cargarPromociones: widget.cargarPromociones,
            crearDetalle: widget.crearDetalle,
          ),
          Stack(
            children: [
              MapaEstablecimientosScreen(
                controller: _controller,
                mostrarTiles: widget.mostrarTilesMapa,
                crearDetalle: widget.crearDetalle,
              ),
              if (_monitor != null)
                Positioned(
                  key: const Key('radar-panel-position'),
                  left: 12,
                  right: 12,
                  // La atribución de OpenStreetMap ocupa la franja inferior.
                  bottom: 42,
                  child: SafeArea(
                    top: false,
                    child: RadarCerclyPanel(controller: _monitor!),
                  ),
                ),
            ],
          ),
          widget.terceraOpcionBuilder(context),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: sky.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1F4E8C),
              blurRadius: 16,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 70,
              backgroundColor: sky.surface,
              indicatorColor: sky.soft,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final seleccionado = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: seleccionado ? sky.interactive : sky.muted,
                  size: seleccionado ? 25 : 23,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final seleccionado = states.contains(WidgetState.selected);
                return TextStyle(
                  color: seleccionado ? sky.interactive : sky.muted,
                  fontSize: 11.5,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _indice,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (indice) =>
                  setState(() => _indice = indice),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: 'Explorar',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: 'Mapa',
                ),
                NavigationDestination(
                  key: const Key('tab-cuenta'),
                  icon: Icon(widget.terceraOpcionIcon),
                  selectedIcon: Icon(widget.terceraOpcionSelectedIcon),
                  label: widget.terceraOpcionLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
