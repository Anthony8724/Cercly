import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_model.dart';
import '../services/establecimiento_service.dart';

class EditarInformacionEstablecimientoScreen extends StatefulWidget {
  const EditarInformacionEstablecimientoScreen({
    required this.establecimiento,
    super.key,
  });

  final EstablecimientoModel establecimiento;

  @override
  State<EditarInformacionEstablecimientoScreen> createState() =>
      _EditarInformacionEstablecimientoScreenState();
}

class _EditarInformacionEstablecimientoScreenState
    extends State<EditarInformacionEstablecimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = EstablecimientoService();

  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _direccionController;
  late final TextEditingController _telefonoController;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final establecimiento = widget.establecimiento;
    _nombreController = TextEditingController(text: establecimiento.nombre);
    _descripcionController = TextEditingController(
      text: establecimiento.descripcion,
    );
    _direccionController = TextEditingController(
      text: establecimiento.direccion,
    );
    _telefonoController = TextEditingController(
      text: establecimiento.telefonoPublico,
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  String? _validarNombre(String? valor) {
    final texto = valor?.trim() ?? '';

    if (texto.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }

    if (texto.length > 120) {
      return 'El nombre no puede superar 120 caracteres';
    }

    return null;
  }

  String? _validarDireccion(String? valor) {
    final texto = valor?.trim() ?? '';

    if (texto.isEmpty) {
      return 'La dirección es obligatoria';
    }

    if (texto.length > 250) {
      return 'La dirección no puede superar 250 caracteres';
    }

    return null;
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final actual = widget.establecimiento;
      final actualizado = EstablecimientoModel(
        id: actual.id,
        propietarioId: actual.propietarioId,
        nombre: _nombreController.text,
        descripcion: _descripcionController.text,
        categoriaId: actual.categoriaId,
        direccion: _direccionController.text,
        latitud: actual.latitud,
        longitud: actual.longitud,
        telefonoPublico: _telefonoController.text,
        horario: actual.horario,
        zonaHoraria: actual.zonaHoraria,
        estado: actual.estado,
      );

      await _service.actualizarInformacion(actualizado);

      if (!mounted) {
        return;
      }

      final mensaje = actual.estado == 'aprobado'
          ? 'Información actualizada y enviada nuevamente a revisión.'
          : 'Información actualizada correctamente.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: ${error.message}')),
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
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
    final requiereRevision = widget.establecimiento.estado == 'aprobado';

    return Scaffold(
      appBar: AppBar(title: const Text('Información del establecimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.establecimiento.nombre,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Edita la información pública principal de tu establecimiento.',
                ),
                if (requiereRevision) ...[
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Al guardar cambios en un establecimiento aprobado, '
                              'volverá a estado pendiente para revisión.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('editar-establecimiento-nombre'),
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  validator: _validarNombre,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('editar-establecimiento-descripcion'),
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLength: 1000,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('editar-establecimiento-direccion'),
                  controller: _direccionController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  maxLength: 250,
                  textInputAction: TextInputAction.next,
                  validator: _validarDireccion,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('editar-establecimiento-telefono'),
                  controller: _telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono público (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                const Text(
                  'La categoría, ubicación y horarios se administran desde sus '
                  'secciones correspondientes.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('guardar-informacion-establecimiento'),
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
