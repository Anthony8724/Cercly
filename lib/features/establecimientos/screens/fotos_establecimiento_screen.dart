import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/ui/cercly_ui.dart';

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
      backgroundColor: CerclyColors.background,
      body: Column(
        children: [
          CerclyPageHeader(
            title: 'Fotografías',
            subtitle: widget.establecimiento.nombre,
            icon: Icons.photo_library_rounded,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: FutureBuilder<List<FotoEstablecimiento>>(
                future: _fotosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: CerclySectionCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No se pudieron cargar las fotografías.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: CerclyColors.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _recargar,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final fotos =
                      snapshot.data ?? <FotoEstablecimiento>[];

                  return Stack(
                    children: [
                      ListView(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          28,
                        ),
                        children: [
                          CerclySectionCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: CerclyColors.softBlue,
                                    borderRadius:
                                        BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.collections_rounded,
                                    color: CerclyColors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Galería del establecimiento',
                                        style: TextStyle(
                                          color: CerclyColors.text,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${fotos.length} de ${FotoEstablecimientoService.maximoFotos} fotografías',
                                        style: const TextStyle(
                                          color: CerclyColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (fotos.isEmpty)
                            const CerclySectionCard(
                              child: Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 58,
                                      color: CerclyColors.blue,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Todavía no existen fotografías.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: CerclyColors.text,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Agrega imágenes para que los usuarios conozcan mejor tu negocio.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: CerclyColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: fotos.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.80,
                                  ),
                              itemBuilder: (context, index) {
                                final foto = fotos[index];

                                return Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    border: Border.all(
                                      color: CerclyColors.border,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x12031A3A),
                                        blurRadius: 14,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
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
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return const ColoredBox(
                                                      color:
                                                          CerclyColors
                                                              .softBlue,
                                                      child: Center(
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_rounded,
                                                          color:
                                                              CerclyColors
                                                                  .blue,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            ),
                                            if (foto.esPortada)
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                            horizontal:
                                                                9,
                                                            vertical: 6,
                                                          ),
                                                  decoration:
                                                      BoxDecoration(
                                                        color:
                                                            Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                  999,
                                                                ),
                                                      ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.star_rounded,
                                                        size: 15,
                                                        color:
                                                            Colors.amber,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Portada',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
                                                : () =>
                                                      _hacerPortada(
                                                        foto,
                                                      ),
                                            tooltip:
                                                'Usar como portada',
                                            icon: Icon(
                                              foto.esPortada
                                                  ? Icons.star_rounded
                                                  : Icons
                                                        .star_border_rounded,
                                              color:
                                                  CerclyColors.blue,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _procesando
                                                ? null
                                                : () => _eliminar(
                                                    foto,
                                                  ),
                                            tooltip: 'Eliminar',
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _procesando
                                  ? null
                                  : () => _seleccionarFotos(fotos),
                              style: FilledButton.styleFrom(
                                backgroundColor: CerclyColors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(15),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_photo_alternate_rounded,
                              ),
                              label: const Text(
                                'Seleccionar fotografías',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_procesando)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x33031A3A),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
