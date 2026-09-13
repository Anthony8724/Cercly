import 'package:flutter/material.dart';

import '../controllers/explorar_controller.dart';
import '../models/ubicacion_usuario.dart';
import '../widgets/estado_ubicacion_card.dart';
import '../widgets/filtros_explorar.dart';
import '../widgets/tarjeta_establecimiento_publico.dart';
import 'detalle_establecimiento_screen.dart';

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({required this.controller, super.key});

  final ExplorarController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.buscar,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.radar,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cercly',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Descubre cerca de ti',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Encuentra comercios y promociones en tu zona.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        EstadoUbicacionCard(controller: controller),
                        const SizedBox(height: 16),
                        FiltrosExplorar(controller: controller),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cerca de ti',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (!controller.cargandoResultados &&
                                controller.ubicacion != null)
                              Text(
                                '${controller.establecimientos.length} resultados',
                                style: Theme.of(context).textTheme.bodySmall,
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
            descripcion: 'Cercly usa tu posición solamente para buscar lugares cercanos.',
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
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MensajeCentral(
            key: Key('estado-sin-resultados'),
            icono: Icons.search_off,
            titulo: 'No encontramos establecimientos',
            descripcion: 'Prueba con otro radio o cambia los filtros.',
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
            return SizedBox(
              height: 158,
              child: TarjetaEstablecimientoPublico(
                establecimiento: establecimiento,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetalleEstablecimientoScreen(
                        establecimiento: establecimiento,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ];
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
