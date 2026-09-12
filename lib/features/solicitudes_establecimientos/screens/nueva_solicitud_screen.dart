import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../services/solicitud_establecimiento_service.dart';

class NuevaSolicitudScreen extends StatefulWidget {
  const NuevaSolicitudScreen({super.key});

  @override
  State<NuevaSolicitudScreen> createState() => _NuevaSolicitudScreenState();
}

class _NuevaSolicitudScreenState extends State<NuevaSolicitudScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mensajeController = TextEditingController();
  final SolicitudEstablecimientoService _service =
      SolicitudEstablecimientoService();

  late Future<List<EstablecimientoSolicitudOpcion>> _establecimientosFuture;

  String? _establecimientoId;
  String _tipo = SolicitudEstablecimientoModel.tipoReclamar;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarEstablecimientos();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  void _cargarEstablecimientos() {
    _establecimientosFuture = _service.listarEstablecimientosAprobados();
  }

  void _recargar() {
    setState(_cargarEstablecimientos);
  }

  String _descripcionTipo(String tipo) {
    switch (tipo) {
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'Solicita permiso para colaborar en la administración '
            'del establecimiento.';
      case SolicitudEstablecimientoModel.tipoCorreccion:
        return 'Informa datos incorrectos que deben ser revisados.';
      default:
        return 'Solicita convertirte en el propietario principal '
            'del establecimiento.';
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      await _service.crear(
        establecimientoId: _establecimientoId!,
        tipo: _tipo,
        mensaje: _mensajeController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada correctamente.')),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      final mensaje = error.code == '23505'
          ? 'Ya tienes una solicitud pendiente de este tipo '
                'para el establecimiento.'
          : 'Supabase rechazó la solicitud: ${error.message}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: SafeArea(
        child: FutureBuilder<List<EstablecimientoSolicitudOpcion>>(
          future: _establecimientosFuture,
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
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No se pudieron cargar los establecimientos.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _recargar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final establecimientos =
                snapshot.data ?? <EstablecimientoSolicitudOpcion>[];

            if (establecimientos.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'No hay establecimientos aprobados disponibles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Solicitud sobre un establecimiento',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona el establecimiento y explica '
                      'claramente lo que necesitas.',
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Establecimiento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.storefront),
                      ),
                      items: establecimientos.map((establecimiento) {
                        return DropdownMenuItem<String>(
                          value: establecimiento.id,
                          child: Text(
                            establecimiento.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _guardando
                          ? null
                          : (valor) {
                              setState(() {
                                _establecimientoId = valor;
                              });
                            },
                      validator: (valor) {
                        if (valor == null || valor.isEmpty) {
                          return 'Selecciona un establecimiento.';
                        }

                        return null;
                      },
                    ),
                    if (_establecimientoId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        establecimientos
                            .firstWhere(
                              (establecimiento) =>
                                  establecimiento.id == _establecimientoId,
                            )
                            .direccion,
                      ),
                    ],
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de solicitud',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      items: SolicitudEstablecimientoModel.tiposPermitidos.map((
                        tipo,
                      ) {
                        return DropdownMenuItem<String>(
                          value: tipo,
                          child: Text(_etiquetaTipo(tipo)),
                        );
                      }).toList(),
                      onChanged: _guardando
                          ? null
                          : (valor) {
                              if (valor == null) {
                                return;
                              }

                              setState(() {
                                _tipo = valor;
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_descripcionTipo(_tipo))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _mensajeController,
                      enabled: !_guardando,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Explicación de la solicitud',
                        hintText:
                            'Describe el motivo y proporciona '
                            'información que permita verificarlo.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (valor) {
                        final texto = valor?.trim() ?? '';

                        if (texto.isEmpty) {
                          return 'Escribe una explicación.';
                        }

                        if (texto.length < 10) {
                          return 'La explicación debe tener '
                              'al menos 10 caracteres.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _enviar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _guardando ? 'Enviando...' : 'Enviar solicitud',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _etiquetaTipo(String tipo) {
    switch (tipo) {
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'Solicitar acceso';
      case SolicitudEstablecimientoModel.tipoCorreccion:
        return 'Corregir información';
      default:
        return 'Reclamar establecimiento';
    }
  }
}
