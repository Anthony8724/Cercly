import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/establecimiento_model.dart';
import '../services/foto_establecimiento_service.dart';

class FotosEstablecimientoScreen extends StatefulWidget {
  const FotosEstablecimientoScreen({required this.establecimiento, super.key});

  final EstablecimientoModel establecimiento;

  @override
  State<FotosEstablecimientoScreen> createState() =>
      _FotosEstablecimientoScreenState();
}

class _FotosEstablecimientoScreenState
    extends State<FotosEstablecimientoScreen> {
  final _service = FotoEstablecimientoService();
  final _imagePicker = ImagePicker();

  late Future<List<FotoEstablecimiento>> _fotosFuture;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _fotosFuture = _service.listar(widget.establecimiento.id);
  }

  void _recargar() {
    setState(_cargar);
  }

  Future<void> _seleccionarFotos(
    List<FotoEstablecimiento> fotosActuales,
  ) async {
    final disponibles =
        FotoEstablecimientoService.maximoFotos - fotosActuales.length;

    if (disponibles <= 0) {
      _mostrarMensaje('Ya alcanzaste el máximo de 5 fotografías.');
      return;
    }

    final archivos = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );

    if (archivos.isEmpty) {
      return;
    }

    if (archivos.length > disponibles) {
      _mostrarMensaje(
        'Solo puedes seleccionar $disponibles fotografía(s) más.',
      );
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _service.subir(
        establecimientoId: widget.establecimiento.id,
        archivos: archivos,
      );

      if (!mounted) {
        return;
      }

      _mostrarMensaje('Fotografías subidas correctamente.');
      _recargar();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _mostrarMensaje('No se pudieron subir: $error');
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _hacerPortada(FotoEstablecimiento foto) async {
    if (foto.esPortada || _procesando) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _service.establecerComoPortada(
        establecimientoId: widget.establecimiento.id,
        fotoId: foto.id,
      );

      if (mounted) {
        _mostrarMensaje('Portada actualizada.');
        _recargar();
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje('No se pudo cambiar la portada: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _eliminar(FotoEstablecimiento foto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar fotografía'),
          content: const Text('¿Deseas eliminar esta fotografía?'),
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
      await _service.eliminar(foto);

      if (mounted) {
        _mostrarMensaje('Fotografía eliminada.');
        _recargar();
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje('No se pudo eliminar: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fotografías')),
      body: FutureBuilder<List<FotoEstablecimiento>>(
        future: _fotosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar las fotografías.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _recargar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final fotos = snapshot.data ?? <FotoEstablecimiento>[];

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.establecimiento.nombre,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${fotos.length} de '
                    '${FotoEstablecimientoService.maximoFotos} fotografías',
                  ),
                  const SizedBox(height: 20),
                  if (fotos.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 60),
                            SizedBox(height: 12),
                            Text(
                              'Todavía no existen fotografías.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: fotos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                      itemBuilder: (context, index) {
                        final foto = fotos[index];

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      foto.urlTemporal,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 40,
                                              ),
                                            );
                                          },
                                    ),
                                    if (foto.esPortada)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Chip(
                                          avatar: const Icon(
                                            Icons.star,
                                            size: 16,
                                          ),
                                          label: const Text('Portada'),
                                          backgroundColor:
                                              Colors.amber.shade100,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    onPressed: _procesando
                                        ? null
                                        : () => _hacerPortada(foto),
                                    tooltip: 'Usar como portada',
                                    icon: Icon(
                                      foto.esPortada
                                          ? Icons.star
                                          : Icons.star_border,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _procesando
                                        ? null
                                        : () => _eliminar(foto),
                                    tooltip: 'Eliminar',
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _seleccionarFotos(fotos),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Seleccionar fotografías'),
                  ),
                ],
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
    );
  }
}
