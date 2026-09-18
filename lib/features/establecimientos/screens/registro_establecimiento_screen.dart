import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../models/establecimiento_model.dart';
import '../models/turno_horario.dart';
import '../services/establecimiento_service.dart';
import 'seleccionar_ubicacion_establecimiento_screen.dart';

class RegistroEstablecimientoScreen extends StatefulWidget {
  const RegistroEstablecimientoScreen({super.key});

  @override
  State<RegistroEstablecimientoScreen> createState() =>
      _RegistroEstablecimientoScreenState();
}

class _RegistroEstablecimientoScreenState
    extends State<RegistroEstablecimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = EstablecimientoService();
  final _ubicacionService = GeolocatorUbicacionService();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _categoriasFuture;

  String? _categoriaId;
  double? _latitudSeleccionada;
  double? _longitudSeleccionada;
  String? _origenUbicacion;
  bool _guardando = false;
  bool _obteniendoUbicacion = false;

  @override
  void initState() {
    super.initState();
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

  Map<String, List<TurnoHorario>> _crearHorarioInicial() {
    return {
      for (final dia in EstablecimientoModel.diasSemana) dia: <TurnoHorario>[],
    };
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
        ),
      ),
    );

    if (!mounted || ubicacion == null) return;

    _establecerUbicacion(ubicacion, 'Seleccionada en el mapa');
  }

  Future<void> _guardar() async {
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

    final usuario = Supabase.instance.client.auth.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión nuevamente.')),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final establecimiento = EstablecimientoModel(
        id: '',
        propietarioId: usuario.id,
        nombre: _nombreController.text,
        descripcion: _descripcionController.text,
        categoriaId: _categoriaId!,
        direccion: _direccionController.text,
        latitud: latitud,
        longitud: longitud,
        telefonoPublico: _telefonoController.text,
        horario: _crearHorarioInicial(),
        zonaHoraria: 'America/Guayaquil',
      );

      await _service.crear(establecimiento);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Establecimiento enviado para revisión correctamente.'),
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
      appBar: AppBar(title: const Text('Registrar establecimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Información del establecimiento',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El establecimiento será revisado antes de aparecer '
                  'públicamente en Cercly.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validarNombre,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLength: 1000,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cargando categorías...'),
                          SizedBox(height: 8),
                          LinearProgressIndicator(),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'No se pudieron cargar las categorías.',
                            style: TextStyle(color: Colors.red),
                          ),
                          TextButton(
                            onPressed: _reintentarCategorias,
                            child: const Text('Reintentar'),
                          ),
                        ],
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
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: categorias.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria['id'] as String,
                          child: Text(categoria['nombre'] as String),
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
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLength: 250,
                  textInputAction: TextInputAction.next,
                  validator: _validarObligatorio,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono público (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ubicación del negocio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Indica dónde se encuentra el establecimiento. Puedes usar '
                  'el GPS si estás en el negocio o marcar el punto directamente '
                  'en el mapa.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _guardando || _obteniendoUbicacion
                        ? null
                        : _usarUbicacionActual,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1769FF),
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
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _guardando ? null : _seleccionarEnMapa,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1769FF),
                      side: const BorderSide(
                        color: Color(0xFF1769FF),
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
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (_latitudSeleccionada != null &&
                    _longitudSeleccionada != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFD8FF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1769FF),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ubicación seleccionada',
                                style: TextStyle(
                                  color: Color(0xFF102A56),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _origenUbicacion ?? 'Lista para guardar',
                                style: const TextStyle(
                                  color: Color(0xFF526B91),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ver o cambiar ubicación',
                          onPressed: _guardando ? null : _seleccionarEnMapa,
                          icon: const Icon(
                            Icons.edit_location_alt_rounded,
                            color: Color(0xFF1769FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Enviar para revisión',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
