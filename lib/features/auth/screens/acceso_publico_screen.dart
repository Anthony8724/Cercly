import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_logo.dart';
import '../../../sky/sky_theme.dart';
import 'login_screen.dart';
import 'seleccion_tipo_cuenta_screen.dart';

class AccesoPublicoScreen extends StatelessWidget {
  const AccesoPublicoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      body: SkySurface(
        intensity: .75,
        child: SafeArea(
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
                      color: sky.surface,
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: sky.headerGradient,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Únete a Cercly',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sky.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Inicia sesión o crea una cuenta para guardar tus preferencias y aprovechar más funciones.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sky.muted,
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
                              backgroundColor: sky.primary,
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
                              foregroundColor: sky.interactive,
                              side: BorderSide(color: sky.border),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: sky.muted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Tus datos se usan solo para tu experiencia en Cercly.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: sky.muted,
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
      ),
    );
  }
}

class _CabeceraAcceso extends StatelessWidget {
  const _CabeceraAcceso();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SkyBackdrop(
        child: Container(
          width: double.infinity,
          height: 300,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SkyMark(size: 94),
                  const SizedBox(height: 8),
                  const SkyWordmark(size: 36, onDark: true),
                  const SizedBox(height: 10),
                  const Text(
                    'Descubre lugares cerca de ti',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
