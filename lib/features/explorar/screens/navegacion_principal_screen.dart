import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/explorar_controller.dart';
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
    super.key,
  });

  final WidgetBuilder terceraOpcionBuilder;
  final String terceraOpcionLabel;
  final IconData terceraOpcionIcon;
  final IconData terceraOpcionSelectedIcon;
  final ExplorarController? controller;
  final bool inicializarController;
  final bool mostrarTilesMapa;

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
    if (widget.inicializarController) {
      unawaited(_controller.inicializar());
    }
  }

  @override
  void dispose() {
    if (_esPropio) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: IndexedStack(
        index: _indice,
        children: [
          ExplorarScreen(
            controller: _controller,
            onPerfil: () => setState(() => _indice = 2),
          ),
          MapaEstablecimientosScreen(
            controller: _controller,
            mostrarTiles: widget.mostrarTilesMapa,
          ),
          widget.terceraOpcionBuilder(context),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
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
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE9F1FF),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final seleccionado = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: seleccionado
                      ? const Color(0xFF1769FF)
                      : const Color(0xFF40516C),
                  size: seleccionado ? 25 : 23,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final seleccionado = states.contains(WidgetState.selected);
                return TextStyle(
                  color: seleccionado
                      ? const Color(0xFF1769FF)
                      : const Color(0xFF40516C),
                  fontSize: 11.5,
                  fontWeight:
                      seleccionado ? FontWeight.w700 : FontWeight.w500,
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
