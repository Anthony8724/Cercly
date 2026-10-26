import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_logo.dart';

/// Cabecera visual de Explorar. Toda la decoración es estática para evitar
/// animaciones y reconstrucciones costosas.
class CabeceraExplorar extends StatelessWidget {
  const CabeceraExplorar({required this.buscador, this.onPerfil, super.key});

  final Widget buscador;
  final VoidCallback? onPerfil;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: SkyBackdrop(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkyMark(size: 48),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SkyWordmark(size: 30, onDark: true),
                          SizedBox(height: 4),
                          Text(
                            'Tu mundo más cerca',
                            style: TextStyle(
                              color: Color(0xFFE0EEFF),
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onPerfil != null)
                      SizedBox.square(
                        dimension: 40,
                        child: IconButton(
                          key: const Key('perfil-explorar'),
                          tooltip: 'Mi perfil',
                          onPressed: onPerfil,
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0x22000000),
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.4,
                            ),
                          ),
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 23,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Descubre cerca de ti',
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25.5,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.48,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Encuentra comercios y promociones en tu zona.',
                  style: TextStyle(
                    color: Color(0xFFD9E9FF),
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 11),
                buscador,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
