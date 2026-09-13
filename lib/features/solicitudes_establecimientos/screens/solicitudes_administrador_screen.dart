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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes'),
        actions: [
          IconButton(
            onPressed: _recargar,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Solicitudes de establecimientos',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Revisa las solicitudes antes de aprobarlas o rechazarlas.',
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: SolicitudEstablecimientoModel.estadoPendiente,
                      icon: Icon(Icons.pending_actions),
                      label: Text('Pendientes'),
                    ),
                    ButtonSegment<String>(
                      value: SolicitudEstablecimientoModel.estadoAprobada,
                      icon: Icon(Icons.check_circle),
                      label: Text('Aprobadas'),
                    ),
                    ButtonSegment<String>(
                      value: SolicitudEstablecimientoModel.estadoRechazada,
                      icon: Icon(Icons.cancel),
                      label: Text('Rechazadas'),
                    ),
                  ],
                  selected: {_estadoSeleccionado},
                  onSelectionChanged: (seleccion) {
                    setState(() {
                      _estadoSeleccionado = seleccion.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
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
                    );
                  }

                  return Column(
                    children: solicitudes.map((detalle) {
                      final solicitud = detalle.solicitud;
                      final procesando = _solicitudProcesando == solicitud.id;
                      final color = _colorEstado(solicitud.estado);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Icon(_iconoEstado(solicitud.estado)),
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
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(_nombreTipo(solicitud.tipo)),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      _iconoEstado(solicitud.estado),
                                      color: color,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _nombreEstado(solicitud.estado),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Solicitante: '
                                '${detalle.nombreSolicitante}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                solicitud.mensaje.isEmpty
                                    ? 'Sin mensaje'
                                    : solicitud.mensaje,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
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
    this.boton,
    this.onPressed,
  });

  final IconData icono;
  final String texto;
  final String? boton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icono, size: 56),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
            if (boton != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(boton!)),
            ],
          ],
        ),
      ),
    );
  }
}
