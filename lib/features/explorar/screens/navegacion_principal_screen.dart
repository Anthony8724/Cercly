import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/explorar_controller.dart';
import 'explorar_screen.dart';
import 'mapa_establecimientos_screen.dart';

class NavegacionPrincipalScreen extends StatefulWidget {
  const NavegacionPrincipalScreen({
    required this.negocioBuilder,
    this.controller,
    super.key,
  });

  final WidgetBuilder negocioBuilder;
  final ExplorarController? controller;

  @override
  State<NavegacionPrincipalScreen> createState() =>
      _NavegacionPrincipalScreenState();
}

class _NavegacionPrincipalScreenState extends State<NavegacionPrincipalScreen> {
  late final ExplorarController _controller;
  late final bool _esPropio;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _esPropio = widget.controller == null;
    _controller = widget.controller ?? ExplorarController();
    unawaited(_controller.inicializar());
  }

  @override
  void dispose() {
    if (_esPropio) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          ExplorarScreen(controller: _controller),
          MapaEstablecimientosScreen(controller: _controller),
          widget.negocioBuilder(context),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (indice) => setState(() => _indice = indice),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Mi negocio',
          ),
        ],
      ),
    );
  }
}
