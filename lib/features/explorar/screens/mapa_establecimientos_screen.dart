import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../sky/sky_theme.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../controllers/explorar_controller.dart';
import '../models/ubicacion_usuario.dart';
import '../widgets/filtros_explorar.dart';
import 'detalle_establecimiento_screen.dart';
import 'explorar_screen.dart' show CrearDetalleEstablecimiento;

class MapaEstablecimientosScreen extends StatelessWidget {
  const MapaEstablecimientosScreen({
    required this.controller,
    this.mostrarTiles = true,
    this.crearDetalle,
    super.key,
  });

  final ExplorarController controller;
  final bool mostrarTiles;
  final CrearDetalleEstablecimiento? crearDetalle;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ubicacion = controller.ubicacion;

        return ColoredBox(
          color: sky.background,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ubicacion == null
                      ? _SinUbicacion(controller: controller)
                      : FlutterMap(
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
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    const String.fromEnvironment(
                                      'CERCLY_MAP_USER_AGENT',
                                      defaultValue: 'com.cercly.cercly',
                                    ),
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  key: const Key('marcador-usuario'),
                                  point: LatLng(
                                    ubicacion.latitud,
                                    ubicacion.longitud,
                                  ),
                                  width: 52,
                                  height: 52,
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
                                    height: 60,
                                    child: _MarcadorEstablecimiento(
                                      tienePromocion:
                                          establecimiento.tienePromociones,
                                      onTap: () => _mostrarEstablecimiento(
                                        context,
                                        establecimiento,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '© OpenStreetMap contributors',
                                      key: Key(
                                        'atribucion-openstreetmap-explorar',
                                      ),
                                      style: TextStyle(
                                        color: Color(0xFF253041),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _PanelMapa(
                    controller: controller,
                    tieneUbicacion: ubicacion != null,
                  ),
                ),
                if (controller.cargandoResultados)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Color(0x22031A3A),
                        child: Center(
                          child: CircularProgressIndicator(color: sky.primary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarEstablecimiento(
    BuildContext context,
    EstablecimientoPublicoModel establecimiento,
  ) {
    final sky = SkyPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        decoration: BoxDecoration(
          color: sky.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sky.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: _PortadaMini(establecimiento: establecimiento),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          establecimiento.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sky.text,
                            fontSize: 19,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          establecimiento.categoria.nombre,
                          style: TextStyle(
                            color: sky.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (establecimiento.distanciaFormateada.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: sky.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                establecimiento.distanciaFormateada,
                                style: TextStyle(
                                  color: sky.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) =>
                            crearDetalle?.call(routeContext, establecimiento) ??
                            DetalleEstablecimientoScreen(
                              establecimiento: establecimiento,
                            ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: sky.primary,
                    foregroundColor: sky.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Ver detalle',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelMapa extends StatelessWidget {
  const _PanelMapa({required this.controller, required this.tieneUbicacion});

  final ExplorarController controller;
  final bool tieneUbicacion;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Material(
      elevation: 5,
      shadowColor: const Color(0x33031A3A),
      color: sky.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: sky.headerGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.map_rounded, color: Colors.white, size: 22),
          ),
          title: Text(
            tieneUbicacion ? 'Mapa Cercly' : 'Mapa sin ubicación',
            style: TextStyle(
              color: sky.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            tieneUbicacion
                ? '${controller.establecimientos.length} lugares cerca de ti'
                : 'Activa tu ubicación para comenzar',
            style: TextStyle(color: sky.muted, fontSize: 11.5),
          ),
          trailing: Icon(Icons.tune_rounded, color: sky.primary),
          children: [FiltrosExplorar(controller: controller)],
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
    final sky = SkyPalette.of(context);
    final cargando = controller.estadoUbicacion == EstadoUbicacion.cargando;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky.soft, sky.background],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sky.surface,
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  size: 42,
                  color: sky.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Encuentra lugares en el mapa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sky.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.mensajeUbicacion ?? 'Si eliges continuar, Cercly pedirá ubicación precisa para centrar el mapa, mostrar lugares cercanos y comprobar promociones para alertas locales mientras la app está abierta. Las búsquedas envían las coordenadas a Supabase; no usamos ubicación en segundo plano. Puedes seguir sin activar esta función y revocar el permiso en los ajustes de Android.',
                textAlign: TextAlign.center,
                style: TextStyle(color: sky.muted, height: 1.35),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: cargando ? null : controller.solicitarUbicacion,
                style: FilledButton.styleFrom(
                  backgroundColor: sky.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.my_location_rounded),
                label: Text(cargando ? 'Buscando…' : 'Usar ubicación y buscar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarcadorUsuario extends StatelessWidget {
  const _MarcadorUsuario();

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: sky.primary.withValues(alpha: .38),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: sky.primary.withValues(alpha: .25), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: sky.primary),
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
    final sky = SkyPalette.of(context);
    final color = tienePromocion ? const Color(0xFFF97316) : sky.primary;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 50,
            color: color,
            shadows: const [
              Shadow(color: Colors.white, blurRadius: 4),
              Shadow(color: Color(0x55000000), blurRadius: 7),
            ],
          ),
          Positioned(
            top: 9,
            child: Icon(
              tienePromocion
                  ? Icons.local_offer_rounded
                  : Icons.storefront_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortadaMini extends StatelessWidget {
  const _PortadaMini({required this.establecimiento});

  final EstablecimientoPublicoModel establecimiento;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final url = establecimiento.urlFotoPortada;
    if (url == null || url.isEmpty) {
      return ColoredBox(
        color: sky.soft,
        child: Icon(Icons.storefront_rounded, color: sky.primary, size: 36),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 300,
      errorBuilder: (_, _, _) => ColoredBox(
        color: sky.soft,
        child: Icon(Icons.storefront_rounded, color: sky.primary, size: 36),
      ),
    );
  }
}
