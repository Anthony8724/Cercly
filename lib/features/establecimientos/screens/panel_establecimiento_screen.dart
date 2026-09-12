import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../promociones/screens/promociones_establecimiento_screen.dart';
import '../models/establecimiento_model.dart';
import '../services/establecimiento_service.dart';
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

  void _mostrarProximamente(String opcion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$opcion estará disponible próximamente.')),
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
      appBar: AppBar(
        title: const Text('Panel del establecimiento'),
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Bienvenido',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(email, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              Text(
                'Mis establecimientos',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<EstablecimientoModel>>(
                future: _establecimientosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No se pudieron cargar tus establecimientos.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(_cargarEstablecimientos);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final establecimientos =
                      snapshot.data ?? <EstablecimientoModel>[];

                  if (establecimientos.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              child: Icon(Icons.storefront, size: 34),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Todavía no tienes establecimientos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Registra tu negocio para enviarlo a revisión.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _abrirRegistro,
                              icon: const Icon(Icons.add_business),
                              label: const Text('Registrar establecimiento'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final establecimiento in establecimientos)
                        _TarjetaEstablecimiento(
                          establecimiento: establecimiento,
                          colorEstado: _colorEstado(establecimiento.estado),
                          textoEstado: _textoEstado(establecimiento.estado),
                          onFotografias: () {
                            _abrirFotografias(establecimiento);
                          },
                          onHorarios: () {
                            _abrirHorarios(establecimiento);
                          },
                          onPromociones: () {
                            _abrirPromociones(establecimiento);
                          },
                        ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: _abrirRegistro,
                        icon: const Icon(Icons.add_business),
                        label: const Text('Registrar otro establecimiento'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Administración general',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _OpcionPanel(
                icono: Icons.edit,
                titulo: 'Información del establecimiento',
                descripcion:
                    'Edita el nombre, descripción, dirección y teléfono.',
                onTap: () =>
                    _mostrarProximamente('Edición del establecimiento'),
              ),
              _OpcionPanel(
                icono: Icons.assignment,
                titulo: 'Estado de revisión',
                descripcion: 'Consulta si tu establecimiento fue aprobado.',
                onTap: () =>
                    _mostrarProximamente('Detalle del estado de revisión'),
              ),
            ],
          ),
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 26,
                  child: Icon(Icons.storefront, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        establecimiento.nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(establecimiento.direccion),
                      if (establecimiento.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          establecimiento.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.circle, size: 12, color: colorEstado),
                label: Text(textoEstado),
                backgroundColor: colorEstado.withValues(alpha: 0.12),
                side: BorderSide(color: colorEstado.withValues(alpha: 0.35)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onFotografias,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Fotografías'),
                ),
                OutlinedButton.icon(
                  onPressed: onHorarios,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Horarios'),
                ),
                OutlinedButton.icon(
                  onPressed: onPromociones,
                  icon: const Icon(Icons.local_offer),
                  label: const Text('Promociones'),
                ),
              ],
            ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icono)),
        title: Text(titulo),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
