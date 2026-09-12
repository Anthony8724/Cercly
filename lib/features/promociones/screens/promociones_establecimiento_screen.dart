import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_model.dart';
import '../models/promocion_model.dart';
import '../services/promocion_service.dart';
import 'registro_promocion_screen.dart';

class PromocionesEstablecimientoScreen extends StatefulWidget {
  const PromocionesEstablecimientoScreen({
    required this.establecimiento,
    super.key,
  });

  final EstablecimientoModel establecimiento;

  @override
  State<PromocionesEstablecimientoScreen> createState() =>
      _PromocionesEstablecimientoScreenState();
}

class _PromocionesEstablecimientoScreenState
    extends State<PromocionesEstablecimientoScreen> {
  final _service = PromocionService();

  late Future<List<_PromocionVista>> _promocionesFuture;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _promocionesFuture = _cargarPromociones();
  }

  Future<List<_PromocionVista>> _cargarPromociones() async {
    final promociones = await _service.listarPorEstablecimiento(
      widget.establecimiento.id,
    );

    return Future.wait(
      promociones.map((promocion) async {
        final url = await _service.obtenerUrlImagen(promocion);

        return _PromocionVista(promocion: promocion, urlImagen: url);
      }),
    );
  }

  Future<void> _recargar() async {
    setState(_cargar);
    await _promocionesFuture;
  }

  Future<void> _abrirRegistro() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            RegistroPromocionScreen(establecimiento: widget.establecimiento),
      ),
    );

    if (creada == true && mounted) {
      setState(_cargar);
    }
  }

  Future<void> _cambiarEstado(PromocionModel promocion, bool activa) async {
    if (_procesando) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _service.cambiarEstado(promocionId: promocion.id, activa: activa);

      if (mounted) {
        _mostrarMensaje(
          activa ? 'Promoción activada.' : 'Promoción desactivada.',
        );
        setState(_cargar);
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje('No se pudo actualizar la promoción: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _eliminar(PromocionModel promocion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar promoción'),
          content: Text(
            '¿Deseas eliminar la promoción '
            '"${promocion.titulo}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _service.eliminar(promocion);

      if (mounted) {
        _mostrarMensaje('Promoción eliminada.');
        setState(_cargar);
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje('No se pudo eliminar la promoción: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _abrirRegistro,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: FutureBuilder<List<_PromocionVista>>(
          future: _promocionesFuture,
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
                  const Icon(Icons.error_outline, color: Colors.red, size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar las promociones.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(_cargar);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              );
            }

            final promociones = snapshot.data ?? <_PromocionVista>[];

            if (promociones.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.local_offer_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    widget.establecimiento.nombre,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Todavía no existen promociones.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _abrirRegistro,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear primera promoción'),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: promociones.length,
                  itemBuilder: (context, index) {
                    final vista = promociones[index];
                    final promocion = vista.promocion;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (vista.urlImagen != null)
                            Image.network(
                              vista.urlImagen!,
                              height: 190,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: Icon(Icons.broken_image, size: 42),
                                  ),
                                );
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  promocion.titulo,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (promocion.descripcion.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(promocion.descripcion),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  'Desde ${_formatearFecha(promocion.fechaInicio)} '
                                  'hasta ${_formatearFecha(promocion.fechaFin)}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Radio de alerta: '
                                  '${promocion.radioAlertaMetros} m',
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          promocion.activa
                                              ? 'Activa'
                                              : 'Inactiva',
                                        ),
                                        value: promocion.activa,
                                        onChanged: _procesando
                                            ? null
                                            : (valor) {
                                                _cambiarEstado(
                                                  promocion,
                                                  valor,
                                                );
                                              },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _procesando
                                          ? null
                                          : () => _eliminar(promocion),
                                      tooltip: 'Eliminar',
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_procesando)
                  const ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PromocionVista {
  const _PromocionVista({required this.promocion, required this.urlImagen});

  final PromocionModel promocion;
  final String? urlImagen;
}
