import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';

class SeleccionarUbicacionEstablecimientoScreen extends StatefulWidget {
  const SeleccionarUbicacionEstablecimientoScreen({
    this.latitudInicial,
    this.longitudInicial,
    super.key,
  });

  final double? latitudInicial;
  final double? longitudInicial;

  @override
  State<SeleccionarUbicacionEstablecimientoScreen> createState() =>
      _SeleccionarUbicacionEstablecimientoScreenState();
}

class _SeleccionarUbicacionEstablecimientoScreenState
    extends State<SeleccionarUbicacionEstablecimientoScreen> {
  static const _centroTulcan = LatLng(0.8119, -77.7173);

  final _mapController = MapController();
  final _ubicacionService = GeolocatorUbicacionService();

  LatLng? _seleccion;
  bool _buscandoUbicacion = false;

  @override
  void initState() {
    super.initState();

    final latitud = widget.latitudInicial;
    final longitud = widget.longitudInicial;
    if (latitud != null && longitud != null) {
      _seleccion = LatLng(latitud, longitud);
    }
  }

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

    final resultado = await _ubicacionService.obtenerUbicacion();

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
    setState(() {
      _seleccion = punto;
    });

    _mapController.move(punto, 17);
  }

  void _confirmar() {
    final seleccion = _seleccion;
    if (seleccion == null) return;

    Navigator.of(context).pop(
      UbicacionUsuario(
        latitud: seleccion.latitude,
        longitud: seleccion.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centroInicial = _seleccion ?? _centroTulcan;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FE),
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        backgroundColor: const Color(0xFFF5F8FE),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centroInicial,
                  initialZoom: _seleccion == null ? 14 : 17,
                  onTap: (_, punto) {
                    setState(() {
                      _seleccion = punto;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.cercly.cercly',
                  ),
                  if (_seleccion != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _seleccion!,
                          width: 64,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: const _MarcadorNegocio(),
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
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22031A3A),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, color: Color(0xFF1769FF)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toca el mapa exactamente donde se encuentra tu negocio.',
                          style: TextStyle(
                            color: Color(0xFF203A63),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                        onPressed: _seleccion == null ? null : _confirmar,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1769FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          _seleccion == null
                              ? 'Selecciona un punto'
                              : 'Confirmar ubicación',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
