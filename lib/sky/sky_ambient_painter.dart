import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sky_ambient_geometry.dart';
import 'sky_theme.dart';

/// Una capa por superficie; el reloj compartido solo repinta este CustomPaint.
class SkyAmbientPainter extends CustomPainter {
  SkyAmbientPainter({
    required this.palette,
    required this.motion,
    required this.header,
    required this.intensity,
  }) : super(repaint: motion);

  final SkyPalette palette;
  final ValueListenable<double> motion;
  final bool header;
  final double intensity;

  Size? _cachedSize;
  List<SkyStar> _stars = const [];
  List<SkyCloud> _clouds = const [];

  static const starColors = <Color>[
    Color(0xFFE3EDFF),
    Color(0xFFDCCAFF),
    Color(0xFFC9E8FF),
    Color(0xFFBFC2F1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !palette.decorationsEnabled) return;
    if (_cachedSize != size) {
      _cachedSize = size;
      _stars = SkyAmbientGeometry.stars(size, header: header);
      _clouds = SkyAmbientGeometry.clouds(size, header: header);
    }
    switch (palette.environment) {
      case SkyEnvironment.amanecer:
        _paintSun(canvas, size, sunset: false);
      case SkyEnvironment.dia:
        _paintClouds(canvas, size);
      case SkyEnvironment.atardecer:
        _paintSun(canvas, size, sunset: true);
      case SkyEnvironment.noche:
        _paintStars(canvas);
    }
  }

  void _paintSun(Canvas canvas, Size size, {required bool sunset}) {
    final center = SkyAmbientGeometry.sunCenter(
      size,
      sunset: sunset,
      header: header,
    );
    final radius = (math.min(size.width, size.height) * .035).clamp(7.0, 13.0);
    final warm = sunset ? const Color(0xFFFFC3A2) : const Color(0xFFF8D0BC);
    final glow = SkyAmbientMotionMath.sunGlow(motion.value, sunset: sunset);
    final strength = intensity * (header ? .83 : .65);
    canvas.drawCircle(
      center,
      radius * 3.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            warm.withValues(alpha: .27 * strength * glow),
            warm.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 3.6)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = warm.withValues(alpha: .56 * strength),
    );
    final ray = Paint()
      ..color = warm.withValues(alpha: .37 * strength * glow)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 8; index++) {
      final angle = index * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius * 1.45),
        center + direction * (radius * 1.85),
        ray,
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    final seconds = motion.value;
    final strength = intensity * (header ? .85 : .9);
    if (header) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(size.width * .64, 0, size.width * .36, size.height * .62),
      );
    }
    for (final cloud in _clouds) {
      final x = SkyAmbientMotionMath.cloudX(cloud, size, seconds);
      final width = cloud.width;
      final height = width * .28;
      final y = cloud.position.dy;
      final path = Path()
        ..moveTo(x, y + height * .78)
        ..cubicTo(
          x + width * .06,
          y + height * .48,
          x + width * .18,
          y + height * .47,
          x + width * .28,
          y + height * .50,
        )
        ..cubicTo(
          x + width * .36,
          y + height * .03,
          x + width * .54,
          y + height * .02,
          x + width * .65,
          y + height * .43,
        )
        ..cubicTo(
          x + width * .79,
          y + height * .29,
          x + width * .95,
          y + height * .52,
          x + width,
          y + height * .78,
        )
        ..quadraticBezierTo(
          x + width * .98,
          y + height,
          x + width * .84,
          y + height,
        )
        ..lineTo(x + width * .15, y + height)
        ..quadraticBezierTo(x, y + height, x, y + height * .78)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = (header ? Colors.white : const Color(0xFF7ABDE2))
              .withValues(alpha: cloud.opacity * strength),
      );
    }
    if (header) canvas.restore();
  }

  void _paintStars(Canvas canvas) {
    final seconds = motion.value;
    final paint = Paint();
    for (final star in _stars) {
      paint.color = starColors[star.colorIndex].withValues(
        alpha: SkyAmbientMotionMath.starOpacity(star, seconds) * intensity,
      );
      if (star.shape == SkyStarShape.micro) {
        canvas.drawCircle(star.position, star.radius, paint);
      } else {
        _drawFourPoint(
          canvas,
          star.position,
          star.radius * SkyAmbientMotionMath.starScale(star, seconds),
          paint,
        );
      }
    }
  }

  void _drawFourPoint(Canvas canvas, Offset point, double radius, Paint paint) {
    final outer = radius * 2.2;
    final inner = radius * .37;
    final path = Path()
      ..moveTo(point.dx, point.dy - outer)
      ..quadraticBezierTo(
        point.dx + inner,
        point.dy - inner,
        point.dx + outer,
        point.dy,
      )
      ..quadraticBezierTo(
        point.dx + inner,
        point.dy + inner,
        point.dx,
        point.dy + outer,
      )
      ..quadraticBezierTo(
        point.dx - inner,
        point.dy + inner,
        point.dx - outer,
        point.dy,
      )
      ..quadraticBezierTo(
        point.dx - inner,
        point.dy - inner,
        point.dx,
        point.dy - outer,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SkyAmbientPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.header != header ||
      oldDelegate.intensity != intensity ||
      oldDelegate.motion != motion;
}
