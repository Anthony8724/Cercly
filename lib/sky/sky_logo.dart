import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sky_theme.dart';

/// Isotipo aprobado. Los cuatro SVG se generan desde isotipo-master.svg.
class SkyMark extends StatelessWidget {
  const SkyMark({this.size = 48, this.environment, super.key});

  final double size;
  final SkyEnvironment? environment;

  static String assetFor(SkyEnvironment environment) =>
      'assets/branding/sky/variants/isotipo-${environment.name}.svg';

  @override
  Widget build(BuildContext context) {
    final selected = environment ?? SkyPalette.of(context).environment;
    return Semantics(
      label: 'Cercly',
      image: true,
      child: ExcludeSemantics(
        child: SvgPicture.asset(
          assetFor(selected),
          key: Key('sky-mark-${selected.name}'),
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class SkyWordmark extends StatelessWidget {
  const SkyWordmark({this.size = 30, this.onDark = false, super.key});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Text(
    'Cercly',
    maxLines: 1,
    overflow: TextOverflow.fade,
    softWrap: false,
    style: TextStyle(
      fontFamily: 'Comfortaa',
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.1,
      color: onDark ? Colors.white : SkyPalette.of(context).text,
    ),
  );
}

class SkyHorizontalLogo extends StatelessWidget {
  const SkyHorizontalLogo({
    this.markSize = 48,
    this.wordSize = 30,
    this.onDark = false,
    super.key,
  });

  final double markSize;
  final double wordSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SkyMark(size: markSize),
      const SizedBox(width: 8),
      SkyWordmark(size: wordSize, onDark: onDark),
    ],
  );
}
