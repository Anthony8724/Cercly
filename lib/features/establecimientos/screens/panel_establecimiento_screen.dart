import 'package:flutter/material.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../../auth/services/auth_service.dart';
import '../../promociones/screens/promociones_establecimiento_screen.dart';
import '../../solicitudes_establecimientos/screens/mis_solicitudes_screen.dart';
import '../models/establecimiento_model.dart';
import '../services/establecimiento_service.dart';
import 'editar_informacion_establecimiento_screen.dart';
import 'fotos_establecimiento_screen.dart';
import 'horarios_establecimiento_screen.dart';
import 'registro_establecimiento_screen.dart';

class PanelEstablecimientoScreen extends StatefulWidget {
  const PanelEstablecimientoScreen({super.key});

  @override
  State<PanelEstablecimientoScreen> createState() =>
      _PanelEstablecimientoScreenState();
}

class _PanelEstablecimientoScreenState
    extends State<PanelEstablecimientoScreen> {
  final _service = EstablecimientoService();

  late Future<List<EstablecimientoModel>> _establecimientosFuture;

  @override
  void initState() {
    super.initState();
    _cargarEstablecimientos();
  }

  void _cargarEstablecimientos() {
    _establecimientosFuture = _service.listarEstablecimientosDelUsuario();
  }

  Future<void> _recargar() async {
    setState(_cargarEstablecimientos);
    await _establecimientosFuture;
  }

  Future<void> _cerrarSesion() async {
    await AuthService().signOut();
  }

  Future<void> _abrirRegistro() async {
    final fueRegistrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const RegistroEstablecimientoScreen(),
      ),
    );

    if (fueRegistrado == true && mounted) {
      setState(_cargarEstablecimientos);
    }
  }

  Future<void> _abrirInformacionEstablecimiento() async {
    try {
      final establecimientos = await _service
          .listarEstablecimientosDelUsuario();

      if (!mounted) {
        return;
      }

      if (establecimientos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Primero debes registrar un establecimiento.'),
          ),
        );
        return;
      }

      EstablecimientoModel? seleccionado;

      if (establecimientos.length == 1) {
        seleccionado = establecimientos.first;
      } else {
        seleccionado = await showDialog<EstablecimientoModel>(
          context: context,
          builder: (context) {
            return SimpleDialog(
              title: const Text('Selecciona un establecimiento'),
              children: [
                for (final establecimiento in establecimientos)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(establecimiento),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            establecimiento.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(establecimiento.direccion),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }

      if (!mounted || seleccionado == null) {
        return;
      }

      final actualizado = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => EditarInformacionEstablecimientoScreen(
            establecimiento: seleccionado!,
          ),
        ),
      );

      if (actualizado == true && mounted) {
        setState(_cargarEstablecimientos);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la información: $error')),
      );
    }
  }

  void _abrirFotografias(EstablecimientoModel establecimiento) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FotosEstablecimientoScreen(establecimiento: establecimiento),
      ),
    );
  }

  void _abrirHorarios(EstablecimientoModel establecimiento) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HorariosEstablecimientoScreen(establecimiento: establecimiento),
      ),
    );
  }

  void _abrirPromociones(EstablecimientoModel establecimiento) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PromocionesEstablecimientoScreen(establecimiento: establecimiento),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _textoEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? 'Sin correo';

    return Scaffold(
      backgroundColor: CerclyColors.background,
      body: Column(
        children: [
          CerclyPageHeader(
            title: 'Panel del establecimiento',
            subtitle: email,
            icon: Icons.storefront_rounded,
            actions: [
              CerclyHeaderAction(
                icon: Icons.logout_rounded,
                tooltip: 'Cerrar sesión',
                onPressed: _cerrarSesion,
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _recargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    const CerclySectionTitle(
                      title: 'Mis establecimientos',
                      subtitle: 'Administra la información, horarios, fotografías y promociones de tus negocios.',
                      icon: Icons.business_rounded,
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<List<EstablecimientoModel>>(
                      future: _establecimientosFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CerclySectionCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 22),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return CerclySectionCard(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.red,
                                  size: 42,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No se pudieron cargar tus establecimientos.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CerclyColors.text,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(_cargarEstablecimientos);
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          );
                        }

                        final establecimientos =
                            snapshot.data ?? <EstablecimientoModel>[];

                        if (establecimientos.isEmpty) {
                          return CerclySectionCard(
                            child: Column(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: const BoxDecoration(
                                    color: CerclyColors.softBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_business_rounded,
                                    color: CerclyColors.blue,
                                    size: 35,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Todavía no tienes establecimientos',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CerclyColors.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                const Text(
                                  'Registra tu negocio para enviarlo a revisión.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: CerclyColors.muted),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _abrirRegistro,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: CerclyColors.blue,
                                  ),
                                  icon: const Icon(Icons.add_business_rounded),
                                  label: const Text(
                                    'Registrar establecimiento',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final establecimiento in establecimientos)
                              _TarjetaEstablecimiento(
                                establecimiento: establecimiento,
                                colorEstado: _colorEstado(
                                  establecimiento.estado,
                                ),
                                textoEstado: _textoEstado(
                                  establecimiento.estado,
                                ),
                                onFotografias: () =>
                                    _abrirFotografias(establecimiento),
                                onHorarios: () =>
                                    _abrirHorarios(establecimiento),
                                onPromociones: () =>
                                    _abrirPromociones(establecimiento),
                              ),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _abrirRegistro,
                                icon: const Icon(Icons.add_business_rounded),
                                label: const Text(
                                  'Registrar otro establecimiento',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const CerclySectionTitle(
                      title: 'Administración general',
                      subtitle: 'Gestiona información general y solicitudes relacionadas con tus negocios.',
                      icon: Icons.settings_rounded,
                    ),
                    const SizedBox(height: 14),
                    _OpcionPanel(
                      icono: Icons.edit_rounded,
                      titulo: 'Información del establecimiento',
                      descripcion:
                          'Edita el nombre, descripción, dirección y teléfono.',
                      onTap: _abrirInformacionEstablecimiento,
                    ),
                    const SizedBox(height: 10),
                    _OpcionPanel(
                      icono: Icons.assignment_rounded,
                      titulo: 'Mis solicitudes',
                      descripcion: 'Envía solicitudes y consulta la respuesta del administrador.',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MisSolicitudesScreen(),
                          ),
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
    );
  }
}

class _TarjetaEstablecimiento extends StatelessWidget {
  const _TarjetaEstablecimiento({
    required this.establecimiento,
    required this.colorEstado,
    required this.textoEstado,
    required this.onFotografias,
    required this.onHorarios,
    required this.onPromociones,
  });

  final EstablecimientoModel establecimiento;
  final Color colorEstado;
  final String textoEstado;
  final VoidCallback onFotografias;
  final VoidCallback onHorarios;
  final VoidCallback onPromociones;

  @override
  Widget build(BuildContext context) {
    return CerclySectionCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: CerclyColors.softBlue,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: CerclyColors.blue,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      establecimiento.nombre,
                      style: const TextStyle(
                        color: CerclyColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: CerclyColors.blue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            establecimiento.direccion,
                            style: const TextStyle(
                              color: CerclyColors.muted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (establecimiento.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        establecimiento.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CerclyColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colorEstado.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorEstado.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: colorEstado),
                  const SizedBox(width: 6),
                  Text(
                    textoEstado,
                    style: TextStyle(
                      color: colorEstado,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onFotografias,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Fotografías'),
              ),
              OutlinedButton.icon(
                onPressed: onHorarios,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Horarios'),
              ),
              OutlinedButton.icon(
                onPressed: onPromociones,
                icon: const Icon(Icons.local_offer_rounded),
                label: const Text('Promociones'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpcionPanel extends StatelessWidget {
  const _OpcionPanel({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CerclySectionCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CerclyColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icono, color: CerclyColors.blue),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            color: CerclyColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          descripcion,
          style: const TextStyle(color: CerclyColors.muted),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: CerclyColors.blue,
        ),
        onTap: onTap,
      ),
    );
  }
}
