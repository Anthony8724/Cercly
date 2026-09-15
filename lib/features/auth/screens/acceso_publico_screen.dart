import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'seleccion_tipo_cuenta_screen.dart';

class AccesoPublicoScreen extends StatelessWidget {
  const AccesoPublicoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const _CabeceraAcceso(),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0B4EA9),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1769FF), Color(0xFF0B4EA9)],
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Únete a Cercly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF102A56),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inicia sesión o crea una cuenta para guardar tus preferencias y aprovechar más funciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF65758C),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          key: const Key('iniciar-sesion-publico'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1769FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text(
                            'Iniciar sesión',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const Key('crear-cuenta-publico'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SeleccionTipoCuentaScreen(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1769FF),
                            side: const BorderSide(color: Color(0xFF8AB8FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text(
                            'Crear cuenta',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: Color(0xFF7C8CA3),
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Tus datos se usan solo para tu experiencia en Cercly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF7C8CA3),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _CabeceraAcceso extends StatelessWidget {
  const _CabeceraAcceso();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 250,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF02142F), Color(0xFF07377D), Color(0xFF1769FF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 18,
            top: 6,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF8CCBFF),
              size: 22,
            ),
          ),
          const Positioned(
            right: 70,
            top: 58,
            child: Icon(
              Icons.star_rounded,
              color: Color(0x66FFFFFF),
              size: 10,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cercly',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tu mundo más cerca',
                        style: TextStyle(
                          color: Color(0xFFDCEBFF),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Tu cuenta, tu experiencia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Descubre, guarda y conecta con lugares cerca de ti.',
                style: TextStyle(
                  color: Color(0xFFD7E8FF),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
