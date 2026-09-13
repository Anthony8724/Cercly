import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../establecimientos/models/establecimiento_model.dart';
import '../models/promocion_model.dart';
import '../services/promocion_service.dart';

class RegistroPromocionScreen extends StatefulWidget {
  const RegistroPromocionScreen({required this.establecimiento, super.key});

  final EstablecimientoModel establecimiento;

  @override
  State<RegistroPromocionScreen> createState() =>
      _RegistroPromocionScreenState();
}

class _RegistroPromocionScreenState extends State<RegistroPromocionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = PromocionService();
  final _imagePicker = ImagePicker();

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _radioController = TextEditingController(text: '100');

  late DateTime _fechaInicio;
  late DateTime _fechaFin;

  XFile? _imagen;
  Uint8List? _imagenBytes;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    final ahora = DateTime.now();
    _fechaInicio = ahora;
    _fechaFin = ahora.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _radioController.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (fecha == null) {
      return;
    }

    setState(() {
      _fechaInicio = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );

      if (!_fechaFin.isAfter(_fechaInicio)) {
        _fechaFin = _fechaInicio.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin,
      firstDate: DateTime(
        _fechaInicio.year,
        _fechaInicio.month,
        _fechaInicio.day,
      ),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (fecha == null) {
      return;
    }

    setState(() {
      _fechaFin = DateTime(fecha.year, fecha.month, fecha.day, 23, 59);
    });
  }

  Future<void> _seleccionarImagen() async {
    final imagen = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );

    if (imagen == null) {
      return;
    }

    final bytes = await imagen.readAsBytes();

    if (bytes.length > PromocionService.maximoBytes) {
      if (mounted) {
        _mostrarMensaje('La imagen supera el límite permitido de 5 MB.');
      }
      return;
    }

    setState(() {
      _imagen = imagen;
      _imagenBytes = bytes;
    });
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) {
      return;
    }

    if (!_fechaFin.isAfter(_fechaInicio)) {
      _mostrarMensaje('La fecha final debe ser posterior a la inicial.');
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      final promocion = PromocionModel(
        id: '',
        establecimientoId: widget.establecimiento.id,
        titulo: _tituloController.text,
        descripcion: _descripcionController.text,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        radioAlertaMetros: int.parse(_radioController.text.trim()),
        activa: true,
      );

      await _service.crear(promocion: promocion, imagen: _imagen);

      if (!mounted) {
        return;
      }

      _mostrarMensaje('Promoción creada correctamente.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _mostrarMensaje('No se pudo crear la promoción: $error');
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
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
      appBar: AppBar(title: const Text('Nueva promoción')),
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
                  'Crea una promoción que posteriormente será '
                  'visible para los clientes de Cercly.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ejemplo: 20 % de descuento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_offer),
                  ),
                  maxLength: 120,
                  validator: (valor) {
                    final texto = valor?.trim() ?? '';

                    if (texto.length < 2) {
                      return 'Ingresa un título válido';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _radioController,
                  decoration: const InputDecoration(
                    labelText: 'Radio de alerta en metros',
                    helperText: 'Debe estar entre 10 y 5000 metros',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.radar),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (valor) {
                    final radio = int.tryParse(valor?.trim() ?? '');

                    if (radio == null) {
                      return 'Ingresa un número válido';
                    }

                    if (radio < 10 || radio > 5000) {
                      return 'El radio debe estar entre 10 y 5000';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Fecha de inicio'),
                  subtitle: Text(_formatearFecha(_fechaInicio)),
                  trailing: const Icon(Icons.edit),
                  onTap: _guardando ? null : _seleccionarFechaInicio,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available),
                  title: const Text('Fecha de finalización'),
                  subtitle: Text(_formatearFecha(_fechaFin)),
                  trailing: const Icon(Icons.edit),
                  onTap: _guardando ? null : _seleccionarFechaFin,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Imagen de la promoción',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_imagenBytes == null)
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _seleccionarImagen,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Seleccionar imagen'),
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _imagenBytes!,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _guardando ? null : _seleccionarImagen,
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Cambiar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _guardando
                            ? null
                            : () {
                                setState(() {
                                  _imagen = null;
                                  _imagenBytes = null;
                                });
                              },
                        tooltip: 'Quitar imagen',
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
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
                      : const Icon(Icons.save),
                  label: Text(_guardando ? 'Guardando...' : 'Crear promoción'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
