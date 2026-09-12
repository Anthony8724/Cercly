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
  String? _establecimientoProcesando;

  @override
  void initState() {
    super.initState();
    _cargarEstablecimientos();
  }

  void _cargarEstablecimientos() {
    _establecimientosFuture = _service.listarEstablecimientosPendientes();
  }

  void _recargar() {
    setState(_cargarEstablecimientos);
  }

  Future<void> _cerrarSesion() async {
    await AuthService().signOut();
  }

  Future<void> _cambiarEstado(
    EstablecimientoModel establecimiento,
    String nuevoEstado,
  ) async {
    final accion = nuevoEstado == 'aprobado' ? 'aprobar' : 'rechazar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nuevoEstado == 'aprobado'
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
              style: nuevoEstado == 'rechazado'
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              child: Text(nuevoEstado == 'aprobado' ? 'Aprobar' : 'Rechazar'),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado == 'aprobado'
                ? 'Establecimiento aprobado correctamente.'
                : 'Establecimiento rechazado.',
          ),
        ),
      );

      _recargar();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _establecimientoProcesando = null;
        });
      }
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
                _Detalle(etiqueta: 'Estado', valor: establecimiento.estado),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          _cambiarEstado(establecimiento, 'rechazado');
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Rechazar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          _cambiarEstado(establecimiento, 'aprobado');
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
          onRefresh: () async {
            _recargar();
            await _establecimientosFuture;
          },
          child: ListView(
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
              Text(
                'Establecimientos pendientes',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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

                  final establecimientos =
                      snapshot.data ?? <EstablecimientoModel>[];

                  if (establecimientos.isEmpty) {
                    return const _MensajePanel(
                      icono: Icons.task_alt,
                      mensaje: 'No hay establecimientos pendientes.',
                    );
                  }

                  return Column(
                    children: establecimientos.map((establecimiento) {
                      final procesando =
                          _establecimientoProcesando == establecimiento.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.storefront),
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
                                        Text(establecimiento.direccion),
                                      ],
                                    ),
                                  ),
                                  const Chip(label: Text('Pendiente')),
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
                              if (procesando)
                                const Center(child: CircularProgressIndicator())
                              else
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        _mostrarDetalles(establecimiento);
                                      },
                                      child: const Text('Ver detalles'),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () {
                                        _cambiarEstado(
                                          establecimiento,
                                          'rechazado',
                                        );
                                      },
                                      tooltip: 'Rechazar',
                                      color: Colors.red,
                                      icon: const Icon(Icons.close),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () {
                                        _cambiarEstado(
                                          establecimiento,
                                          'aprobado',
                                        );
                                      },
                                      icon: const Icon(Icons.check),
                                      label: const Text('Aprobar'),
                                    ),
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
