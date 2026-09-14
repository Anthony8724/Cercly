import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../services/solicitud_establecimiento_service.dart';

class SolicitudesAdministradorScreen extends StatefulWidget {
  const SolicitudesAdministradorScreen({super.key});

  @override
  State<SolicitudesAdministradorScreen> createState() =>
      _SolicitudesAdministradorScreenState();
}

class _SolicitudesAdministradorScreenState
    extends State<SolicitudesAdministradorScreen> {
  static const _azul = Color(0xFF1769FF);
  static const _navy = Color(0xFF0A2A66);
  static const _fondo = Color(0xFFF5F8FE);
  static const _borde = Color(0xFFE2E9F5);

  final SolicitudEstablecimientoService _service =
      SolicitudEstablecimientoService();

  late Future<List<SolicitudEstablecimientoDetalle>> _solicitudesFuture;

  String _estadoSeleccionado = SolicitudEstablecimientoModel.estadoPendiente;

  String? _solicitudProcesando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _solicitudesFuture = _service.listarTodas();
  }

  Future<void> _recargar() async {
    setState(_cargar);
    await _solicitudesFuture;
  }

  Future<void> _responder(
    SolicitudEstablecimientoDetalle detalle,
    String nuevoEstado,
  ) async {
    final aprobando =
        nuevoEstado == SolicitudEstablecimientoModel.estadoAprobada;

    final motivo = await showDialog<String>(
      context: context,
      builder: (_) {
        return _DialogoRespuesta(
          aprobando: aprobando,
          nombreEstablecimiento: detalle.nombreEstablecimiento,
        );
      },
    );

    if (motivo == null || !mounted) {
      return;
    }

    setState(() {
      _solicitudProcesando = detalle.solicitud.id;
    });

    try {
      await _service.responder(
        solicitudId: detalle.solicitud.id,
        estado: nuevoEstado,
        motivoRespuesta: motivo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _solicitudProcesando = null;
        _cargar();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aprobando
                ? 'Solicitud aprobada correctamente.'
                : 'Solicitud rechazada correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _solicitudProcesando = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo responder: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDetalles(SolicitudEstablecimientoDetalle detalle) {
    final solicitud = detalle.solicitud;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalles de la solicitud',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _Detalle(
                  etiqueta: 'Solicitante',
                  valor: detalle.nombreSolicitante,
                ),
                _Detalle(
                  etiqueta: 'Establecimiento',
                  valor: detalle.nombreEstablecimiento,
                ),
                _Detalle(
                  etiqueta: 'Dirección',
                  valor: detalle.direccionEstablecimiento,
                ),
                _Detalle(
                  etiqueta: 'Tipo de solicitud',
                  valor: _nombreTipo(solicitud.tipo),
                ),
                _Detalle(
                  etiqueta: 'Mensaje',
                  valor: solicitud.mensaje.isEmpty
                      ? 'Sin mensaje'
                      : solicitud.mensaje,
                ),
                _Detalle(
                  etiqueta: 'Estado',
                  valor: _nombreEstado(solicitud.estado),
                ),
                _Detalle(
                  etiqueta: 'Fecha',
                  valor: _formatearFecha(solicitud.creadoEn),
                ),
                if (solicitud.motivoRespuesta.isNotEmpty)
                  _Detalle(
                    etiqueta: 'Respuesta del administrador',
                    valor: solicitud.motivoRespuesta,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(bottomSheetContext).pop();
                    },
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'Solicitar acceso';
      case SolicitudEstablecimientoModel.tipoCorreccion:
        return 'Solicitar corrección';
      default:
        return 'Reclamar establecimiento';
    }
  }

  String _nombreEstado(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return 'Aprobada';
      case SolicitudEstablecimientoModel.estadoRechazada:
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return Icons.check_circle;
      case SolicitudEstablecimientoModel.estadoRechazada:
        return Icons.cancel;
      default:
        return Icons.pending_actions;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return Colors.green;
      case SolicitudEstablecimientoModel.estadoRechazada:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin fecha';
    }

    String dosDigitos(int valor) {
      return valor.toString().padLeft(2, '0');
    }

    return '${dosDigitos(fecha.day)}/'
        '${dosDigitos(fecha.month)}/'
        '${fecha.year} '
        '${dosDigitos(fecha.hour)}:'
        '${dosDigitos(fecha.minute)}';
  }

  Widget _botonCabecera({
    required IconData icono,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icono, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Container(
      height: 158,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3F7FE8),
            Color(0xFF174FAD),
            Color(0xFF0A2A66),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _SolicitudesStarPainter()),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _botonCabecera(
                    icono: Icons.arrow_back_rounded,
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitudes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Gestiona las solicitudes de establecimientos',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _botonCabecera(
                    icono: Icons.refresh_rounded,
                    tooltip: 'Actualizar',
                    onPressed: _recargar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorEstado() {
    Widget opcion(String estado, String texto, IconData icono) {
      final seleccionado = estado == _estadoSeleccionado;

      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _estadoSeleccionado = estado),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: seleccionado ? _azul : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: seleccionado ? _azul : _borde),
              boxShadow: seleccionado
                  ? const [
                      BoxShadow(
                        color: Color(0x241769FF),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icono,
                    size: 14,
                    color: seleccionado ? Colors.white : _navy,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    texto,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : _navy,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opcion(
          SolicitudEstablecimientoModel.estadoPendiente,
          'Pendientes',
          Icons.schedule_rounded,
        ),
        const SizedBox(width: 8),
        opcion(
          SolicitudEstablecimientoModel.estadoAprobada,
          'Aprobadas',
          Icons.check_circle_outline_rounded,
        ),
        const SizedBox(width: 8),
        opcion(
          SolicitudEstablecimientoModel.estadoRechazada,
          'Rechazadas',
          Icons.cancel_outlined,
        ),
      ],
    );
  }

  String _textoVacioSecundario(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return 'Las solicitudes aprobadas aparecerán aquí.';
      case SolicitudEstablecimientoModel.estadoRechazada:
        return 'Las solicitudes rechazadas aparecerán aquí.';
      default:
        return 'Las nuevas solicitudes aparecerán aquí.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _cabecera(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solicitudes de establecimientos',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Revisa las solicitudes antes de aprobarlas o rechazarlas.',
                    style: TextStyle(
                      color: Color(0xFF6F819F),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _selectorEstado(),
                  const SizedBox(height: 20),
                  FutureBuilder<List<SolicitudEstablecimientoDetalle>>(
                    future: _solicitudesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return _Mensaje(
                          icono: Icons.error_outline,
                          texto:
                              'No se pudieron cargar las solicitudes.\n'
                              '${snapshot.error}',
                          boton: 'Reintentar',
                          onPressed: _recargar,
                        );
                      }

                      final todas =
                          snapshot.data ?? <SolicitudEstablecimientoDetalle>[];

                      final solicitudes = todas
                          .where(
                            (detalle) =>
                                detalle.solicitud.estado == _estadoSeleccionado,
                          )
                          .toList();

                      if (solicitudes.isEmpty) {
                        return _Mensaje(
                          icono: _iconoEstado(_estadoSeleccionado),
                          texto:
                              'No hay solicitudes '
                              '${_nombreEstado(_estadoSeleccionado).toLowerCase()}s.',
                          textoSecundario: _textoVacioSecundario(
                            _estadoSeleccionado,
                          ),
                        );
                      }

                      return Column(
                        children: solicitudes.map((detalle) {
                          final solicitud = detalle.solicitud;
                          final procesando = _solicitudProcesando == solicitud.id;
                          final color = _colorEstado(solicitud.estado);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _borde),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D0A2A66),
                                  blurRadius: 14,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        child: Icon(
                                          _iconoEstado(solicitud.estado),
                                          color: color,
                                          size: 21,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              detalle.nombreEstablecimiento,
                                              style: const TextStyle(
                                                color: _navy,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _nombreTipo(solicitud.tipo),
                                              style: const TextStyle(
                                                color: Color(0xFF6F819F),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        backgroundColor: color.withValues(
                                          alpha: 0.09,
                                        ),
                                        side: BorderSide.none,
                                        visualDensity: VisualDensity.compact,
                                        avatar: Icon(
                                          _iconoEstado(solicitud.estado),
                                          color: color,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _nombreEstado(solicitud.estado),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Solicitante: '
                                    '${detalle.nombreSolicitante}',
                                    style: const TextStyle(
                                      color: _navy,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: Color(0xFF6F819F),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _formatearFecha(solicitud.creadoEn),
                                        style: const TextStyle(
                                          color: Color(0xFF6F819F),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    solicitud.mensaje.isEmpty
                                        ? 'Sin mensaje'
                                        : solicitud.mensaje,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF6F819F),
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (procesando)
                                    const Center(child: CircularProgressIndicator())
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            _mostrarDetalles(detalle);
                                          },
                                          child: const Text('Ver detalles'),
                                        ),
                                        if (solicitud.estaPendiente) ...[
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              _responder(
                                                detalle,
                                                SolicitudEstablecimientoModel
                                                    .estadoRechazada,
                                              );
                                            },
                                            icon: const Icon(Icons.close),
                                            label: const Text('Rechazar'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: () {
                                              _responder(
                                                detalle,
                                                SolicitudEstablecimientoModel
                                                    .estadoAprobada,
                                              );
                                            },
                                            icon: const Icon(Icons.check),
                                            label: const Text('Aprobar'),
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolicitudesStarPainter extends CustomPainter {
  const _SolicitudesStarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(19);
    final estrellas = Paint();

    for (var i = 0; i < 20; i++) {
      estrellas.color = Colors.white.withValues(
        alpha: 0.22 + random.nextDouble() * 0.45,
      );
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height * 0.82,
        ),
        0.45 + random.nextDouble() * 0.9,
        estrellas,
      );
    }

    final destello = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    for (final punto in [
      Offset(size.width * 0.46, 31),
      Offset(size.width * 0.76, 58),
    ]) {
      canvas.drawLine(
        Offset(punto.dx - 3.5, punto.dy),
        Offset(punto.dx + 3.5, punto.dy),
        destello,
      );
      canvas.drawLine(
        Offset(punto.dx, punto.dy - 3.5),
        Offset(punto.dx, punto.dy + 3.5),
        destello,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DialogoRespuesta extends StatefulWidget {
  const _DialogoRespuesta({
    required this.aprobando,
    required this.nombreEstablecimiento,
  });

  final bool aprobando;
  final String nombreEstablecimiento;

  @override
  State<_DialogoRespuesta> createState() => _DialogoRespuestaState();
}

class _DialogoRespuestaState extends State<_DialogoRespuesta> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _motivoController = TextEditingController();

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_motivoController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.aprobando ? 'Aprobar solicitud' : 'Rechazar solicitud',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.aprobando
                  ? 'Se aprobará la solicitud para '
                        '"${widget.nombreEstablecimiento}".'
                  : 'Indica por qué se rechazará la solicitud para '
                        '"${widget.nombreEstablecimiento}".',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motivoController,
              maxLength: 1000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.aprobando
                    ? 'Observación opcional'
                    : 'Motivo del rechazo',
                border: const OutlineInputBorder(),
              ),
              validator: (valor) {
                final texto = valor?.trim() ?? '';

                if (!widget.aprobando && texto.isEmpty) {
                  return 'El motivo del rechazo es obligatorio.';
                }

                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          style: widget.aprobando
              ? null
              : FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text(widget.aprobando ? 'Aprobar' : 'Rechazar'),
        ),
      ],
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(valor),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.texto,
    this.textoSecundario,
    this.boton,
    this.onPressed,
  });

  final IconData icono;
  final String texto;
  final String? textoSecundario;
  final String? boton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0A2A66),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icono, size: 27, color: const Color(0xFF1769FF)),
          ),
          const SizedBox(height: 15),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0A2A66),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (textoSecundario != null) ...[
            const SizedBox(height: 6),
            Text(
              textoSecundario!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6F819F),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (boton != null && onPressed != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(boton!)),
          ],
        ],
      ),
    );
  }
}
