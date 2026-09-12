import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        actions: [
          IconButton(
            onPressed: _recargar,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevaSolicitud,
        icon: const Icon(Icons.add),
        label: const Text('Nueva solicitud'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: FutureBuilder<List<SolicitudEstablecimientoDetalle>>(
            future: _solicitudesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudieron cargar tus solicitudes.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _recargar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ),
                  ],
                );
              }

              final solicitudes =
                  snapshot.data ?? <SolicitudEstablecimientoDetalle>[];

              if (solicitudes.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.assignment_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Todavía no tienes solicitudes',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pulsa “Nueva solicitud” para reclamar un '
                      'establecimiento, pedir acceso o informar '
                      'una corrección.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: solicitudes.length,
                itemBuilder: (context, index) {
                  final detalle = solicitudes[index];
                  final solicitud = detalle.solicitud;
                  final color = _colorEstado(solicitud.estado);
                  final eliminando = _eliminandoId == solicitud.id;

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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                label: Text(_nombreEstado(solicitud.estado)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(solicitud.mensaje),
                          const SizedBox(height: 8),
                          Text(
                            'Enviada: ${_formatearFecha(solicitud.creadoEn)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (solicitud.motivoRespuesta.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text(
                              'Respuesta del administrador',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(solicitud.motivoRespuesta),
                          ],
                          if (solicitud.estaPendiente) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: eliminando
                                  ? const CircularProgressIndicator()
                                  : TextButton.icon(
                                      onPressed: () {
                                        _eliminar(detalle);
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Eliminar'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
