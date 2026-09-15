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
      backgroundColor: const Color(0xFFF6F9FE),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Mi cuenta',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF02142F), Color(0xFF0B5DD8)],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF031633), Color(0xFF1769FF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x240B4EA9),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x22FFFFFF),
                        border: Border.all(
                          color: const Color(0x88FFFFFF),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cercly',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      correoVisible,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE0EEFF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3EAF5)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFEAF2FF),
                      child: Icon(
                        Icons.explore_outlined,
                        color: Color(0xFF1769FF),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu experiencia Cercly',
                            style: TextStyle(
                              color: Color(0xFF102A56),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Explora lugares y promociones manteniendo tu sesión activa.',
                            style: TextStyle(
                              color: Color(0xFF65758C),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const Key('cerrar-sesion-cuenta'),
                  onPressed: cerrarSesion ?? servicio!.signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFF0B7B7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
