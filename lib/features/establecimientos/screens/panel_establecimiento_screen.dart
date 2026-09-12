import 'package:flutter/material.dart';

import 'registro_establecimiento_screen.dart';
import '../../auth/services/auth_service.dart';

class PanelEstablecimientoScreen extends StatelessWidget {
  const PanelEstablecimientoScreen({super.key});

  Future<void> _cerrarSesion() async {
    await AuthService().signOut();
  }

  void _mostrarProximamente(BuildContext context, String opcion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$opcion estará disponible próximamente.')),
    );
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
        child: ListView(
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      child: Icon(Icons.storefront, size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mi establecimiento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Completa la información de tu negocio.'),
                        ],
                      ),
                    ),
                    Chip(
                      label: const Text('Pendiente'),
                      backgroundColor: Colors.orange.shade100,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Administración',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _OpcionPanel(
              icono: Icons.edit,
              titulo: 'Información del establecimiento',
              descripcion: 'Nombre, descripción, dirección y teléfono.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegistroEstablecimientoScreen(),
                  ),
                );
              },
            ),
            _OpcionPanel(
              icono: Icons.schedule,
              titulo: 'Horarios de atención',
              descripcion: 'Configura los horarios de cada día.',
              onTap: () =>
                  _mostrarProximamente(context, 'Horarios de atención'),
            ),
            _OpcionPanel(
              icono: Icons.local_offer,
              titulo: 'Promociones',
              descripcion: 'Crea y administra promociones activas.',
              onTap: () => _mostrarProximamente(
                context,
                'Administración de promociones',
              ),
            ),
            _OpcionPanel(
              icono: Icons.assignment,
              titulo: 'Estado de la solicitud',
              descripcion: 'Consulta la revisión de tu establecimiento.',
              onTap: () =>
                  _mostrarProximamente(context, 'Estado de la solicitud'),
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
