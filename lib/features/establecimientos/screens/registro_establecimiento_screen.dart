import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';

import '../../../sky/sky_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../services/establecimiento_service.dart';
import 'seleccionar_ubicacion_establecimiento_screen.dart';
import '../../solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import '../../solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import '../models/establecimiento_model.dart';
import '../models/turno_horario.dart';

typedef EnviarSolicitudDemoLocal = Future<String> Function({
  required String nombre,
  required String categoriaId,
  required String descripcion,
  required String direccion,
  required String telefono,
  required double latitud,
  required double longitud,
  List<Map<String, dynamic>> horarios,
});

class RegistroEstablecimientoScreen extends StatefulWidget {
  const RegistroEstablecimientoScreen({
    super.key,
    this.service,
    this.soloEvaluacion = false,
    this.enviarSolicitudDemoLocal,
    this.mostrarTiles = true,
  });

  final RegistroEstablecimientoRepository? service;
  final bool soloEvaluacion;
  final EnviarSolicitudDemoLocal? enviarSolicitudDemoLocal;
  final bool mostrarTiles;

  @override
  State<RegistroEstablecimientoScreen> createState() =>
      _RegistroEstablecimientoScreenState();
}

class _RegistroEstablecimientoScreenState
    extends State<RegistroEstablecimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final RegistroEstablecimientoRepository _service;
  final _ubicacionService = GeolocatorUbicacionService();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _categoriasFuture;

  String? _categoriaId;
  final Map<int, TurnoHorario?> _horariosSemana = {
    for (var dia = 1; dia <= 7; dia++) dia: null,
  };
  double? _latitudSeleccionada;
  double? _longitudSeleccionada;
  String? _origenUbicacion;
  bool _guardando = false;
  bool _obteniendoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EstablecimientoService();
    _categoriasFuture = _service.listarCategoriasActivas();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  String? _validarObligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }

    return null;
  }

  String? _validarNombre(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa el nombre del establecimiento';
    }

    if (valor.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }

    if (valor.trim().length > 120) {
      return 'El nombre no puede superar 120 caracteres';
    }

    return null;
  }

  List<Map<String, dynamic>> _horariosParaSolicitud() => [
    for (final entrada in _horariosSemana.entries)
      if (entrada.value != null)
        {
          'dia_semana': entrada.key,
          'apertura_minutos': entrada.value!.aperturaMinutos,
          'cierre_minutos': entrada.value!.cierreMinutos,
          'cierra_al_dia_siguiente': entrada.value!.cierraAlDiaSiguiente,
        },
  ];

  Future<void> _editarHora(int dia, bool apertura) async {
    final actual = _horariosSemana[dia];
    if (actual == null) return;
    final minutos = apertura ? actual.aperturaMinutos : actual.cierreMinutos;
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60),
    );
    if (!mounted || elegida == null) return;
    final nuevoMinuto = elegida.hour * 60 + elegida.minute;
    final nuevoInicio = apertura ? nuevoMinuto : actual.aperturaMinutos;
    final nuevoCierre = apertura ? actual.cierreMinutos : nuevoMinuto;
    if (nuevoCierre <= nuevoInicio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El cierre debe ser posterior a la apertura.'),
        ),
      );
      return;
    }
    setState(() {
      _horariosSemana[dia] = TurnoHorario(
        aperturaMinutos: nuevoInicio,
        cierreMinutos: nuevoCierre,
      );
    });
  }

  String _hora(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

  Widget _filaHorario(int dia, String codigo) {
    const nombres = {
      'lunes': 'Lunes',
      'martes': 'Martes',
      'miercoles': 'Miércoles',
      'jueves': 'Jueves',
      'viernes': 'Viernes',
      'sabado': 'Sábado',
      'domingo': 'Domingo',
    };
    final turno = _horariosSemana[dia];
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(nombres[codigo] ?? codigo),
            subtitle: Text(turno == null ? 'Cerrado / sin horario' : 'Abierto'),
            value: turno != null,
            onChanged: _guardando
                ? null
                : (abierto) => setState(() {
                    _horariosSemana[dia] = abierto
                        ? TurnoHorario(
                            aperturaMinutos: 540,
                            cierreMinutos: 1020,
                          )
                        : null;
                  }),
          ),
        ),
        if (turno != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardando ? null : () => _editarHora(dia, true),
                    child: Text('Abre ${_hora(turno.aperturaMinutos)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardando
                        ? null
                        : () => _editarHora(dia, false),
                    child: Text('Cierra ${_hora(turno.cierreMinutos)}'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _establecerUbicacion(UbicacionUsuario ubicacion, String origen) {
    setState(() {
      _latitudSeleccionada = ubicacion.latitud;
      _longitudSeleccionada = ubicacion.longitud;
      _origenUbicacion = origen;
    });
  }

  Future<void> _usarUbicacionActual() async {
    if (_guardando || _obteniendoUbicacion) return;

    setState(() {
      _obteniendoUbicacion = true;
    });

    final resultado = await _ubicacionService.obtenerUbicacion();

    if (!mounted) return;

    setState(() {
      _obteniendoUbicacion = false;
    });

    final ubicacion = resultado.ubicacion;
    if (ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado.mensaje ?? 'No pudimos obtener tu ubicación. Puedes seleccionarla en el mapa.',
          ),
        ),
      );
      return;
    }

    _establecerUbicacion(ubicacion, 'Ubicación actual');
  }

  Future<void> _seleccionarEnMapa() async {
    if (_guardando) return;

    final ubicacion = await Navigator.of(context).push<UbicacionUsuario>(
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionEstablecimientoScreen(
          latitudInicial: _latitudSeleccionada,
          longitudInicial: _longitudSeleccionada,
          mostrarTiles: widget.mostrarTiles,
        ),
      ),
    );

    if (!mounted || ubicacion == null) return;

    _establecerUbicacion(ubicacion, 'Seleccionada en el mapa');
  }

  Future<void> _guardar() async {
    if (widget.soloEvaluacion && widget.enviarSolicitudDemoLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay un repositorio local de demo disponible.'),
        ),
      );
      return;
    }
    if (_guardando || !_formKey.currentState!.validate()) {
      return;
    }

    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría.')),
      );
      return;
    }

    final latitud = _latitudSeleccionada;
    final longitud = _longitudSeleccionada;
    if (latitud == null || longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la ubicación del establecimiento.'),
        ),
      );
      return;
    }

    if (!widget.soloEvaluacion) {
      final usuario = Supabase.instance.client.auth.currentUser;
      if (usuario == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión nuevamente.')),
        );
        return;
      }
    }

    setState(() {
      _guardando = true;
    });

    try {
      final coincidencias = await _service.buscarCoincidenciasCercanas(
        nombre: _nombreController.text,
        latitud: latitud,
        longitud: longitud,
      );
      if (!mounted) return;
      if (coincidencias.isNotEmpty) {
        final decision = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('¿Ya aparece en Cercly?'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Encontramos negocios cercanos con nombres similares. Revisa si alguno corresponde a este negocio.',
                    ),
                    const SizedBox(height: 12),
                    for (final coincidencia in coincidencias) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(coincidencia['nombre'] as String),
                        subtitle: Text(
                          '${coincidencia['direccion']} · ${(coincidencia['distancia_metros'] as double).round()} m',
                        ),
                      ),
                      if (coincidencia['fuente'] == 'osm' &&
                          coincidencia['estado_reclamo'] == 'no_reclamado' &&
                          coincidencia['propietario_id'] == null)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop({
                            'accion': 'reclamar',
                            'id': coincidencia['id'],
                          }),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Reclamar este establecimiento'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Revisar después'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop({'accion': 'continuar'}),
                child: const Text('Es otro negocio, continuar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (decision?['accion'] == 'reclamar') {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => NuevaSolicitudScreen(
                tipoInicial: SolicitudEstablecimientoModel.tipoReclamar,
                establecimientoIdInicial: decision!['id'] as String,
                bloquearTipo: true,
              ),
            ),
          );
          return;
        }
        if (decision?['accion'] != 'continuar') return;
      }

      final horarios = _horariosParaSolicitud();
      if (widget.soloEvaluacion) {
        await widget.enviarSolicitudDemoLocal!(
          nombre: _nombreController.text,
          descripcion: _descripcionController.text,
          categoriaId: _categoriaId!,
          direccion: _direccionController.text,
          telefono: _telefonoController.text,
          latitud: latitud,
          longitud: longitud,
          horarios: horarios,
        );
      } else {
        await _service.crearSolicitudRegistro(
          nombre: _nombreController.text,
          descripcion: _descripcionController.text,
          categoriaId: _categoriaId!,
          direccion: _direccionController.text,
          telefono: _telefonoController.text,
          latitud: latitud,
          longitud: longitud,
          horarios: horarios,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.soloEvaluacion
                ? 'Solicitud simulada en memoria local. No se envió a Cercly ni a Supabase.'
                : 'Establecimiento enviado para revisión correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar el establecimiento: ${error.message}',
          ),
        ),
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado al guardar.'),
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

  void _reintentarCategorias() {
    setState(() {
      _categoriasFuture = _service.listarCategoriasActivas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkyPalette.of(context).background,
      body: SkySurface(
        child: Column(
          children: [
            CerclyPageHeader(
              title: 'Registrar establecimiento',
              subtitle: 'Envía tu negocio para revisión',
              icon: Icons.add_business_rounded,
              onBack: () => Navigator.of(context).maybePop(),
              compact: true,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CerclyInfoBanner(
                          text: widget.soloEvaluacion
                              ? 'MODO DEMO: la solicitud se simula solo en la memoria de esta app; no se contacta con Cercly ni Supabase.'
                              : 'El establecimiento será revisado antes de aparecer públicamente en Cercly.',
                          icon: Icons.verified_user_outlined,
                        ),
                        const SizedBox(height: 16),
                        CerclySectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const CerclySectionTitle(
                                title: 'Información del establecimiento',
                                subtitle: 'Completa los datos que verán tus futuros clientes.',
                                icon: Icons.storefront_rounded,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _nombreController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre comercial (obligatorio)',
                                  prefixIcon: Icon(Icons.store_rounded),
                                ),
                                textInputAction: TextInputAction.next,
                                scrollPadding: const EdgeInsets.all(24),
                                validator: _validarNombre,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descripcionController,
                                decoration: const InputDecoration(
                                  labelText: 'Descripción (opcional)',
                                  prefixIcon: Icon(Icons.description_rounded),
                                ),
                                maxLength: 1000,
                                maxLines: 4,
                                scrollPadding: const EdgeInsets.all(24),
                              ),
                              const SizedBox(height: 16),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _categoriasFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cargando categorías...',
                                          style: TextStyle(
                                            color: SkyPalette.of(context).muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        LinearProgressIndicator(),
                                      ],
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3F2),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFFFD5D0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'No se pudieron cargar las categorías.',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _reintentarCategorias,
                                            child: const Text('Reintentar'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final categorias =
                                      snapshot.data ?? <Map<String, dynamic>>[];

                                  if (categorias.isEmpty) {
                                    return const Text(
                                      'No existen categorías disponibles.',
                                      style: TextStyle(color: Colors.red),
                                    );
                                  }

                                  return DropdownButtonFormField<String>(
                                    initialValue: _categoriaId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Categoría (obligatoria)',
                                      prefixIcon: Icon(Icons.category_rounded),
                                    ),
                                    items: categorias.map((categoria) {
                                      return DropdownMenuItem<String>(
                                        value: categoria['id'] as String,
                                        child: Text(
                                          categoria['nombre'] as String,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _guardando
                                        ? null
                                        : (valor) {
                                            setState(() {
                                              _categoriaId = valor;
                                            });
                                          },
                                    validator: (valor) {
                                      if (valor == null || valor.isEmpty) {
                                        return 'Selecciona una categoría';
                                      }
                                      return null;
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _direccionController,
                                decoration: const InputDecoration(
                                  labelText: 'Dirección (obligatoria)',
                                  prefixIcon: Icon(Icons.location_on_rounded),
                                  helperText: 'Referencia: Bolívar y Sucre, junto al parque',
                                  helperMaxLines: 2,
                                ),
                                maxLength: 250,
                                textInputAction: TextInputAction.next,
                                scrollPadding: const EdgeInsets.all(24),
                                validator: _validarObligatorio,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _telefonoController,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono público (opcional)',
                                  prefixIcon: Icon(Icons.phone_rounded),
                                ),
                                maxLength: 20,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                scrollPadding: const EdgeInsets.all(24),
                              ),
                              const SizedBox(height: 18),
                              const CerclySectionTitle(
                                title: 'Horarios (opcional)',
                                subtitle: 'Añade los días y horas de atención si ya los conoces.',
                                icon: Icons.schedule_rounded,
                              ),
                              const SizedBox(height: 8),
                              for (
                                var indice = 0;
                                indice < EstablecimientoModel.diasSemana.length;
                                indice++
                              )
                                _filaHorario(
                                  indice + 1,
                                  EstablecimientoModel.diasSemana[indice],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        CerclySectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const CerclySectionTitle(
                                title: 'Ubicación del negocio',
                                subtitle: 'Ubica el negocio en el mapa. El GPS es opcional y solo sirve como referencia.',
                                icon: Icons.location_on_rounded,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _guardando || _obteniendoUbicacion
                                      ? null
                                      : _usarUbicacionActual,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: SkyPalette.of(context)
                                        .primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: _obteniendoUbicacion
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.my_location_rounded),
                                  label: Text(
                                    _obteniendoUbicacion
                                        ? 'Buscando ubicación...'
                                        : 'Usar mi ubicación actual',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _guardando
                                      ? null
                                      : _seleccionarEnMapa,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: SkyPalette.of(context)
                                        .primary,
                                    side: BorderSide(
                                      color: SkyPalette.of(context).primary,
                                      width: 1.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.map_rounded),
                                  label: Text(
                                    _latitudSeleccionada == null
                                        ? 'Seleccionar en el mapa'
                                        : 'Cambiar ubicación en el mapa',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              if (_latitudSeleccionada != null &&
                                  _longitudSeleccionada != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: SkyPalette.of(context).soft,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFBFD8FF),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: SkyPalette.of(context).primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ubicación seleccionada',
                                              style: TextStyle(
                                                color: SkyPalette.of(context)
                                                    .text,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _origenUbicacion ??
                                                  'Lista para guardar',
                                              style: TextStyle(
                                                color: SkyPalette.of(context)
                                                    .muted,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Ver o cambiar ubicación',
                                        onPressed: _guardando
                                            ? null
                                            : _seleccionarEnMapa,
                                        icon: Icon(
                                          Icons.edit_location_alt_rounded,
                                          color: SkyPalette.of(context).primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            key: const Key('enviar-solicitud-establecimiento'),
                            onPressed:
                                _guardando ||
                                    (widget.soloEvaluacion &&
                                        widget.enviarSolicitudDemoLocal == null)
                                ? null
                                : _guardar,
                            style: FilledButton.styleFrom(
                              backgroundColor: SkyPalette.of(context).primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: _guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _guardando
                                  ? 'Guardando...'
                                  : widget.soloEvaluacion
                                  ? 'Simular solicitud local'
                                  : 'Enviar para revisión',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
