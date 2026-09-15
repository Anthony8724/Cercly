import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/screens/login_screen.dart';
import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/models/turno_horario.dart';
import '../../establecimientos/services/estado_horario_service.dart';
import '../../establecimientos/services/horario_establecimiento_service.dart';
import '../../solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import '../../solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import '../services/mapas_externos_service.dart';

typedef CargarHorarioEstablecimiento =
    Future<Map<String, List<TurnoHorario>>> Function(String establecimientoId);
typedef EstaAutenticado = bool Function();
typedef CrearPantallaAcceso = Widget Function();
typedef CrearPantallaReclamo = Widget Function(String establecimientoId);

class DetalleEstablecimientoScreen extends StatefulWidget {
  const DetalleEstablecimientoScreen({
    required this.establecimiento,
    this.mapasService,
    this.cargarHorario,
    this.ahora,
    this.estaAutenticado,
    this.crearPantallaAcceso,
    this.crearPantallaReclamo,
    super.key,
  });

  final EstablecimientoPublicoModel establecimiento;
  final MapasExternosService? mapasService;
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

  Future<void> _comoLlegar(BuildContext context) async {
    final abierto = await (widget.mapasService ?? MapasExternosService())
        .comoLlegar(
          latitud: establecimiento.latitud,
          longitud: establecimiento.longitud,
        );

    if (!abierto && context.mounted) {
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
      backgroundColor: const Color(0xFFF6F9FE),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Cercly',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF02142F), Color(0xFF0B5DD8)],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('boton-como-llegar'),
              onPressed: () => _comoLlegar(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1769FF),
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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroEstablecimiento(establecimiento: establecimiento),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: Colors.white,
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
                          style: const TextStyle(
                            color: Color(0xFF102A56),
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
                      style: const TextStyle(
                        color: Color(0xFF53647E),
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Información',
                    style: TextStyle(
                      color: Color(0xFF102A56),
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
                      valor: [
                        establecimiento.ciudad,
                        establecimiento.provincia,
                      ]
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
                        const Icon(
                          Icons.local_offer_rounded,
                          color: Color(0xFF1769FF),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Promociones activas',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF102A56),
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
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B4EA9), Color(0xFF1769FF), Color(0xFF78B7FF)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 82,
            color: Colors.white,
          ),
        ),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: 900,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF1769FF),
        child: Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 82,
            color: Colors.white,
          ),
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
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.near_me_rounded,
            size: 15,
            color: Color(0xFF1769FF),
          ),
          const SizedBox(width: 4),
          Text(
            distancia,
            style: const TextStyle(
              color: Color(0xFF285584),
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
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Color(0xFF1769FF),
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
      return const _PildoraEstado(
        key: Key('estado-horario-cargando'),
        icono: Icons.schedule_rounded,
        texto: 'Consultando horario',
        color: Color(0xFF64748B),
        fondo: Color(0xFFF1F5F9),
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
          ? const Color(0xFF15803D)
          : cerrado
              ? const Color(0xFFB91C1C)
              : const Color(0xFF64748B),
      fondo: abierto
          ? const Color(0xFFF0FDF4)
          : cerrado
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF1F5F9),
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
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5ECF7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icono, color: const Color(0xFF1769FF), size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Color(0xFF65758C),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Color(0xFF1D2D45),
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
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF3FF), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCFE1FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Este negocio es tuyo?',
            style: TextStyle(
              color: Color(0xFF102A56),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Envía una solicitud para administrarlo y publicar información en Cercly.',
            style: TextStyle(color: Color(0xFF5B6E88), height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('reclamar-establecimiento'),
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1769FF),
              side: const BorderSide(color: Color(0xFF7EB0FF)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E9F5)),
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
                  style: const TextStyle(
                    color: Color(0xFF102A56),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (promocion.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    promocion.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF687991),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  'Vigente hasta ${_fecha(promocion.fechaFin)}',
                  style: const TextStyle(
                    color: Color(0xFF1769FF),
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
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F1FF), Color(0xFFD9E8FF)],
        ),
      ),
      child: Icon(
        Icons.local_offer_rounded,
        color: Color(0xFF1769FF),
        size: 30,
      ),
    );
  }
}
