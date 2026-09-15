import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF02142F),
              Color(0xFF062F73),
              Color(0xFF0B5DD8),
            ],
            stops: [0, .52, 1],
          ),
        ),
        child: CustomPaint(
          painter: _CieloExplorar(),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 42,
                        child: CustomPaint(painter: _LogoCerclyPainter()),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cercly',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 31,
                                height: .95,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.15,
                              ),
                            ),
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
                  SizedBox(
                    height: 74,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          right: 96,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Descubre cerca de ti',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25.5,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.48,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Encuentra comercios y promociones en tu zona.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFFD9E9FF),
                                  fontSize: 12.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          right: 2,
                          top: 8,
                          child: _FraseDecorativa(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  buscador,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FraseDecorativa extends StatelessWidget {
  const _FraseDecorativa();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.10,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Explora\nDescubre\nDisfruta',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1.16,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 3),
          Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: Color(0xFFFFC83D),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoCerclyPainter extends CustomPainter {
  const _LogoCerclyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width * .49, size.height * .43);
    final orbit = Rect.fromCenter(
      center: Offset(centro.dx, size.height * .62),
      width: size.width * .94,
      height: size.height * .30,
    );

    canvas.drawOval(
      orbit,
      Paint()
        ..color = const Color(0xFF23B8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final pin = Path()
      ..moveTo(centro.dx, size.height * .92)
      ..cubicTo(
        size.width * .30,
        size.height * .66,
        size.width * .25,
        size.height * .41,
        size.width * .31,
        size.height * .27,
      )
      ..cubicTo(
        size.width * .38,
        size.height * .08,
        size.width * .60,
        size.height * .08,
        size.width * .68,
        size.height * .27,
      )
      ..cubicTo(
        size.width * .75,
        size.height * .44,
        size.width * .67,
        size.height * .67,
        centro.dx,
        size.height * .92,
      )
      ..close();

    canvas.drawPath(pin, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(centro.dx, size.height * .38),
      size.width * .115,
      Paint()..color = const Color(0xFF0B4EA9),
    );
  }

  @override
  bool shouldRepaint(covariant _LogoCerclyPainter oldDelegate) => false;
}

class _CieloExplorar extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _dibujarPlaneta(canvas, size);
    _dibujarEstrellas(canvas, size);
    _dibujarEstrellaFugaz(canvas, size);
  }

  void _dibujarPlaneta(Canvas canvas, Size size) {
    final centro = Offset(size.width * 1.02, size.height * .84);
    final radio = size.width * .58;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    final glowRect = Rect.fromCircle(center: centro, radius: radio * 1.035);
    canvas.drawCircle(
      centro,
      radio * 1.035,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x0019A7FF),
            Color(0x0019A7FF),
            Color(0xAA65C7FF),
            Color(0x0019A7FF),
          ],
          stops: [0, .88, .97, 1],
        ).createShader(glowRect),
    );

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.45, -.48),
          radius: 1.05,
          colors: [
            Color(0xFF1676E8),
            Color(0xFF0750B7),
            Color(0xFF032C6B),
            Color(0xFF011B48),
          ],
          stops: [0, .42, .76, 1],
        ).createShader(rect),
    );

    final atmosfera = Paint()
      ..color = const Color(0xFF72C8FF).withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawArc(rect, math.pi * 1.02, math.pi * .80, false, atmosfera);

    final nube = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(centro.dx - radio * .05, centro.dy - radio * .12),
        radius: radio * .72,
      ),
      math.pi * 1.08,
      math.pi * .62,
      false,
      nube,
    );
  }

  void _dibujarEstrellas(Canvas canvas, Size size) {
    for (var i = 0; i < 54; i++) {
      final x = ((i * 83 + 17) % 337) / 337 * size.width;
      final y = ((i * 59 + 9) % 229) / 229 * size.height * .72;
      final grande = i % 13 == 0;
      canvas.drawCircle(
        Offset(x, y),
        grande ? 1.15 : .55,
        Paint()
          ..color = Colors.white.withValues(alpha: grande ? .78 : .30),
      );
    }

    final brillo = Paint()
      ..color = const Color(0xFFBEE8FF)
      ..strokeWidth = 1;
    for (final punto in [
      Offset(size.width * .60, size.height * .16),
      Offset(size.width * .87, size.height * .32),
    ]) {
      canvas.drawLine(
        punto - const Offset(5, 0),
        punto + const Offset(5, 0),
        brillo,
      );
      canvas.drawLine(
        punto - const Offset(0, 5),
        punto + const Offset(0, 5),
        brillo,
      );
      canvas.drawCircle(punto, 1.4, Paint()..color = Colors.white);
    }
  }

  void _dibujarEstrellaFugaz(Canvas canvas, Size size) {
    final inicio = Offset(size.width * .53, size.height * .13);
    final fin = Offset(size.width * .67, size.height * .045);
    final linea = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x0019B5FF), Color(0xFFFFFFFF)],
      ).createShader(Rect.fromPoints(inicio, fin))
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(inicio, fin, linea);
    canvas.drawCircle(fin, 1.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _CieloExplorar oldDelegate) => false;
}
