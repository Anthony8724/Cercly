import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../../establecimientos/models/establecimiento_model.dart';
import '../models/promocion_model.dart';
import '../services/promocion_service.dart';

class RegistroPromocionScreen extends StatefulWidget {
  const RegistroPromocionScreen({
    required this.establecimiento,
    this.promocion,
    this.urlImagenActual,
    super.key,
  });

  final EstablecimientoModel establecimiento;
  final PromocionModel? promocion;
  final String? urlImagenActual;

  bool get editando => promocion != null;

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
  final _radioController = TextEditingController();

  late DateTime _fechaInicio;
  late DateTime _fechaFin;

  XFile? _imagen;
  Uint8List? _imagenBytes;
  bool _eliminarImagenActual = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    final existente = widget.promocion;
    final ahora = DateTime.now();

    if (existente == null) {
      _fechaInicio = ahora;
      _fechaFin = ahora.add(const Duration(days: 7));
      _radioController.text = '100';
      return;
    }

    _tituloController.text = existente.titulo;
    _descripcionController.text = existente.descripcion;
    _radioController.text = existente.radioAlertaMetros.toString();
    _fechaInicio = existente.fechaInicio;
    _fechaFin = existente.fechaFin;
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
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
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
        _fechaInicio.hour,
        _fechaInicio.minute,
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
      _eliminarImagenActual = false;
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
      final existente = widget.promocion;
      final promocion = PromocionModel(
        id: existente?.id ?? '',
        establecimientoId: widget.establecimiento.id,
        titulo: _tituloController.text,
        descripcion: _descripcionController.text,
        imagenRutaStorage: existente?.imagenRutaStorage,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        radioAlertaMetros: int.parse(_radioController.text.trim()),
        activa: existente?.activa ?? true,
        creadoEn: existente?.creadoEn,
        actualizadoEn: existente?.actualizadoEn,
      );

      if (existente == null) {
        await _service.crear(promocion: promocion, imagen: _imagen);
      } else {
        await _service.actualizar(
          promocion: promocion,
          imagenNueva: _imagen,
          eliminarImagenActual: _eliminarImagenActual,
        );
      }

      if (!mounted) {
        return;
      }

      _mostrarMensaje(
        existente == null
            ? 'Promoción creada correctamente.'
            : 'Promoción actualizada correctamente.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _mostrarMensaje(
        widget.editando
            ? 'No se pudo actualizar la promoción: $error'
            : 'No se pudo crear la promoción: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  void _quitarImagen() {
    setState(() {
      _imagen = null;
      _imagenBytes = null;
      _eliminarImagenActual = true;
    });
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  bool get _mostrarImagenActual {
    return !_eliminarImagenActual &&
        _imagenBytes == null &&
        widget.urlImagenActual != null &&
        widget.urlImagenActual!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final tituloPantalla =
        widget.editando ? 'Editar promoción' : 'Nueva promoción';

    return Scaffold(
      backgroundColor: CerclyColors.background,
      body: Column(
        children: [
          CerclyPageHeader(
            title: tituloPantalla,
            subtitle: widget.establecimiento.nombre,
            icon: Icons.local_offer_rounded,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CerclyInfoBanner(
                        text: widget.editando
                            ? 'Actualiza los datos de esta promoción.'
                            : 'Crea una promoción que será visible para los clientes de Cercly.',
                        icon: Icons.campaign_rounded,
                      ),
                      const SizedBox(height: 16),
                      CerclySectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const CerclySectionTitle(
                              title: 'Información de la promoción',
                              subtitle:
                                  'Define el mensaje, alcance y vigencia de la promoción.',
                              icon: Icons.sell_rounded,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              key: const Key('promocion-titulo'),
                              controller: _tituloController,
                              decoration: const InputDecoration(
                                labelText: 'Título',
                                hintText: 'Ejemplo: 20 % de descuento',
                                prefixIcon:
                                    Icon(Icons.local_offer_rounded),
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
                              key: const Key('promocion-descripcion'),
                              controller: _descripcionController,
                              decoration: const InputDecoration(
                                labelText: 'Descripción',
                                prefixIcon:
                                    Icon(Icons.description_rounded),
                              ),
                              maxLength: 1000,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('promocion-radio'),
                              controller: _radioController,
                              decoration: const InputDecoration(
                                labelText: 'Radio de alerta en metros',
                                helperText:
                                    'Debe estar entre 10 y 5000 metros',
                                prefixIcon: Icon(Icons.radar_rounded),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (valor) {
                                final radio =
                                    int.tryParse(valor?.trim() ?? '');
                                if (radio == null) {
                                  return 'Ingresa un número válido';
                                }
                                if (radio < 10 || radio > 5000) {
                                  return 'El radio debe estar entre 10 y 5000';
                                }
                                return null;
                              },
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
                              title: 'Vigencia',
                              subtitle:
                                  'Selecciona desde cuándo y hasta cuándo estará disponible.',
                              icon: Icons.calendar_month_rounded,
                            ),
                            const SizedBox(height: 12),
                            _FechaPromocionTile(
                              icono: Icons.play_circle_outline_rounded,
                              titulo: 'Fecha de inicio',
                              fecha: _formatearFecha(_fechaInicio),
                              onTap: _guardando
                                  ? null
                                  : _seleccionarFechaInicio,
                            ),
                            const SizedBox(height: 10),
                            _FechaPromocionTile(
                              icono: Icons.event_available_rounded,
                              titulo: 'Fecha de finalización',
                              fecha: _formatearFecha(_fechaFin),
                              onTap:
                                  _guardando ? null : _seleccionarFechaFin,
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
                              title: 'Imagen de la promoción',
                              subtitle:
                                  'Puedes agregar una imagen para hacer la promoción más atractiva.',
                              icon: Icons.image_rounded,
                            ),
                            const SizedBox(height: 16),
                            if (_imagenBytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  _imagenBytes!,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AccionesImagen(
                                guardando: _guardando,
                                onCambiar: _seleccionarImagen,
                                onQuitar: _quitarImagen,
                              ),
                            ] else if (_mostrarImagenActual) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  widget.urlImagenActual!,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox(
                                    height: 120,
                                    child: ColoredBox(
                                      color: CerclyColors.softBlue,
                                      child: Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: CerclyColors.blue,
                                          size: 42,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AccionesImagen(
                                guardando: _guardando,
                                onCambiar: _seleccionarImagen,
                                onQuitar: _quitarImagen,
                              ),
                            ] else
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: _guardando
                                      ? null
                                      : _seleccionarImagen,
                                  icon: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                  ),
                                  label:
                                      const Text('Seleccionar imagen'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          key: const Key('guardar-promocion'),
                          onPressed: _guardando ? null : _guardar,
                          style: FilledButton.styleFrom(
                            backgroundColor: CerclyColors.blue,
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
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _guardando
                                ? 'Guardando...'
                                : widget.editando
                                    ? 'Guardar cambios'
                                    : 'Crear promoción',
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
    );
  }
}
class _FechaPromocionTile extends StatelessWidget {
  const _FechaPromocionTile({
    required this.icono,
    required this.titulo,
    required this.fecha,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String fecha;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CerclyColors.softBlue,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icono,
                  color: CerclyColors.blue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: CerclyColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fecha,
                      style: const TextStyle(
                        color: CerclyColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_calendar_rounded,
                color: CerclyColors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _AccionesImagen extends StatelessWidget {
  const _AccionesImagen({
    required this.guardando,
    required this.onCambiar,
    required this.onQuitar,
  });

  final bool guardando;
  final VoidCallback onCambiar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: guardando ? null : onCambiar,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Cambiar'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: guardando ? null : onQuitar,
          tooltip: 'Quitar imagen',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
