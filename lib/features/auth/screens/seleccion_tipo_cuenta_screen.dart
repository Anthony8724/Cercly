import 'package:flutter/material.dart';

import 'register_screen.dart';

class SeleccionTipoCuentaScreen extends StatelessWidget {
  const SeleccionTipoCuentaScreen({super.key});

  void _abrirRegistro(BuildContext context, TipoCuenta tipoCuenta) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(tipoCuenta: tipoCuenta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Cómo quieres usar Cercly?',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _OpcionCuenta(
                key: const Key('registro-como-usuario'),
                icono: Icons.person_outline,
                titulo: 'Como usuario',
                descripcion: 'Guarda tus preferencias y descubre lugares.',
                onTap: () => _abrirRegistro(context, TipoCuenta.usuario),
              ),
              const SizedBox(height: 12),
              _OpcionCuenta(
                key: const Key('registro-como-propietario'),
                icono: Icons.storefront_outlined,
                titulo: 'Como propietario de un negocio',
                descripcion: 'Registra y administra tu establecimiento.',
                onTap: () => _abrirRegistro(context, TipoCuenta.propietario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionCuenta extends StatelessWidget {
  const _OpcionCuenta({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icono, size: 36),
        title: Text(titulo),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
