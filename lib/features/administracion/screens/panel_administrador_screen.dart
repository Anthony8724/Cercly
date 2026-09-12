import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../establecimientos/models/establecimiento_model.dart';
import '../../establecimientos/services/establecimiento_service.dart';

class PanelAdministradorScreen extends StatefulWidget {
  const PanelAdministradorScreen({super.key});

  @override
  State<PanelAdministradorScreen> createState() =>
      _PanelAdministradorScreenState();
}

class _PanelAdministradorScreenState extends State<PanelAdministradorScreen> {
  final EstablecimientoService _service = EstablecimientoService();

  late Future<List<EstablecimientoModel>> _establecimientosFuture;

  String _estadoSeleccionado = 'pendiente';
  String? _establecimientoProcesando;

  @override
  void initState() {
    super.initState();
    _cargarEstablecimientos();
  }

  void _cargarEstablecimientos() {
    _establecimientosFuture = _service.listarTodosLosEstablecimientos();
  }

  Future<void> _recargar() async {
    setState(_cargarEstablecimientos);
    await _establecimientosFuture;
  }

  Future<void> _cerrarSesion() async {
    await AuthService().signOut();
  }

  Future<void> _cambiarEstado(
    EstablecimientoModel establecimiento,
    String nuevoEstado,
  ) async {
    final esAprobacion = nuevoEstado == 'aprobado';
    final accion = esAprobacion ? 'aprobar' : 'rechazar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            esAprobacion
                ? 'Aprobar establecimiento'
                : 'Rechazar establecimiento',
          ),
          content: Text(
            '¿Deseas $accion el establecimiento '
            '"${establecimiento.nombre}"?',
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
              style: esAprobacion
                  ? null
                  : FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(esAprobacion ? 'Aprobar' : 'Rechazar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    setState(() {
      _establecimientoProcesando = establecimiento.id;
    });

    try {
      await _service.cambiarEstado(
        establecimientoId: establecimiento.id,
        nuevoEstado: nuevoEstado,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _establecimientoProcesando = null;
        _cargarEstablecimientos();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esAprobacion
                ? 'Establecimiento aprobado correctamente.'
                : 'Establecimiento rechazado correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _establecimientoProcesando = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDetalles(EstablecimientoModel establecimiento) {
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
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.storefront, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        establecimiento.nombre,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Detalle(
                  etiqueta: 'Descripción',
                  valor: establecimiento.descripcion.isEmpty
                      ? 'Sin descripción'
                      : establecimiento.descripcion,
                ),
                _Detalle(
                  etiqueta: 'Dirección',
                  valor: establecimiento.direccion,
                ),
                _Detalle(
                  etiqueta: 'Teléfono',
                  valor: establecimiento.telefonoPublico.isEmpty
                      ? 'Sin teléfono'
                      : establecimiento.telefonoPublico,
                ),
                _Detalle(
                  etiqueta: 'Categoría',
                  valor: establecimiento.categoriaId,
                ),
                _Detalle(
                  etiqueta: 'Ubicación',
                  valor:
                      '${establecimiento.latitud}, '
                      '${establecimiento.longitud}',
                ),
                _Detalle(
                  etiqueta: 'Zona horaria',
                  valor: establecimiento.zonaHoraria,
                ),
                _Detalle(
                  etiqueta: 'Estado',
                  valor: _nombreEstado(establecimiento.estado),
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

  String _nombreEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return Icons.check_circle;
      case 'rechazado':
        return Icons.cancel;
      default:
        return Icons.pending_actions;
    }
  }

  Widget _construirAcciones(EstablecimientoModel establecimiento) {
    if (_establecimientoProcesando == establecimiento.id) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      );
    }

    if (establecimiento.estado == 'pendiente') {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              _cambiarEstado(establecimiento, 'rechazado');
            },
            icon: const Icon(Icons.close),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              _cambiarEstado(establecimiento, 'aprobado');
            },
            icon: const Icon(Icons.check),
            label: const Text('Aprobar'),
          ),
        ],
      );
    }

    if (establecimiento.estado == 'aprobado') {
      return OutlinedButton.icon(
        onPressed: () {
          _cambiarEstado(establecimiento, 'rechazado');
        },
        icon: const Icon(Icons.block),
        label: const Text('Cambiar a rechazado'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
      );
    }

    return FilledButton.icon(
      onPressed: () {
        _cambiarEstado(establecimiento, 'aprobado');
      },
      icon: const Icon(Icons.check),
      label: const Text('Cambiar a aprobado'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final correo = AuthService().currentUser?.email ?? 'Sin correo';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrativo'),
        actions: [
          IconButton(
            onPressed: _recargar,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
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
                'Administración de Cercly',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(correo),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'pendiente',
                      icon: Icon(Icons.pending_actions),
                      label: Text('Pendientes'),
                    ),
                    ButtonSegment<String>(
                      value: 'aprobado',
                      icon: Icon(Icons.check_circle),
                      label: Text('Aprobados'),
                    ),
                    ButtonSegment<String>(
                      value: 'rechazado',
                      icon: Icon(Icons.cancel),
                      label: Text('Rechazados'),
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
              FutureBuilder<List<EstablecimientoModel>>(
                future: _establecimientosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return _MensajePanel(
                      icono: Icons.error_outline,
                      mensaje:
                          'No se pudieron cargar los establecimientos.\n'
                          '${snapshot.error}',
                      boton: 'Reintentar',
                      onPressed: _recargar,
                    );
                  }

                  final todos = snapshot.data ?? <EstablecimientoModel>[];

                  final establecimientos = todos
                      .where(
                        (establecimiento) =>
                            establecimiento.estado == _estadoSeleccionado,
                      )
                      .toList();

                  if (establecimientos.isEmpty) {
                    return _MensajePanel(
                      icono: _iconoEstado(_estadoSeleccionado),
                      mensaje:
                          'No hay establecimientos '
                          '${_nombreEstado(_estadoSeleccionado).toLowerCase()}s.',
                    );
                  }

                  return Column(
                    children: establecimientos.map((establecimiento) {
                      final color = _colorEstado(establecimiento.estado);

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
                                    child: Icon(
                                      _iconoEstado(establecimiento.estado),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          establecimiento.nombre,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(establecimiento.direccion),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      _iconoEstado(establecimiento.estado),
                                      color: color,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _nombreEstado(establecimiento.estado),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                establecimiento.descripcion.isEmpty
                                    ? 'Sin descripción'
                                    : establecimiento.descripcion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _mostrarDetalles(establecimiento);
                                    },
                                    child: const Text('Ver detalles'),
                                  ),
                                  _construirAcciones(establecimiento),
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

class _MensajePanel extends StatelessWidget {
  const _MensajePanel({
    required this.icono,
    required this.mensaje,
    this.boton,
    this.onPressed,
  });

  final IconData icono;
  final String mensaje;
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
            Text(mensaje, textAlign: TextAlign.center),
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
