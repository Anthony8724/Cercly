import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum SkyStarShape { micro, fourPoint, accent }

@immutable
class SkyStar {
  const SkyStar({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.periodSeconds,
    required this.phase,
    required this.colorIndex,
    required this.shape,
    required this.almostStatic,
  });

  final Offset position;
  final double radius;
  final double opacity;
  final double periodSeconds;
  final double phase;
  final int colorIndex;
  final SkyStarShape shape;
  final bool almostStatic;
}

@immutable
class SkyCloud {
  const SkyCloud({
    required this.position,
    required this.width,
    required this.speed,
    required this.opacity,
  });

  final Offset position;
  final double width;
  final double speed;
  final double opacity;
}

/// Formas estables por tamaño. Se calculan una sola vez cuando cambia el área.
class SkyAmbientGeometry {
  const SkyAmbientGeometry._();

  static Offset sunCenter(
    Size size, {
    required bool sunset,
    bool header = false,
  }) => Offset(
    size.width * (header ? .86 : (sunset ? .86 : .14)),
    size.height * (header ? (sunset ? .68 : .18) : (sunset ? .56 : .46)),
  );

  static List<SkyStar> stars(Size size, {bool header = false}) {
    if (size.isEmpty) return const [];
    final random = math.Random(header ? 42160 : 42159);
    final count = header
        ? (size.width * size.height / 7200).round().clamp(10, 24)
        : (size.width * size.height / 4600).round().clamp(24, 96);
    final stars = <SkyStar>[];
    var attempts = 0;
    while (stars.length < count && attempts < count * 24) {
      attempts++;
      final point = Offset(
        8 + random.nextDouble() * math.max(1, size.width - 16),
        8 + random.nextDouble() * math.max(1, size.height - 16),
      );
      if (stars.any((star) => (star.position - point).distance < 19)) {
        continue;
      }
      final type = random.nextDouble();
      final shape = type < .70
          ? SkyStarShape.micro
          : type < .93
          ? SkyStarShape.fourPoint
          : SkyStarShape.accent;
      stars.add(
        SkyStar(
          position: point,
          radius: switch (shape) {
            SkyStarShape.micro => .45 + random.nextDouble() * .65,
            SkyStarShape.fourPoint => 1.3 + random.nextDouble() * .55,
            SkyStarShape.accent => 1.8 + random.nextDouble() * .5,
          },
          opacity: switch (shape) {
            SkyStarShape.micro => .18 + random.nextDouble() * .20,
            SkyStarShape.fourPoint => .29 + random.nextDouble() * .16,
            SkyStarShape.accent => .42 + random.nextDouble() * .12,
          },
          periodSeconds: 3 + random.nextDouble() * 5,
          phase: random.nextDouble() * math.pi * 2,
          colorIndex: random.nextInt(4),
          shape: shape,
          almostStatic: random.nextDouble() < .22,
        ),
      );
    }
    return List.unmodifiable(stars);
  }

  static List<SkyCloud> clouds(Size size, {bool header = false}) {
    if (size.isEmpty) return const [];
    final random = math.Random(header ? 3502 : 3501);
    final count = header ? 2 : 4;
    return List.unmodifiable([
      for (var index = 0; index < count; index++)
        SkyCloud(
          position: header
              ? Offset(
                  size.width * (.70 + index * .12),
                  size.height * (.12 + index * .28),
                )
              : Offset(
                  size.width * ([.72, .18, .89, .05][index]),
                  size.height * ([.45, .24, .64, .79][index]),
                ),
          width: 62 + random.nextDouble() * 40,
          speed: 1.1 + random.nextDouble() * 1.8,
          opacity: .20 + random.nextDouble() * .08,
        ),
    ]);
  }
}

class SkyAmbientMotionMath {
  const SkyAmbientMotionMath._();

  static double starOpacity(SkyStar star, double seconds) {
    if (star.almostStatic) return star.opacity;
    final wave = math.sin(
      seconds * 2 * math.pi / star.periodSeconds + star.phase,
    );
    return star.opacity * (0.82 + .18 * wave);
  }

  static double starScale(SkyStar star, double seconds) {
    if (star.shape != SkyStarShape.accent || star.almostStatic) return 1;
    return 1 +
        .045 *
            math.sin(seconds * 2 * math.pi / star.periodSeconds + star.phase);
  }

  static double sunGlow(double seconds, {required bool sunset}) =>
      1 + .08 * math.sin(seconds * 2 * math.pi / (sunset ? 8 : 7));

  static double cloudX(SkyCloud cloud, Size size, double seconds) {
    final span = size.width + cloud.width;
    return ((cloud.position.dx + cloud.speed * seconds + cloud.width) % span) -
        cloud.width;
  }
}
