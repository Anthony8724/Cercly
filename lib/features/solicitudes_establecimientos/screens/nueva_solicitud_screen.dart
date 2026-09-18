import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../services/solicitud_establecimiento_service.dart';

class NuevaSolicitudScreen extends StatefulWidget {
  const NuevaSolicitudScreen({
    super.key,
    this.tipoInicial = SolicitudEstablecimientoModel.tipoReclamar,
    this.establecimientoIdInicial,
    this.bloquearTipo = false,
    this.service,
  });

  final String tipoInicial;
  final String? establecimientoIdInicial;
  final bool bloquearTipo;
  final SolicitudEstablecimientoRepository? service;

  @override
  State<NuevaSolicitudScreen> createState() => _NuevaSolicitudScreenState();
}

class _NuevaSolicitudScreenState extends State<NuevaSolicitudScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mensajeController = TextEditingController();
  late final SolicitudEstablecimientoRepository _service;

  late Future<List<EstablecimientoSolicitudOpcion>> _establecimientosFuture;

  String? _establecimientoId;
  late String _tipo;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SolicitudEstablecimientoService();
    _tipo = widget.tipoInicial;
    _establecimientoId = widget.establecimientoIdInicial;
    _cargarEstablecimientos();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  void _cargarEstablecimientos() {
    _establecimientosFuture = _service.listarEstablecimientosParaTipo(_tipo);
  }

  void _recargar() {
    setState(_cargarEstablecimientos);
  }

  void _cambiarTipo(String tipo) {
    setState(() {
      _tipo = tipo;
      _establecimientoId = null;
      _cargarEstablecimientos();
    });
  }

  String get _mensajeSinResultados {
    switch (_tipo) {
      case SolicitudEstablecimientoModel.tipoReclamar:
        return 'No hay establecimientos OSM disponibles para reclamar.';
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'No hay establecimientos administrados disponibles.';
      default:
        return 'No hay establecimientos públicos disponibles.';
    }
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
      backgroundColor: CerclyColors.background,
      body: Column(
        children: [
          CerclyPageHeader(
            title: 'Nueva solicitud',
            subtitle:
                'Solicita acceso, reclama un establecimiento o informa una corrección',
            icon: Icons.assignment_add_rounded,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: FutureBuilder<
                  List<EstablecimientoSolicitudOpcion>>(
                future: _establecimientosFuture,
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
                        padding: const EdgeInsets.all(20),
                        child: CerclySectionCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 52,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No se pudieron cargar los establecimientos.',
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
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                ),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final establecimientos =
                      snapshot.data ??
                      <EstablecimientoSolicitudOpcion>[];

                  if (establecimientos.isEmpty &&
                      widget.bloquearTipo) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: CerclySectionCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: const BoxDecoration(
                                  color: CerclyColors.softBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  size: 34,
                                  color: CerclyColors.blue,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _mensajeSinResultados,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: CerclyColors.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      28,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const CerclyInfoBanner(
                            text:
                                'Selecciona el establecimiento y explica claramente lo que necesitas para que pueda revisarse.',
                            icon: Icons.info_outline_rounded,
                          ),
                          const SizedBox(height: 16),
                          CerclySectionCard(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                const CerclySectionTitle(
                                  title: 'Datos de la solicitud',
                                  subtitle:
                                      'Elige el establecimiento y el tipo de solicitud.',
                                  icon: Icons.assignment_rounded,
                                ),
                                const SizedBox(height: 20),
                                if (establecimientos.isEmpty) ...[
                                  CerclyInfoBanner(
                                    text: _mensajeSinResultados,
                                    icon: Icons
                                        .storefront_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      establecimientos.any(
                                        (item) =>
                                            item.id ==
                                            _establecimientoId,
                                      )
                                      ? _establecimientoId
                                      : null,
                                  decoration:
                                      const InputDecoration(
                                    labelText: 'Establecimiento',
                                    prefixIcon: Icon(
                                      Icons.storefront_rounded,
                                    ),
                                  ),
                                  items: establecimientos
                                      .map((establecimiento) {
                                    return DropdownMenuItem<String>(
                                      value: establecimiento.id,
                                      child: Text(
                                        establecimiento.nombre,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged:
                                      _guardando ||
                                              establecimientos.isEmpty
                                          ? null
                                          : (valor) {
                                              setState(() {
                                                _establecimientoId =
                                                    valor;
                                              });
                                            },
                                  validator: (valor) {
                                    if (valor == null ||
                                        valor.isEmpty) {
                                      return 'Selecciona un establecimiento.';
                                    }
                                    return null;
                                  },
                                ),
                                if (_establecimientoId !=
                                    null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons
                                            .location_on_rounded,
                                        size: 17,
                                        color:
                                            CerclyColors.blue,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          establecimientos
                                              .firstWhere(
                                                (
                                                  establecimiento,
                                                ) =>
                                                    establecimiento
                                                        .id ==
                                                    _establecimientoId,
                                              )
                                              .direccion,
                                          style: const TextStyle(
                                            color:
                                                CerclyColors.muted,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 18),
                                DropdownButtonFormField<String>(
                                  initialValue: _tipo,
                                  decoration:
                                      const InputDecoration(
                                    labelText: 'Tipo de solicitud',
                                    prefixIcon: Icon(
                                      Icons.category_rounded,
                                    ),
                                  ),
                                  items:
                                      SolicitudEstablecimientoModel
                                          .tiposPermitidos
                                          .map((tipo) {
                                    return DropdownMenuItem<String>(
                                      value: tipo,
                                      child:
                                          Text(_etiquetaTipo(tipo)),
                                    );
                                  }).toList(),
                                  onChanged:
                                      _guardando ||
                                              widget.bloquearTipo
                                          ? null
                                          : (valor) {
                                              if (valor == null) {
                                                return;
                                              }
                                              _cambiarTipo(valor);
                                            },
                                ),
                                const SizedBox(height: 12),
                                CerclyInfoBanner(
                                  text: _descripcionTipo(_tipo),
                                  icon: Icons
                                      .lightbulb_outline_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          CerclySectionCard(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                const CerclySectionTitle(
                                  title: 'Explicación',
                                  subtitle:
                                      'Describe el motivo con suficiente detalle para facilitar la revisión.',
                                  icon: Icons
                                      .chat_bubble_outline_rounded,
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller:
                                      _mensajeController,
                                  enabled: !_guardando,
                                  minLines: 4,
                                  maxLines: 7,
                                  maxLength: 1000,
                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'Explicación de la solicitud',
                                    hintText:
                                        'Describe el motivo y proporciona información que permita verificarlo.',
                                    alignLabelWithHint: true,
                                    prefixIcon: Icon(
                                      Icons.edit_note_rounded,
                                    ),
                                  ),
                                  validator: (valor) {
                                    final texto =
                                        valor?.trim() ?? '';
                                    if (texto.isEmpty) {
                                      return 'Escribe una explicación.';
                                    }
                                    if (texto.length < 10) {
                                      return 'La explicación debe tener al menos 10 caracteres.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 54,
                            child: FilledButton.icon(
                              onPressed:
                                  _guardando ? null : _enviar,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    CerclyColors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                              ),
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                    ),
                              label: Text(
                                _guardando
                                    ? 'Enviando...'
                                    : 'Enviar solicitud',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
