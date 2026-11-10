import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';

import '../../../sky/sky_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../models/establecimiento_model.dart';
import '../services/establecimiento_service.dart';
import '../../solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import '../../solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';

class EditarInformacionEstablecimientoScreen extends StatefulWidget {
  const EditarInformacionEstablecimientoScreen({
    required this.establecimiento,
    this.service,
    this.solicitudesService,
    super.key,
  });

  final EstablecimientoModel establecimiento;
  final EstablecimientoService? service;
  final SolicitudEstablecimientoRepository? solicitudesService;

  @override
  State<EditarInformacionEstablecimientoScreen> createState() =>
      _EditarInformacionEstablecimientoScreenState();
}

class _EditarInformacionEstablecimientoScreenState
    extends State<EditarInformacionEstablecimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _service = widget.service ?? EstablecimientoService();

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

      const mensaje = 'Información actualizada correctamente.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
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
    if (widget.establecimiento.requiereSolicitudCorreccion) {
      if (!widget.establecimiento.publicable) {
        return Scaffold(
          backgroundColor: SkyPalette.of(context).background,
          body: SkySurface(
            child: SafeArea(
              child: Column(
                children: [
                  CerclyPageHeader(
                    title: 'Ficha aprobada sin publicar',
                    subtitle: widget.establecimiento.nombre,
                    icon: Icons.visibility_off_outlined,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CerclyInfoBanner(
                      text: 'Un administrador debe revisar la publicación de esta ficha antes de que puedas solicitar una corrección. No se han modificado sus datos.',
                      icon: Icons.info_outline_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return NuevaSolicitudScreen(
        tipoInicial: 'correccion',
        establecimientoIdInicial: widget.establecimiento.id,
        bloquearTipo: true,
        service: widget.solicitudesService,
      );
    }

    return Scaffold(
      backgroundColor: SkyPalette.of(context).background,
      body: SkySurface(
        child: Column(
          children: [
            CerclyPageHeader(
              title: 'Información del establecimiento',
              subtitle: widget.establecimiento.nombre,
              icon: Icons.edit_note_rounded,
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
                        CerclySectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const CerclySectionTitle(
                                title: 'Datos públicos',
                                subtitle: 'Actualiza la información que se mostrará a los usuarios de Cercly.',
                                icon: Icons.badge_rounded,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                key: const Key('editar-establecimiento-nombre'),
                                controller: _nombreController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre',
                                  prefixIcon: Icon(Icons.storefront_rounded),
                                ),
                                maxLength: 120,
                                textInputAction: TextInputAction.next,
                                validator: _validarNombre,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key(
                                  'editar-establecimiento-descripcion',
                                ),
                                controller: _descripcionController,
                                decoration: const InputDecoration(
                                  labelText: 'Descripción',
                                  prefixIcon: Icon(Icons.description_rounded),
                                ),
                                maxLength: 1000,
                                maxLines: 4,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key(
                                  'editar-establecimiento-direccion',
                                ),
                                controller: _direccionController,
                                decoration: const InputDecoration(
                                  labelText: 'Dirección',
                                  prefixIcon: Icon(Icons.location_on_rounded),
                                ),
                                maxLength: 250,
                                textInputAction: TextInputAction.next,
                                validator: _validarDireccion,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key(
                                  'editar-establecimiento-telefono',
                                ),
                                controller: _telefonoController,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono público (opcional)',
                                  prefixIcon: Icon(Icons.phone_rounded),
                                ),
                                maxLength: 20,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const CerclyInfoBanner(
                          text: 'La categoría, ubicación y horarios se administran desde sus secciones correspondientes.',
                          icon: Icons.tune_rounded,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            key: const Key(
                              'guardar-informacion-establecimiento',
                            ),
                            onPressed: _guardando ? null : _guardar,
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
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _guardando ? 'Guardando...' : 'Guardar cambios',
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
