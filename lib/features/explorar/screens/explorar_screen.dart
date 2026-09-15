import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../controllers/explorar_controller.dart';
import '../models/ubicacion_usuario.dart';
import '../widgets/cabecera_explorar.dart';
import '../widgets/estado_ubicacion_card.dart';
import '../widgets/filtros_explorar.dart';
import '../widgets/promociones_explorar.dart';
import '../widgets/tarjeta_establecimiento_publico.dart';
import 'detalle_establecimiento_screen.dart';

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({
    required this.controller,
    this.onPerfil,
    this.cargarPromociones,
    super.key,
  });

  final ExplorarController controller;
  final VoidCallback? onPerfil;
  final CargarPromocionesExplorar? cargarPromociones;

  void _abrirDetalle(BuildContext context, EstablecimientoPublicoModel establecimiento) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DetalleEstablecimientoScreen(establecimiento: establecimiento),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ColoredBox(
          color: const Color(0xFFF5F8FE),
          child: SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.buscar,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: CabeceraExplorar(
                    onPerfil: onPerfil,
                    buscador: _BuscadorEstablecimientos(controller: controller),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.estadoUbicacion != EstadoUbicacion.disponible) ...[
                          EstadoUbicacionCard(controller: controller),
                          const SizedBox(height: 16),
                        ],
                        FiltrosExplorar(controller: controller),
                        if (controller.estadoUbicacion == EstadoUbicacion.disponible &&
                            !controller.cargandoResultados && controller.errorResultados == null)
                          PromocionesExplorar(
                            establecimientos: controller.establecimientos,
                            cargarPromociones: cargarPromociones,
                            onEstablecimiento: (e) => _abrirDetalle(context, e),
                            onVerTodas: () => controller.cambiarSoloPromociones(true),
                          ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFF1769FF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                controller.busqueda.trim().isEmpty
                                    ? 'Cerca de ti'
                                    : 'Resultados de búsqueda',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (!controller.cargandoResultados &&
                                controller.ubicacion != null)
                              Flexible(
                                child: Text(
                                  '${controller.establecimientos.length} lugares mostrados',
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ..._contenido(context),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  List<Widget> _contenido(BuildContext context) {
    if (controller.estadoUbicacion != EstadoUbicacion.disponible) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MensajeCentral(
            icono: Icons.explore_outlined,
            titulo: 'Activa tu ubicación para comenzar',
            descripcion:
                'Cercly usa tu posición solamente para buscar lugares cercanos.',
          ),
        ),
      ];
    }

    if (controller.cargandoResultados && controller.establecimientos.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            key: Key('estado-loading'),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    if (controller.errorResultados != null &&
        controller.establecimientos.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MensajeCentral(
            key: const Key('estado-error'),
            icono: Icons.cloud_off_outlined,
            titulo: 'No pudimos cargar los lugares',
            descripcion: controller.errorResultados!,
            accion: FilledButton.icon(
              onPressed: controller.buscar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ),
      ];
    }

    if (controller.establecimientos.isEmpty) {
      final tieneBusqueda = controller.busqueda.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MensajeCentral(
            key: const Key('estado-sin-resultados'),
            icono: Icons.search_off,
            titulo: tieneBusqueda
                ? 'No encontramos coincidencias'
                : 'No encontramos establecimientos',
            descripcion: tieneBusqueda
                ? 'Prueba con otro nombre, categoría o subcategoría.'
                : 'Prueba con otro radio o cambia los filtros.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList.builder(
          itemCount:
              controller.establecimientos.length +
              (controller.hayMasResultados ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == controller.establecimientos.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  key: const Key('cargar-mas'),
                  onPressed: controller.cargandoResultados
                      ? null
                      : controller.cargarMas,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Cargar más'),
                ),
              );
            }
            final establecimiento = controller.establecimientos[index];
            return TarjetaEstablecimientoPublico(
                establecimiento: establecimiento,
                onTap: () => _abrirDetalle(context, establecimiento),
            );
          },
        ),
      ),
    ];
  }
}

class _BuscadorEstablecimientos extends StatefulWidget {
  const _BuscadorEstablecimientos({required this.controller});

  final ExplorarController controller;

  @override
  State<_BuscadorEstablecimientos> createState() =>
      _BuscadorEstablecimientosState();
}

class _BuscadorEstablecimientosState
    extends State<_BuscadorEstablecimientos> {
  late final TextEditingController _textoController;

  @override
  void initState() {
    super.initState();
    _textoController = TextEditingController(text: widget.controller.busqueda);
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  void _limpiar() {
    _textoController.clear();
    widget.controller.limpiarBusqueda();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('buscador-establecimientos'),
      controller: _textoController,
      textInputAction: TextInputAction.search,
      onChanged: widget.controller.cambiarBusqueda,
      onSubmitted: (_) => widget.controller.buscar(),
      decoration: InputDecoration(
        hintText: 'Buscar lugares cerca de ti',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textoController,
          builder: (context, valor, _) {
            if (valor.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              key: const Key('limpiar-busqueda'),
              tooltip: 'Limpiar búsqueda',
              onPressed: _limpiar,
              icon: const Icon(Icons.close),
            );
          },
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _MensajeCentral extends StatelessWidget {
  const _MensajeCentral({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.accion,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 58, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (accion != null) ...[const SizedBox(height: 18), accion!],
        ],
      ),
    );
  }
}
