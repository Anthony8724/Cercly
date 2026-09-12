import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_model.dart';
import '../models/turno_horario.dart';
import '../services/establecimiento_service.dart';

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

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _latitudController = TextEditingController();
  final _longitudController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _categoriasFuture;

  String? _categoriaId;
  bool _guardando = false;

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
    _latitudController.dispose();
    _longitudController.dispose();
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

  String? _validarLatitud(String? valor) {
    final numero = double.tryParse(valor?.trim() ?? '');

    if (numero == null) {
      return 'Ingresa una latitud válida';
    }

    if (numero < -90 || numero > 90) {
      return 'La latitud debe estar entre -90 y 90';
    }

    return null;
  }

  String? _validarLongitud(String? valor) {
    final numero = double.tryParse(valor?.trim() ?? '');

    if (numero == null) {
      return 'Ingresa una longitud válida';
    }

    if (numero < -180 || numero > 180) {
      return 'La longitud debe estar entre -180 y 180';
    }

    return null;
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
        latitud: double.parse(_latitudController.text.trim()),
        longitud: double.parse(_longitudController.text.trim()),
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
                  'Ubicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Por ahora ingresa las coordenadas. Posteriormente '
                  'permitiremos seleccionarlas directamente en el mapa.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _latitudController,
                  decoration: const InputDecoration(
                    labelText: 'Latitud',
                    hintText: 'Ejemplo: 0.8119',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.my_location),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validarLatitud,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _longitudController,
                  decoration: const InputDecoration(
                    labelText: 'Longitud',
                    hintText: 'Ejemplo: -77.7173',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _validarLongitud,
                ),
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
