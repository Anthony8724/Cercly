import 'package:flutter/material.dart';

import '../../../shared/ui/cercly_ui.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../../solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import '../../solicitudes_establecimientos/screens/mis_solicitudes_screen.dart';
import '../../solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import '../models/establecimiento_model.dart';
import '../services/establecimiento_service.dart';
import 'registro_establecimiento_screen.dart';

class MisNegociosScreen extends StatefulWidget {
  const MisNegociosScreen({
    super.key,
    this.cargarNegocios,
    this.registroService,
    this.registroScreenBuilder,
    this.reclamoScreenBuilder,
    this.solicitudesScreenBuilder,
  });

  final Future<List<EstablecimientoModel>> Function()? cargarNegocios;
  final RegistroEstablecimientoRepository? registroService;
  final WidgetBuilder? registroScreenBuilder;
  final WidgetBuilder? reclamoScreenBuilder;
  final WidgetBuilder? solicitudesScreenBuilder;

  @override
  State<MisNegociosScreen> createState() => _MisNegociosScreenState();
}

class _MisNegociosScreenState extends State<MisNegociosScreen> {
  late final EstablecimientoService? _service;
  late Future<List<EstablecimientoModel>> _negocios;

  @override
  void initState() {
    super.initState();
    _service = widget.cargarNegocios == null ? EstablecimientoService() : null;
    _negocios = _cargarNegocios();
  }

  Future<List<EstablecimientoModel>> _cargarNegocios() =>
      widget.cargarNegocios?.call() ??
      _service!.listarEstablecimientosDelUsuario();

  Future<void> _recargar() async {
    setState(() => _negocios = _cargarNegocios());
    await _negocios;
  }

  Future<void> _abrirRegistro() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            widget.registroScreenBuilder ??
            (_) =>
                RegistroEstablecimientoScreen(service: widget.registroService),
      ),
    );
    if (creado == true && mounted) await _recargar();
  }

  void _abrirReclamo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            widget.reclamoScreenBuilder ??
            (_) => const NuevaSolicitudScreen(
              tipoInicial: SolicitudEstablecimientoModel.tipoReclamar,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      body: SkySurface(
        child: Column(
          children: [
            CerclyPageHeader(
              title: 'Mis negocios',
              subtitle: 'Registra un negocio o gestiona tus solicitudes',
              icon: Icons.storefront_rounded,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: _recargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      FilledButton.icon(
                        key: const Key('registrar-nuevo-establecimiento'),
                        onPressed: _abrirRegistro,
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('Registrar nuevo establecimiento'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('reclamar-establecimiento-existente'),
                        onPressed: _abrirReclamo,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Reclamar establecimiento existente'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                widget.solicitudesScreenBuilder ??
                                (_) => const MisSolicitudesScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.assignment_outlined),
                        label: const Text('Mis solicitudes'),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Mis establecimientos',
                        style: TextStyle(
                          color: sky.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<EstablecimientoModel>>(
                        future: _negocios,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return CerclySectionCard(
                              child: Text(
                                'No se pudieron cargar tus establecimientos. Desliza para actualizar.',
                                style: TextStyle(color: sky.muted),
                              ),
                            );
                          }
                          final negocios = snapshot.data ?? [];
                          if (negocios.isEmpty) {
                            return CerclySectionCard(
                              child: Text(
                                'Los establecimientos aprobados aparecerán aquí.',
                                style: TextStyle(color: sky.muted),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (final negocio in negocios)
                                Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.storefront_rounded,
                                    ),
                                    title: Text(negocio.nombre),
                                    subtitle: Text(
                                      '${negocio.direccion}\nEstado: ${negocio.estado}',
                                    ),
                                    isThreeLine: true,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
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
