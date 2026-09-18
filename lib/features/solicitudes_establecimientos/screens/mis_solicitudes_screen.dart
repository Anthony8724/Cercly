import 'package:flutter/material.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../services/solicitud_establecimiento_service.dart';
import 'nueva_solicitud_screen.dart';

class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  final SolicitudEstablecimientoService _service =
      SolicitudEstablecimientoService();

  late Future<List<SolicitudEstablecimientoDetalle>> _solicitudesFuture;
  String? _eliminandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _solicitudesFuture = _service.listarDelUsuarioActual();
  }

  Future<void> _recargar() async {
    setState(_cargar);
    await _solicitudesFuture;
  }

  Future<void> _abrirNuevaSolicitud() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NuevaSolicitudScreen()),
    );

    if (creada == true && mounted) {
      await _recargar();
    }
  }

  Future<void> _eliminar(SolicitudEstablecimientoDetalle detalle) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar solicitud'),
          content: Text(
            '¿Deseas eliminar la solicitud sobre '
            '"${detalle.nombreEstablecimiento}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    setState(() {
      _eliminandoId = detalle.solicitud.id;
    });

    try {
      await _service.eliminarPendiente(detalle.solicitud.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _eliminandoId = null;
        _cargar();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud eliminada.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _eliminandoId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'Solicitud de acceso';
      case SolicitudEstablecimientoModel.tipoCorreccion:
        return 'Corrección de información';
      default:
        return 'Reclamo de establecimiento';
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

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin fecha';
    }

    String dosDigitos(int valor) {
      return valor.toString().padLeft(2, '0');
    }

    return '${dosDigitos(fecha.day)}/'
        '${dosDigitos(fecha.month)}/'
        '${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerclyColors.background,
      body: Column(
        children: [
          CerclyPageHeader(
            title: 'Mis solicitudes',
            subtitle: 'Consulta el estado y las respuestas de tus solicitudes',
            icon: Icons.assignment_rounded,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              CerclyHeaderAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Actualizar',
                onPressed: _recargar,
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _recargar,
                child: FutureBuilder<List<SolicitudEstablecimientoDetalle>>(
                  future: _solicitudesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          24,
                          16,
                          28,
                        ),
                        children: [
                          CerclySectionCard(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 52,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No se pudieron cargar tus solicitudes.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CerclyColors.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: CerclyColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _recargar,
                                  icon:
                                      const Icon(Icons.refresh_rounded),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    final solicitudes =
                        snapshot.data ??
                        <SolicitudEstablecimientoDetalle>[];

                    if (solicitudes.isEmpty) {
                      return ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          24,
                          16,
                          28,
                        ),
                        children: [
                          CerclySectionCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(
                                      color: CerclyColors.softBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.assignment_outlined,
                                      size: 38,
                                      color: CerclyColors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Todavía no tienes solicitudes',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: CerclyColors.text,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  const Text(
                                    'Puedes reclamar un establecimiento, solicitar acceso o informar una corrección.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: CerclyColors.muted,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  FilledButton.icon(
                                    onPressed: _abrirNuevaSolicitud,
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          CerclyColors.blue,
                                    ),
                                    icon:
                                        const Icon(Icons.add_rounded),
                                    label:
                                        const Text('Nueva solicitud'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        28,
                      ),
                      children: [
                        const CerclySectionTitle(
                          title: 'Historial de solicitudes',
                          subtitle:
                              'Revisa cada solicitud enviada y la respuesta recibida.',
                          icon: Icons.history_rounded,
                        ),
                        const SizedBox(height: 14),
                        for (final detalle in solicitudes)
                          _SolicitudCard(
                            detalle: detalle,
                            eliminando:
                                _eliminandoId ==
                                detalle.solicitud.id,
                            nombreTipo: _nombreTipo,
                            nombreEstado: _nombreEstado,
                            colorEstado: _colorEstado,
                            iconoEstado: _iconoEstado,
                            formatearFecha: _formatearFecha,
                            onEliminar: () => _eliminar(detalle),
                          ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _abrirNuevaSolicitud,
                            style: FilledButton.styleFrom(
                              backgroundColor: CerclyColors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Nueva solicitud',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({
    required this.detalle,
    required this.eliminando,
    required this.nombreTipo,
    required this.nombreEstado,
    required this.colorEstado,
    required this.iconoEstado,
    required this.formatearFecha,
    required this.onEliminar,
  });

  final SolicitudEstablecimientoDetalle detalle;
  final bool eliminando;
  final String Function(String) nombreTipo;
  final String Function(String) nombreEstado;
  final Color Function(String) colorEstado;
  final IconData Function(String) iconoEstado;
  final String Function(DateTime?) formatearFecha;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final solicitud = detalle.solicitud;
    final color = colorEstado(solicitud.estado);

    return CerclySectionCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  iconoEstado(solicitud.estado),
                  color: color,
                  size: 24,
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
                        color: CerclyColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      nombreTipo(solicitud.tipo),
                      style: const TextStyle(
                        color: CerclyColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  nombreEstado(solicitud.estado),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            solicitud.mensaje,
            style: const TextStyle(
              color: CerclyColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: CerclyColors.blue,
              ),
              const SizedBox(width: 5),
              Text(
                'Enviada: ${formatearFecha(solicitud.creadoEn)}',
                style: const TextStyle(
                  color: CerclyColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (solicitud.motivoRespuesta.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: CerclyColors.softBlue,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFCEE0FB),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Respuesta del administrador',
                    style: TextStyle(
                      color: CerclyColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    solicitud.motivoRespuesta,
                    style: const TextStyle(
                      color: CerclyColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (solicitud.estaPendiente) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: eliminando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : TextButton.icon(
                      onPressed: onEliminar,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                      ),
                      label: const Text('Eliminar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

