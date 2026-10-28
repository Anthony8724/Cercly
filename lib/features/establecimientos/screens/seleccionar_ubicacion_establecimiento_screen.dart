import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';

class SeleccionarUbicacionEstablecimientoScreen extends StatefulWidget {
  const SeleccionarUbicacionEstablecimientoScreen({
    this.latitudInicial,
    this.longitudInicial,
    this.mostrarTiles = true,
    super.key,
  });

  final double? latitudInicial;
  final double? longitudInicial;
  final bool mostrarTiles;

  @override
  State<SeleccionarUbicacionEstablecimientoScreen> createState() =>
      _SeleccionarUbicacionEstablecimientoScreenState();
}

class _SeleccionarUbicacionEstablecimientoScreenState
    extends State<SeleccionarUbicacionEstablecimientoScreen> {
  static const _centroTulcan = LatLng(0.8119, -77.7173);

  final _mapController = MapController();
  final _mapKey = GlobalKey();
  final _ubicacionService = GeolocatorUbicacionService();

  LatLng? _seleccion;
  bool _buscandoUbicacion = false;

  @override
  void initState() {
    super.initState();

    final latitud = widget.latitudInicial;
    final longitud = widget.longitudInicial;
    if (latitud != null && longitud != null) {
      final inicial = LatLng(latitud, longitud);
      if (_esPuntoValido(inicial)) _seleccion = inicial;
    }
  }

  bool _esPuntoValido(LatLng? punto) =>
      punto != null &&
      punto.latitude.isFinite &&
      punto.longitude.isFinite &&
      punto.latitude >= -90 &&
      punto.latitude <= 90 &&
      punto.longitude >= -180 &&
      punto.longitude <= 180;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _usarUbicacionActual() async {
    if (_buscandoUbicacion) return;

    setState(() {
      _buscandoUbicacion = true;
    });

    final resultado = await _ubicacionService.obtenerUbicacion(
      solicitarPermiso: true,
    );

    if (!mounted) return;

    setState(() {
      _buscandoUbicacion = false;
    });

    final ubicacion = resultado.ubicacion;
    if (ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado.mensaje ?? 'No pudimos obtener tu ubicación. Selecciona el punto en el mapa.',
          ),
        ),
      );
      return;
    }

    final punto = LatLng(ubicacion.latitud, ubicacion.longitud);
    if (!_esPuntoValido(punto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La ubicación recibida no es válida.')),
      );
      return;
    }
    setState(() {
      _seleccion = punto;
    });

    _mapController.move(punto, 17);
  }

  void _confirmar() {
    final seleccion = _seleccion;
    if (!_esPuntoValido(seleccion)) return;

    Navigator.of(context).pop(
      UbicacionUsuario(
        latitud: seleccion!.latitude,
        longitud: seleccion.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centroInicial = _seleccion ?? _centroTulcan;

    return Scaffold(
      backgroundColor: SkyPalette.of(context).background,
      body: Column(
        children: [
          CerclyPageHeader(
            title: 'Seleccionar ubicación',
            subtitle: 'Selecciona el punto del negocio en el mapa',
            icon: Icons.map_rounded,
            onBack: () => Navigator.of(context).maybePop(),
            compact: true,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      key: _mapKey,
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: centroInicial,
                        initialZoom: _seleccion == null ? 14 : 17,
                        onTap: (_, punto) {
                          if (!_esPuntoValido(punto)) return;
                          setState(() {
                            _seleccion = punto;
                          });
                          _mapController.move(
                            punto,
                            _mapController.camera.zoom,
                          );
                        },
                        onPositionChanged: (camera, hasGesture) {
                          if (!hasGesture) return;
                          final centro = camera.center;
                          if (!_esPuntoValido(centro)) return;
                          if (_seleccion?.latitude == centro.latitude &&
                              _seleccion?.longitude == centro.longitude) {
                            return;
                          }
                          setState(() => _seleccion = centro);
                        },
                      ),
                      children: [
                        if (widget.mostrarTiles)
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: const String.fromEnvironment(
                              'CERCLY_MAP_USER_AGENT',
                              defaultValue: 'com.cercly.cercly',
                            ),
                          ),
                        if (_seleccion != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _seleccion!,
                                width: 64,
                                height: 64,
                                alignment: Alignment.topCenter,
                                child: GestureDetector(
                                  key: const Key('marcador-arrastrable'),
                                  onPanUpdate: (details) {
                                    final box =
                                        _mapKey.currentContext
                                                ?.findRenderObject()
                                            as RenderBox?;
                                    if (box == null) return;
                                    final local = box.globalToLocal(
                                      details.globalPosition,
                                    );
                                    final punto = _mapController.camera
                                        .offsetToCrs(local);
                                    if (!_esPuntoValido(punto)) return;
                                    setState(() => _seleccion = punto);
                                  },
                                  child: const _MarcadorNegocio(),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: SkyPalette.of(context).surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22031A3A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: SkyPalette.of(context).interactive,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Toca el mapa o arrastra el marcador hasta el negocio. Tu GPS solo sirve como referencia.',
                                style: TextStyle(
                                  color: SkyPalette.of(context).text,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Container(
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).height < 700 ? 10 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: SkyPalette.of(context).surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33031A3A),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '© OpenStreetMap contributors',
                              key: const Key('atribucion-openstreetmap'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: SkyPalette.of(context).muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_esPuntoValido(_seleccion))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pin_drop_outlined,
                                    size: 18,
                                    color: SkyPalette.of(context).interactive,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Lat. ${_seleccion!.latitude.toStringAsFixed(6)}  ·  Lon. ${_seleccion!.longitude.toStringAsFixed(6)}',
                                      key: const Key(
                                        'coordenadas-seleccionadas',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: SkyPalette.of(context).text,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Toca el mapa para elegir un punto sin compartir la ubicación del dispositivo. Si eliges GPS, Cercly consultará tu ubicación precisa una vez para marcar el establecimiento; esa coordenada puede mostrarse en su ficha pública.',
                                key: const Key('sin-punto-seleccionado'),
                                style: TextStyle(
                                  color: SkyPalette.of(context).muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _buscandoUbicacion
                                  ? null
                                  : _usarUbicacionActual,
                              icon: _buscandoUbicacion
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                              label: Text(
                                _buscandoUbicacion
                                    ? 'Buscando ubicación...'
                                    : 'Usar mi ubicación actual',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              key: const Key('confirmar-ubicacion'),
                              onPressed: _esPuntoValido(_seleccion)
                                  ? _confirmar
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: SkyPalette.of(context).primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: Text(
                                !_esPuntoValido(_seleccion)
                                    ? 'Selecciona un punto'
                                    : 'Confirmar ubicación',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarcadorNegocio extends StatelessWidget {
  const _MarcadorNegocio();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on_rounded,
          size: 58,
          color: Color(0xFF1769FF),
          shadows: [
            Shadow(color: Colors.white, blurRadius: 5),
            Shadow(color: Color(0x55000000), blurRadius: 8),
          ],
        ),
        Positioned(
          top: 11,
          child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
        ),
      ],
    );
  }
}
