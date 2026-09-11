import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/turno_horario.dart';
import '../models/establecimiento_model.dart';
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

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _latitudController = TextEditingController();
  final _longitudController = TextEditingController();

  final _service = EstablecimientoService();

  String? _categoriaId;
  bool _guardando = false;

  static const _categorias = {
    'restaurantes': 'Restaurante',
    'cafeterias': 'Cafetería',
    'tiendas': 'Tienda',
    'minimarkets': 'Minimarket',
    'otros': 'Otro',
  };

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

  Map<String, List<TurnoHorario>> _horarioVacio() {
    return {
      for (final dia in EstablecimientoModel.diasSemana) dia: <TurnoHorario>[],
    };
  }

  double? _convertirCoordenada(String texto) {
    return double.tryParse(texto.trim().replaceAll(',', '.'));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final usuario = FirebaseAuth.instance.currentUser;
    final latitud = _convertirCoordenada(_latitudController.text);
    final longitud = _convertirCoordenada(_longitudController.text);

    if (usuario == null || latitud == null || longitud == null) {
      return;
    }

    setState(() => _guardando = true);

    try {
      final establecimiento = EstablecimientoModel(
        id: usuario.uid,
        propietarioId: usuario.uid,
        nombre: _nombreController.text,
        descripcion: _descripcionController.text,
        categoriaId: _categoriaId!,
        direccion: _direccionController.text,
        ubicacion: GeoPoint(latitud, longitud),
        telefonoPublico: _telefonoController.text,
        horario: _horarioVacio(),
        zonaHoraria: 'America/Guayaquil',
      );

      await _service.crear(establecimiento);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Establecimiento guardado correctamente.'),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: ${error.message ?? error.code}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error al guardar el establecimiento.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  String? _validarObligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    return null;
  }

  String? _validarLatitud(String? valor) {
    final numero = _convertirCoordenada(valor ?? '');

    if (numero == null || numero < -90 || numero > 90) {
      return 'Ingresa una latitud válida entre -90 y 90.';
    }

    return null;
  }

  String? _validarLongitud(String? valor) {
    final numero = _convertirCoordenada(valor ?? '');

    if (numero == null || numero < -180 || numero > 180) {
      return 'Ingresa una longitud válida entre -180 y 180.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar establecimiento')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Información del negocio',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('El establecimiento quedará pendiente de revisión.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del establecimiento',
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                ),
                maxLength: 120,
                validator: _validarObligatorio,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLength: 1000,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoriaId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: _categorias.entries
                    .map(
                      (categoria) => DropdownMenuItem(
                        value: categoria.key,
                        child: Text(categoria.value),
                      ),
                    )
                    .toList(),
                onChanged: (valor) {
                  setState(() => _categoriaId = valor);
                },
                validator: (valor) {
                  if (valor == null) {
                    return 'Selecciona una categoría.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLength: 250,
                validator: _validarObligatorio,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono público (opcional)',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 20,
              ),
              const SizedBox(height: 8),
              Text(
                'Ubicación',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Por ahora ingresa las coordenadas. Más adelante se '
                'seleccionarán directamente desde el mapa.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _latitudController,
                decoration: const InputDecoration(
                  labelText: 'Latitud',
                  hintText: 'Ejemplo: 0.8119',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _validarLatitud,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitudController,
                decoration: const InputDecoration(
                  labelText: 'Longitud',
                  hintText: 'Ejemplo: -77.7173',
                  border: OutlineInputBorder(),
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
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _guardando ? 'Guardando...' : 'Guardar establecimiento',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
