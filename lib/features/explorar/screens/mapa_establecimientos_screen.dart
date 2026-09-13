import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../controllers/explorar_controller.dart';
import '../models/ubicacion_usuario.dart';
import '../widgets/filtros_explorar.dart';
import 'detalle_establecimiento_screen.dart';

class MapaEstablecimientosScreen extends StatelessWidget {
  const MapaEstablecimientosScreen({
    required this.controller,
    this.mostrarTiles = true,
    super.key,
  });

  final ExplorarController controller;
  final bool mostrarTiles;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ubicacion = controller.ubicacion;

        return SafeArea(
          child: Stack(
            children: [
              if (ubicacion == null)
                _SinUbicacion(controller: controller)
              else
                FlutterMap(
                  key: const Key('mapa-establecimientos'),
                  options: MapOptions(
                    initialCenter: LatLng(
                      ubicacion.latitud,
                      ubicacion.longitud,
                    ),
                    initialZoom: 14,
                  ),
                  children: [
                    if (mostrarTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.cercly.cercly',
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          key: const Key('marcador-usuario'),
                          point: LatLng(ubicacion.latitud, ubicacion.longitud),
                          width: 46,
                          height: 46,
                          child: const _MarcadorUsuario(),
                        ),
                        for (final establecimiento
                            in controller.establecimientos)
                          Marker(
                            key: Key('marcador-${establecimiento.id}'),
                            point: LatLng(
                              establecimiento.latitud,
                              establecimiento.longitud,
                            ),
                            width: 52,
                            height: 58,
                            child: _MarcadorEstablecimiento(
                              tienePromocion: establecimiento.tienePromociones,
                              onTap: () => _mostrarEstablecimiento(
                                context,
                                establecimiento,
                              ),
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.tune),
                    title: Text(
                      ubicacion == null
                          ? 'Mapa sin ubicación'
                          : '${controller.establecimientos.length} lugares en el mapa',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [FiltrosExplorar(controller: controller)],
                  ),
                ),
              ),
              if (controller.cargandoResultados)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Color(0x22000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarEstablecimiento(
    BuildContext context,
    EstablecimientoPublicoModel establecimiento,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              establecimiento.nombre,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(establecimiento.categoria.nombre),
            if (establecimiento.distanciaFormateada.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(establecimiento.distanciaFormateada),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetalleEstablecimientoScreen(
                        establecimiento: establecimiento,
                      ),
                    ),
                  );
                },
                child: const Text('Ver detalle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinUbicacion extends StatelessWidget {
  const _SinUbicacion({required this.controller});

  final ExplorarController controller;

  @override
  Widget build(BuildContext context) {
    final cargando = controller.estadoUbicacion == EstadoUbicacion.cargando;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 60),
            const SizedBox(height: 12),
            Text(
              controller.mensajeUbicacion ??
                  'Activa tu ubicación para mostrar el mapa.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: cargando ? null : controller.solicitarUbicacion,
              icon: const Icon(Icons.my_location),
              label: Text(cargando ? 'Buscando…' : 'Usar mi ubicación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarcadorUsuario extends StatelessWidget {
  const _MarcadorUsuario();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x552563EB),
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.all(9),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _MarcadorEstablecimiento extends StatelessWidget {
  const _MarcadorEstablecimiento({
    required this.tienePromocion,
    required this.onTap,
  });

  final bool tienePromocion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_on,
        size: 48,
        color: tienePromocion
            ? const Color(0xFFF97316)
            : const Color(0xFF2563EB),
        shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
      ),
    );
  }
}
