import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/screens/login_screen.dart';
import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/models/turno_horario.dart';
import '../../establecimientos/services/estado_horario_service.dart';
import '../../establecimientos/services/horario_establecimiento_service.dart';
import '../../solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import '../../solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import '../models/ubicacion_usuario.dart';
import '../services/consentimiento_ubicacion.dart';
import '../services/mapas_externos_service.dart';
import '../services/politica_rutas.dart';
import '../services/ruta_service.dart';
import '../services/ubicacion_service.dart';
import 'ruta_establecimiento_screen.dart';

typedef CargarHorarioEstablecimiento =
    Future<Map<String, List<TurnoHorario>>> Function(String establecimientoId);
typedef EstaAutenticado = bool Function();
typedef CrearPantallaAcceso = Widget Function();
typedef CrearPantallaReclamo = Widget Function(String establecimientoId);

class DetalleEstablecimientoScreen extends StatefulWidget {
  const DetalleEstablecimientoScreen({
    required this.establecimiento,
    this.mapasService,
    this.ubicacionService,
    this.rutaService,
    this.mostrarTilesRuta = true,
    this.cargarHorario,
    this.ahora,
    this.estaAutenticado,
    this.crearPantallaAcceso,
    this.crearPantallaReclamo,
    super.key,
  });

  final EstablecimientoPublicoModel establecimiento;
  final MapasExternosService? mapasService;
  final UbicacionService? ubicacionService;
  final RutaService? rutaService;
  final bool mostrarTilesRuta;
  final CargarHorarioEstablecimiento? cargarHorario;
  final DateTime Function()? ahora;
  final EstaAutenticado? estaAutenticado;
  final CrearPantallaAcceso? crearPantallaAcceso;
  final CrearPantallaReclamo? crearPantallaReclamo;

  @override
  State<DetalleEstablecimientoScreen> createState() =>
      _DetalleEstablecimientoScreenState();
}

class _DetalleEstablecimientoScreenState
    extends State<DetalleEstablecimientoScreen> {
  static const EstadoHorarioService _estadoHorarioService =
      EstadoHorarioService();

  EstadoHorario? _estadoHorario;
  bool _cargandoHorario = true;
  bool _abriendoRuta = false;

  EstablecimientoPublicoModel get establecimiento => widget.establecimiento;

  @override
  void initState() {
    super.initState();
    _cargarEstadoHorario();
  }

  Future<void> _cargarEstadoHorario() async {
    try {
      final cargarHorario =
          widget.cargarHorario ?? HorarioEstablecimientoService().obtener;
      final horario = await cargarHorario(establecimiento.id);
      final estado = _estadoHorarioService.calcular(
        ahora: (widget.ahora ?? DateTime.now)(),
        horario: horario,
      );

      if (!mounted) return;

      setState(() {
        _estadoHorario = estado;
        _cargandoHorario = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _estadoHorario = EstadoHorario.sinHorario;
        _cargandoHorario = false;
      });
    }
  }

  /// La variante de Play no consulta GPS ni el endpoint de rutas. Solo comparte
  /// el destino con Google Maps después de una acción y confirmación explícitas.
  Future<void> _comoLlegar() async {
    if (PoliticaRutas.internasHabilitadas) {
      await _comoLlegarConRutaInterna();
      return;
    }
    if (_abriendoRuta) return;
    setState(() => _abriendoRuta = true);
    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('aviso-mapas-externos'),
          title: const Text('Abrir en Google Maps'),
          content: const SingleChildScrollView(
            child: Text(
              'Se compartirá la ubicación del establecimiento con Google Maps. '
              'Cercly no consultará ni añadirá tu ubicación actual a este enlace. '
              'Google Maps puede utilizar tu ubicación según sus propios permisos y condiciones.',
            ),
          ),
          actions: [
            TextButton(
              key: const Key('mapas-externos-cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('mapas-externos-confirmar'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Abrir Google Maps'),
            ),
          ],
        ),
      );
      if (mounted && confirmado == true) await _abrirMapasExternos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir Google Maps. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoRuta = false);
    }
  }

  /// Código interno conservado para reactivación revisada. Si está autorizado,
  /// y el usuario ya autorizó Cercly para usar su ubicación, muestra la
  /// pantalla de rutas interna. Nunca solicita permisos nuevos desde este botón.
  /// Si falta consentimiento, permiso o GPS, conserva la salida a Google Maps.
  Future<void> _comoLlegarConRutaInterna() async {
    if (_abriendoRuta) return;
    setState(() => _abriendoRuta = true);
    try {
      if (!await ConsentimientoUbicacion.estaAceptado()) {
        if (mounted) await _abrirMapasExternos();
        return;
      }

      // El consentimiento general de GPS no sustituye la información sobre
      // el envío de coordenadas a un proveedor externo para calcular rutas.
      if (!mounted) return;
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('aviso-privacidad-ruta'),
          title: const Text('Antes de calcular tu ruta'),
          content: const SingleChildScrollView(
            child: Text(
              'Al elegir «Calcular ruta», Cercly enviará las coordenadas de '
              'tu ubicación y del establecimiento a Supabase y al servicio '
              'HeiGIT/OpenRouteService para obtener un recorrido por calles. '
              'El proveedor externo procesará esos datos según sus condiciones. '
              'Esta pantalla no hace seguimiento de tus movimientos en tiempo real. '
              'Puedes cancelar sin consultar tu posición ni solicitar la ruta.',
            ),
          ),
          actions: [
            TextButton(
              key: const Key('ruta-privacidad-cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('ruta-privacidad-confirmar'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Calcular ruta'),
            ),
          ],
        ),
      );
      if (!mounted || confirmado != true) return;

      final resultado =
          await (widget.ubicacionService ?? GeolocatorUbicacionService())
              .obtenerUbicacion(solicitarPermiso: false);
      if (!mounted) return;

      if (resultado.estado != EstadoUbicacion.disponible ||
          resultado.ubicacion == null) {
        await _abrirMapasExternos();
        return;
      }

      final origen = resultado.ubicacion!;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RutaEstablecimientoScreen(
            nombreDestino: establecimiento.nombre,
            origen: LatLng(origen.latitud, origen.longitud),
            destino: LatLng(establecimiento.latitud, establecimiento.longitud),
            rutaService: widget.rutaService,
            mostrarTiles: widget.mostrarTilesRuta,
            abrirExterno: () =>
                (widget.mapasService ?? MapasExternosService()).comoLlegar(
                  latitud: establecimiento.latitud,
                  longitud: establecimiento.longitud,
                ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) await _abrirMapasExternos();
    } finally {
      if (mounted) setState(() => _abriendoRuta = false);
    }
  }

  Future<void> _abrirMapasExternos() async {
    final abierto = await (widget.mapasService ?? MapasExternosService())
        .comoLlegar(
          latitud: establecimiento.latitud,
          longitud: establecimiento.longitud,
        );

    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No encontramos una aplicación de mapas disponible.'),
        ),
      );
    }
  }

  Future<void> _reclamarEstablecimiento() async {
    final autenticado =
        widget.estaAutenticado?.call() ??
        Supabase.instance.client.auth.currentUser != null;

    if (!autenticado) {
      final inicioExitoso = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              widget.crearPantallaAcceso?.call() ??
              const LoginScreen(devolverResultado: true),
        ),
      );

      if (inicioExitoso != true || !mounted) return;
    }

    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            widget.crearPantallaReclamo?.call(establecimiento.id) ??
            NuevaSolicitudScreen(
              tipoInicial: SolicitudEstablecimientoModel.tipoReclamar,
              establecimientoIdInicial: establecimiento.id,
              bloquearTipo: true,
            ),
      ),
    );
  }

  String get _textoEstadoHorario {
    switch (_estadoHorario) {
      case EstadoHorario.abierto:
        return 'Abierto';
      case EstadoHorario.cerrado:
        return 'Cerrado';
      case EstadoHorario.sinHorario:
      case null:
        return 'Horario no disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkyPalette.of(context).background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Detalle del establecimiento',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        elevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: SkyPalette.of(context).headerGradient,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: SkyPalette.of(context).surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('boton-como-llegar'),
              onPressed: _abriendoRuta ? null : _comoLlegar,
              style: FilledButton.styleFrom(
                backgroundColor: SkyPalette.of(context).primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded),
              label: const Text(
                'Cómo llegar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
      body: SkySurface(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeroEstablecimiento(establecimiento: establecimiento),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: SkyPalette.of(context).surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F0B4EA9),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            establecimiento.nombre,
                            style: TextStyle(
                              color: SkyPalette.of(context).text,
                              fontSize: 24,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.4,
                            ),
                          ),
                        ),
                        if (establecimiento.distanciaFormateada.isNotEmpty)
                          _PildoraDistancia(
                            distancia: establecimiento.distanciaFormateada,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EtiquetaCategoria(
                          texto: establecimiento.categoria.nombre,
                        ),
                        _EstadoHorarioChip(
                          cargando: _cargandoHorario,
                          estado: _estadoHorario,
                          texto: _textoEstadoHorario,
                        ),
                      ],
                    ),
                    if (establecimiento.descripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        establecimiento.descripcion,
                        style: TextStyle(
                          color: SkyPalette.of(context).muted,
                          height: 1.45,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      'Información',
                      style: TextStyle(
                        color: SkyPalette.of(context).text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DatoDetalle(
                      icono: Icons.location_on_outlined,
                      titulo: 'Dirección',
                      valor: establecimiento.direccion,
                    ),
                    if (establecimiento.telefonoPublico.trim().isNotEmpty)
                      _DatoDetalle(
                        icono: Icons.phone_outlined,
                        titulo: 'Teléfono',
                        valor: establecimiento.telefonoPublico,
                      ),
                    if ((establecimiento.ciudad ?? '').isNotEmpty ||
                        (establecimiento.provincia ?? '').isNotEmpty)
                      _DatoDetalle(
                        icono: Icons.map_outlined,
                        titulo: 'Ubicación',
                        valor:
                            [establecimiento.ciudad, establecimiento.provincia]
                                .whereType<String>()
                                .where((valor) => valor.isNotEmpty)
                                .join(', '),
                      ),
                    if (establecimiento.esReclamable) ...[
                      const SizedBox(height: 8),
                      _ReclamoCard(onTap: _reclamarEstablecimiento),
                    ],
                    if (establecimiento.promociones.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer_rounded,
                            color: SkyPalette.of(context).interactive,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Promociones activas',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: SkyPalette.of(context).text,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final promocion in establecimiento.promociones)
                        _PromocionCard(promocion: promocion),
                    ],
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

class _HeroEstablecimiento extends StatelessWidget {
  const _HeroEstablecimiento({required this.establecimiento});

  final EstablecimientoPublicoModel establecimiento;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ImagenDetalle(url: establecimiento.urlFotoPortada),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x10000000), Color(0x88021A3A)],
              ),
            ),
          ),
          const Positioned(
            left: 16,
            bottom: 32,
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                SizedBox(width: 5),
                Text(
                  'Tu mundo más cerca',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagenDetalle extends StatelessWidget {
  const _ImagenDetalle({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: SkyPalette.of(context).headerGradient,
        ),
        child: const Center(
          child: Icon(Icons.storefront_rounded, size: 82, color: Colors.white),
        ),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: 900,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: SkyPalette.of(context).headerGradient,
        ),
        child: const Center(
          child: Icon(Icons.storefront_rounded, size: 82, color: Colors.white),
        ),
      ),
    );
  }
}

class _PildoraDistancia extends StatelessWidget {
  const _PildoraDistancia({required this.distancia});

  final String distancia;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SkyPalette.of(context).soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.near_me_rounded,
            size: 15,
            color: SkyPalette.of(context).interactive,
          ),
          const SizedBox(width: 4),
          Text(
            distancia,
            style: TextStyle(
              color: SkyPalette.of(context).text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaCategoria extends StatelessWidget {
  const _EtiquetaCategoria({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: SkyPalette.of(context).soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: SkyPalette.of(context).interactive,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EstadoHorarioChip extends StatelessWidget {
  const _EstadoHorarioChip({
    required this.cargando,
    required this.estado,
    required this.texto,
  });

  final bool cargando;
  final EstadoHorario? estado;
  final String texto;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return _PildoraEstado(
        key: const Key('estado-horario-cargando'),
        icono: Icons.schedule_rounded,
        texto: 'Consultando horario',
        color: SkyPalette.of(context).muted,
        fondo: SkyPalette.of(context).soft,
      );
    }

    final abierto = estado == EstadoHorario.abierto;
    final cerrado = estado == EstadoHorario.cerrado;

    return _PildoraEstado(
      key: const Key('estado-horario'),
      icono: abierto
          ? Icons.check_circle_rounded
          : cerrado
          ? Icons.cancel_rounded
          : Icons.schedule_rounded,
      texto: texto,
      color: abierto
          ? SkyPalette.of(context).success
          : cerrado
          ? SkyPalette.of(context).error
          : SkyPalette.of(context).muted,
      fondo: SkyPalette.of(context).soft,
    );
  }
}

class _PildoraEstado extends StatelessWidget {
  const _PildoraEstado({
    required this.icono,
    required this.texto,
    required this.color,
    required this.fondo,
    super.key,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatoDetalle extends StatelessWidget {
  const _DatoDetalle({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: SkyPalette.of(context).soft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: SkyPalette.of(context).border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SkyPalette.of(context).surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icono,
              color: SkyPalette.of(context).interactive,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: SkyPalette.of(context).muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: TextStyle(
                    color: SkyPalette.of(context).text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReclamoCard extends StatelessWidget {
  const _ReclamoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SkyPalette.of(context).soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkyPalette.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Este negocio es tuyo?',
            style: TextStyle(
              color: SkyPalette.of(context).text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Envía una solicitud para administrarlo y publicar información en Cercly.',
            style: TextStyle(color: SkyPalette.of(context).muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('reclamar-establecimiento'),
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: SkyPalette.of(context).interactive,
              side: BorderSide(color: SkyPalette.of(context).border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Reclamar establecimiento'),
          ),
        ],
      ),
    );
  }
}

class _PromocionCard extends StatelessWidget {
  const _PromocionCard({required this.promocion});

  final PromocionPublicaModel promocion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SkyPalette.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkyPalette.of(context).border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x130B4EA9),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 76,
              height: 76,
              child: promocion.urlImagen != null
                  ? Image.network(
                      promocion.urlImagen!,
                      fit: BoxFit.cover,
                      cacheWidth: 260,
                      errorBuilder: (_, _, _) => const _PromoFallback(),
                    )
                  : const _PromoFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promocion.titulo,
                  style: TextStyle(
                    color: SkyPalette.of(context).text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (promocion.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    promocion.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SkyPalette.of(context).muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  'Vigente hasta ${_fecha(promocion.fechaFin)}',
                  style: TextStyle(
                    color: SkyPalette.of(context).interactive,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}

class _PromoFallback extends StatelessWidget {
  const _PromoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: SkyPalette.of(context).soft),
      child: Icon(
        Icons.local_offer_rounded,
        color: SkyPalette.of(context).interactive,
        size: 30,
      ),
    );
  }
}
