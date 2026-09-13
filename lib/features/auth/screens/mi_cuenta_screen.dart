import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class MiCuentaScreen extends StatelessWidget {
  const MiCuentaScreen({
    super.key,
    this.authService,
    this.correo,
    this.cerrarSesion,
  });

  final AuthService? authService;
  final String? correo;
  final Future<void> Function()? cerrarSesion;

  @override
  Widget build(BuildContext context) {
    final servicio =
        authService ??
        (correo == null || cerrarSesion == null ? AuthService() : null);
    final correoVisible =
        correo ?? servicio?.currentUser?.email ?? 'Usuario de Cercly';

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 38,
                child: Icon(Icons.person, size: 42),
              ),
              const SizedBox(height: 16),
              Text(
                correoVisible,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              OutlinedButton.icon(
                key: const Key('cerrar-sesion-cuenta'),
                onPressed: cerrarSesion ?? servicio!.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
