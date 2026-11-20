import '../widgets/atribucion_mapa.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../sky/sky_theme.dart';
import '../models/ruta_model.dart';
import '../services/supabase_ruta_service.dart';
import '../services/ruta_service.dart';
import '../services/ruta_service_linea_recta.dart';

/// Muestra, dentro de la app, la ruta desde la ubicación del usuario hasta un
/// establecimiento: línea sobre el mapa, distancia y tiempo estimado.
///
/// Esta pantalla no pide permisos ni ubicación: recibe el [origen] ya
/// resuelto. Quien la abre debe haber comprobado antes que hay ubicación.
///
/// No es navegación GPS paso a paso: no sigue al usuario ni da indicaciones.
class RutaEstablecimientoScreen extends StatefulWidget {
  const RutaEstablecimientoScreen({
    required this.nombreDestino,
    required this.origen,
    required this.destino,
    this.rutaService,
    this.abrirExterno,
    this.mostrarTiles = true,
    super.key,
  });

  final String nombreDestino;
  final LatLng origen;
  final LatLng destino;

  /// Por defecto usa OpenRouteService, o la línea recta de prueba si la app se
  /// ejecuta con `--dart-define=CERCLY_RUTAS_SIMULADAS=true`.
  final RutaService? rutaService;

  /// Alternativa cuando falla el cálculo: abrir la ruta en otra app de mapas.
  /// Si es null, no se ofrece.
  final Future<bool> Function()? abrirExterno;

  final bool mostrarTiles;

  @override
  State<RutaEstablecimientoScreen> createState() =>
      _RutaEstablecimientoScreenState();
}

class _RutaEstablecimientoScreenState extends State<RutaEstablecimientoScreen> {
  static const bool _rutasSimuladas = bool.fromEnvironment(
    'CERCLY_RUTAS_SIMULADAS',
  );

  final MapController _mapController = MapController();
  late final RutaService _servicio;

  PerfilRuta _perfil = PerfilRuta.aPie;
  RutaModel? _ruta;
  RutaException? _error;
  bool _cargando = true;
  int _peticion = 0;

  bool get _esSimulada => _servicio is RutaServiceLineaRecta;

  @override
  void initState() {
    super.initState();
    _servicio =
        widget.rutaService ??
        (_rutasSimuladas
            ? const RutaServiceLineaRecta()
            : SupabaseRutaService());
    _calcular();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _reintentar() {
    setState(() {
      _cargando = true;
      _error = null;
    });
    _calcular();
  }

  Future<void> _calcular() async {
    final peticion = ++_peticion;
    try {
      final ruta = await _servicio.calcularRuta(
        origen: widget.origen,
        destino: widget.destino,
        perfil: _perfil,
      );
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _ruta = ruta;
        _error = null;
        _cargando = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _ajustarCamara(ruta));
    } on RutaException catch (error) {
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _ruta = null;
        _error = error;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _ruta = null;
        _error = const RutaException(
          TipoErrorRuta.servicioNoDisponible,
          'No pudimos calcular la ruta. Inténtalo de nuevo.',
        );
        _cargando = false;
      });
    }
  }

  void _ajustarCamara(RutaModel ruta) {
    if (!mounted) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(ruta.puntos),
          padding: const EdgeInsets.all(56),
        ),
      );
    } catch (_) {
      // Si el mapa aún no está listo, se queda con el encuadre inicial.
    }
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);

    return Scaffold(
      key: const Key('pantalla-ruta'),
      backgroundColor: sky.background,
      appBar: AppBar(
        title: Text(
          widget.nombreDestino,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: sky.headerGradient),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _mapa(sky)),
          _panel(sky),
        ],
      ),
    );
  }

  Widget _mapa(SkyPalette sky) {
    final centro = LatLng(
      (widget.origen.latitude + widget.destino.latitude) / 2,
      (widget.origen.longitude + widget.destino.longitude) / 2,
    );
    final ruta = _ruta;

    return FlutterMap(
      key: const Key('mapa-ruta'),
      mapController: _mapController,
      options: MapOptions(initialCenter: centro, initialZoom: 15),
      children: [
        if (widget.mostrarTiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: const String.fromEnvironment(
              'CERCLY_MAP_USER_AGENT',
              defaultValue: 'com.cercly.cercly',
            ),
          ),
        if (ruta != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: ruta.puntos,
                strokeWidth: 5,
                color: sky.interactive,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              key: const Key('marcador-origen-ruta'),
              point: widget.origen,
              width: 40,
              height: 40,
              child: Icon(
                Icons.my_location_rounded,
                color: sky.primary,
                size: 30,
              ),
            ),
            Marker(
              key: const Key('marcador-destino-ruta'),
              point: widget.destino,
              width: 48,
              height: 56,
              child: Icon(
                Icons.location_on_rounded,
                color: sky.error,
                size: 44,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: const AtribucionMapa(rutas: true),
          ),
        ),
      ],
    );
  }

  Widget _panel(SkyPalette sky) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: sky.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: sky.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _estado(sky),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final perfil in PerfilRuta.values)
                  ChoiceChip(
                    label: Text(
                      perfil == PerfilRuta.aPie ? 'A pie' : 'En auto',
                    ),
                    selected: _perfil == perfil,
                    selectedColor: sky.selectedSurface,
                    backgroundColor: sky.surface,
                    side: BorderSide(color: sky.border),
                    labelStyle: TextStyle(color: sky.text),
                    onSelected: (_) {
                      if (_perfil == perfil) return;
                      setState(() => _perfil = perfil);
                      _reintentar();
                    },
                  ),
              ],
            ),
            if (_esSimulada)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Ruta de prueba en línea recta: no es un recorrido real.',
                  key: const Key('ruta-aviso-simulada'),
                  style: TextStyle(color: sky.muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _estado(SkyPalette sky) {
    if (_cargando) {
      return Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: sky.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text('Calculando ruta…', style: TextStyle(color: sky.text)),
        ],
      );
    }

    final error = _error;
    if (error != null) {
      return Column(
        key: const Key('ruta-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: sky.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(error.mensaje, style: TextStyle(color: sky.text)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              if (error.tipo != TipoErrorRuta.sinRuta)
                TextButton(
                  key: const Key('ruta-reintentar'),
                  onPressed: _reintentar,
                  child: const Text('Reintentar'),
                ),
              if (widget.abrirExterno != null)
                TextButton(
                  key: const Key('ruta-abrir-externo'),
                  onPressed: () => widget.abrirExterno!(),
                  child: const Text('Abrir en otra app'),
                ),
            ],
          ),
        ],
      );
    }

    final ruta = _ruta;
    if (ruta == null) return const SizedBox.shrink();

    return Row(
      children: [
        _dato(
          sky,
          Icons.straighten_rounded,
          ruta.distanciaTexto,
          'Distancia',
          const Key('ruta-distancia'),
        ),
        const SizedBox(width: 28),
        _dato(
          sky,
          Icons.schedule_rounded,
          ruta.duracionTexto,
          'Tiempo estimado',
          const Key('ruta-tiempo'),
        ),
      ],
    );
  }

  Widget _dato(
    SkyPalette sky,
    IconData icono,
    String valor,
    String etiqueta,
    Key clave,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 20, color: sky.interactive),
            const SizedBox(width: 6),
            Text(
              valor,
              key: clave,
              style: TextStyle(
                color: sky.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Text(etiqueta, style: TextStyle(color: sky.muted, fontSize: 12)),
      ],
    );
  }
}
