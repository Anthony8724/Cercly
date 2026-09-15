import 'package:flutter/material.dart';

/// Decoración estática: no inicia animaciones, timers ni consultas.
class CabeceraExplorar extends StatelessWidget {
  const CabeceraExplorar({required this.buscador, this.onPerfil, super.key});

  final Widget buscador;
  final VoidCallback? onPerfil;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF031633), Color(0xFF07377D), Color(0xFF1769FF)],
          ),
        ),
        child: CustomPaint(
          painter: _CieloExplorar(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 48, color: Colors.white),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cercly', style: TextStyle(color: Colors.white,
                            fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                          Text('Tu mundo más cerca', style: TextStyle(
                            color: Color(0xFFD6E8FF), fontSize: 12)),
                        ],
                      ),
                    ),
                    if (onPerfil != null)
                      IconButton.outlined(
                        key: const Key('perfil-explorar'),
                        tooltip: 'Mi perfil',
                        onPressed: onPerfil,
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF8EC7FF)),
                        ),
                        icon: const Icon(Icons.person_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('Descubre cerca de ti', style: TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Encuentra comercios y promociones en tu zona.',
                  style: TextStyle(color: Color(0xFFC5DFFF), fontSize: 14)),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('Explora · Descubre · Disfruta', style: TextStyle(
                    color: Colors.white, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 14),
                buscador,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CieloExplorar extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final halo = Rect.fromCircle(
      center: Offset(size.width * .93, size.height * .68),
      radius: size.width * .65,
    );
    canvas.drawOval(halo, Paint()..shader = const RadialGradient(
      colors: [Color(0x0065BFFF), Color(0x0065BFFF), Color(0x5565BFFF), Color(0x0065BFFF)],
      stops: [0, .77, .81, 1],
    ).createShader(halo));
    for (var i = 0; i < 64; i++) {
      final x = ((i * 73 + 19) % 307) / 307 * size.width;
      final y = ((i * 47 + 11) % 211) / 211 * size.height * .74;
      canvas.drawCircle(Offset(x, y), i % 9 == 0 ? 1.2 : .65,
        Paint()..color = Colors.white.withValues(alpha: i % 3 == 0 ? .55 : .18));
    }
    final paint = Paint()..color = const Color(0xAA8EC7FF)..strokeWidth = 1;
    for (final point in [Offset(size.width * .55, 24), Offset(size.width * .88, 105)]) {
      canvas.drawLine(point - const Offset(5, 0), point + const Offset(5, 0), paint);
      canvas.drawLine(point - const Offset(0, 5), point + const Offset(0, 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CieloExplorar oldDelegate) => false;
}
