import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';

import '../../../sky/sky_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../widgets/selector_establecimiento.dart';
import '../widgets/proponer_correccion.dart';
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
  EstablecimientoSolicitudOpcion? _seleccion;
  List<EstablecimientoSolicitudOpcion> _asociados = [];
  int _versionCarga = 0;
  bool _destinoNoDisponible = false;
  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)>? _datosCorreccion;
  Map<String, dynamic> _cambios = {};
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
    _establecimientosFuture = _cargarOpciones();
  }

  Future<List<EstablecimientoSolicitudOpcion>> _cargarOpciones() async {
    final version = ++_versionCarga;
    final tipo = _tipo;
    final id = _establecimientoId;
    final asociados = await _service.listarAsociadosParaTipo(tipo);
    final opciones =
        tipo == SolicitudEstablecimientoModel.tipoCorreccion &&
            (id == null || !asociados.any((e) => e.id == id))
        ? <EstablecimientoSolicitudOpcion>[]
        : await _service.listarEstablecimientosParaTipo(tipo, id: id);
    if (!mounted || version != _versionCarga) return [];
    _asociados = asociados;
    final candidatos = {
      for (final e in [...asociados, ...opciones]) e.id: e,
    };
    _seleccion = id != null
        ? {for (final e in opciones) e.id: e}[id]
        : asociados.length == 1
        ? asociados.single
        : null;
    _destinoNoDisponible = id != null && _seleccion == null;
    _establecimientoId = _seleccion?.id;
    _cargarDatosCorreccion();
    return candidatos.values.toList();
  }

  Future<void> _elegirEstablecimiento() async {
    final seleccionado =
        await showModalBottomSheet<EstablecimientoSolicitudOpcion>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => SelectorEstablecimiento(
            service: _service,
            tipo: _tipo,
            asociados: _asociados,
          ),
        );
    if (!mounted || seleccionado == null) return;
    setState(() {
      _seleccion = seleccionado;
      _destinoNoDisponible = false;
      _establecimientoId = seleccionado.id;
      _cargarDatosCorreccion();
    });
  }

  void _recargar() {
    setState(_cargarEstablecimientos);
  }

  void _cambiarTipo(String tipo) {
    setState(() {
      _tipo = tipo;
      _establecimientoId = null;
      _seleccion = null;
      _destinoNoDisponible = false;
      _datosCorreccion = null;
      _cambios = {};
      _cargarEstablecimientos();
    });
  }

  void _cargarDatosCorreccion() {
    _cambios = {};
    _datosCorreccion =
        _tipo == SolicitudEstablecimientoModel.tipoCorreccion &&
            _establecimientoId != null
        ? Future.wait<dynamic>([
            _service.datosParaCorreccion(_establecimientoId!),
            _service.categoriasParaCorreccion(),
          ]).then(
            (r) => (
              r[0] as Map<String, dynamic>,
              r[1] as List<Map<String, dynamic>>,
            ),
          )
        : null;
  }

  String get _mensajeSinResultados {
    switch (_tipo) {
      case SolicitudEstablecimientoModel.tipoReclamar:
        return 'No hay establecimientos OSM disponibles para reclamar.';
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'No hay establecimientos administrados disponibles.';
      default:
        return 'No tienes negocios asociados disponibles para corregir.';
    }
  }

  String _descripcionTipo(String tipo) {
    switch (tipo) {
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'Solicita permiso para colaborar en la administración '
            'del establecimiento.';
      case SolicitudEstablecimientoModel.tipoCorreccion:
        return 'Selecciona cada dato y escribe su valor propuesto. El administrador solo podrá aprobar o rechazar esos cambios.';
      default:
        return 'Solicita convertirte en el propietario principal '
            'del establecimiento.';
    }
  }

  Future<void> _enviar() async {
    if (_tipo == SolicitudEstablecimientoModel.tipoCorreccion &&
        (_datosCorreccion == null || _cambios.isEmpty)) {
      _formKey.currentState!.validate();
      return;
    }
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
        cambios: _tipo == SolicitudEstablecimientoModel.tipoCorreccion
            ? _cambios
            : null,
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
      backgroundColor: SkyPalette.of(context).background,
      body: SkySurface(
        child: Column(
          children: [
            CerclyPageHeader(
              title: 'Nueva solicitud',
              subtitle: 'Solicita acceso, reclama un establecimiento o informa una corrección',
              icon: Icons.assignment_rounded,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: FutureBuilder<List<EstablecimientoSolicitudOpcion>>(
                  future: _establecimientosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
                                Text(
                                  'No se pudieron cargar los establecimientos.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: SkyPalette.of(context).text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: SkyPalette.of(context).muted,
                                  ),
                                ),
                                const SizedBox(height: 16),
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

                    final establecimientos =
                        snapshot.data ?? <EstablecimientoSolicitudOpcion>[];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const CerclyInfoBanner(
                              text: 'Selecciona el establecimiento y explica claramente lo que necesitas para que pueda revisarse.',
                              icon: Icons.info_outline_rounded,
                            ),
                            const SizedBox(height: 16),
                            if (_destinoNoDisponible) ...[
                              const CerclyInfoBanner(
                                text: 'El establecimiento de origen no está disponible para esta solicitud. Puedes buscar otro.',
                                icon: Icons.info_outline,
                              ),
                              const SizedBox(height: 16),
                            ],
                            CerclySectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const CerclySectionTitle(
                                    title: 'Datos de la solicitud',
                                    subtitle: 'Elige el establecimiento y el tipo de solicitud.',
                                    icon: Icons.assignment_rounded,
                                  ),
                                  const SizedBox(height: 20),
                                  if (establecimientos.isEmpty) ...[
                                    CerclyInfoBanner(
                                      text: _mensajeSinResultados,
                                      icon: Icons.storefront_outlined,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  FormField<String>(
                                    key: ValueKey(
                                      'seleccion-$_establecimientoId',
                                    ),
                                    initialValue: _establecimientoId,
                                    validator: (id) => id == null
                                        ? 'Selecciona un establecimiento.'
                                        : null,
                                    builder: (field) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: ListTile(
                                            key: const Key(
                                              'elegir-establecimiento',
                                            ),
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.storefront_outlined,
                                            ),
                                            title: Text(
                                              _seleccion?.nombre ??
                                                  'Buscar establecimiento',
                                            ),
                                            subtitle: Text(
                                              _seleccion?.direccion ?? 'Busca por nombre y comprueba la dirección',
                                            ),
                                            trailing: const Icon(
                                              Icons.search_rounded,
                                            ),
                                            onTap: _guardando
                                                ? null
                                                : _elegirEstablecimiento,
                                          ),
                                        ),
                                        if (field.hasError)
                                          Text(
                                            field.errorText!,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _tipo,
                                    decoration: const InputDecoration(
                                      labelText: 'Tipo de solicitud',
                                      prefixIcon: Icon(Icons.category_rounded),
                                    ),
                                    items: SolicitudEstablecimientoModel
                                        .tiposPermitidos
                                        .where(
                                          (tipo) =>
                                              tipo !=
                                              SolicitudEstablecimientoModel
                                                  .tipoRegistro,
                                        )
                                        .map((tipo) {
                                          return DropdownMenuItem<String>(
                                            value: tipo,
                                            child: Text(
                                              _etiquetaTipo(tipo),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        })
                                        .toList(),
                                    onChanged: _guardando || widget.bloquearTipo
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
                                    icon: Icons.lightbulb_outline_rounded,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_tipo ==
                                    SolicitudEstablecimientoModel
                                        .tipoCorreccion &&
                                _datosCorreccion != null) ...[
                              FutureBuilder<
                                (
                                  Map<String, dynamic>,
                                  List<Map<String, dynamic>>,
                                )
                              >(
                                future: _datosCorreccion,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Column(
                                      children: [
                                        const Text(
                                          'No se pudieron cargar los datos actuales. No se enviará una corrección sin ellos.',
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              setState(_cargarDatosCorreccion),
                                          child: const Text('Reintentar'),
                                        ),
                                      ],
                                    );
                                  }
                                  return CerclySectionCard(
                                    child: ProponerCorreccion(
                                      key: ValueKey(
                                        'propuesta-$_establecimientoId',
                                      ),
                                      actuales: snapshot.data!.$1,
                                      categorias: snapshot.data!.$2,
                                      onChanged: (cambios) =>
                                          _cambios = cambios,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            CerclySectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const CerclySectionTitle(
                                    title: 'Explicación',
                                    subtitle: 'Describe el motivo con suficiente detalle para facilitar la revisión.',
                                    icon: Icons.chat_bubble_outline_rounded,
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _mensajeController,
                                    enabled: !_guardando,
                                    minLines: 4,
                                    maxLines: 7,
                                    maxLength: 1000,
                                    decoration: InputDecoration(
                                      labelText:
                                          _tipo ==
                                              SolicitudEstablecimientoModel
                                                  .tipoCorreccion
                                          ? 'Motivo (opcional)'
                                          : 'Explicación de la solicitud',
                                      hintText: 'Describe el motivo y proporciona información que permita verificarlo.',
                                      alignLabelWithHint: true,
                                      prefixIcon: Icon(Icons.edit_note_rounded),
                                    ),
                                    validator: (valor) {
                                      final texto = valor?.trim() ?? '';
                                      if (_tipo ==
                                          SolicitudEstablecimientoModel
                                              .tipoCorreccion) {
                                        return null;
                                      }
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
                                onPressed: _guardando ? null : _enviar,
                                style: FilledButton.styleFrom(
                                  backgroundColor: SkyPalette.of(context)
                                      .primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
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
