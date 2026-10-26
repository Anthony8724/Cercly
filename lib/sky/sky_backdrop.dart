import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sky_ambient_painter.dart';
import 'sky_theme.dart';

const _stillMotion = AlwaysStoppedAnimation<double>(0);

class _SkyMotionScope extends InheritedWidget {
  const _SkyMotionScope({required this.motion, required super.child});

  final ValueListenable<double> motion;

  static ValueListenable<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkyMotionScope>()?.motion ??
      _stillMotion;

  @override
  bool updateShouldNotify(_SkyMotionScope oldWidget) =>
      motion != oldWidget.motion;
}

/// Capa que solo repinta su CustomPaint; no recibe gestos ni semántica.
class SkyAmbientLayer extends StatelessWidget {
  const SkyAmbientLayer({this.header = false, this.intensity = .65, super.key});

  final bool header;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final palette = SkyPalette.of(context);
    if (!palette.decorationsEnabled) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SkyAmbientPainter(
              palette: palette,
              motion: _SkyMotionScope.of(context),
              header: header,
              intensity: intensity,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecera con gradiente y dibujo ambiental. Una foto oficial sigue siendo opcional.
class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({
    required this.child,
    this.cityImage,
    this.ambient = true,
    super.key,
  });

  final Widget child;
  final ImageProvider? cityImage;
  final bool ambient;

  @override
  Widget build(BuildContext context) {
    final palette = SkyPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette.headerGradient,
        image: cityImage == null
            ? null
            : DecorationImage(
                image: cityImage!,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  palette.headerStart.withValues(alpha: .42),
                  BlendMode.darken,
                ),
              ),
      ),
      child: Stack(
        children: [
          if (ambient)
            const Positioned.fill(
              child: SkyAmbientLayer(header: true, intensity: .65),
            ),
          child,
        ],
      ),
    );
  }
}

/// Un reloj de 8 Hz por pantalla visible. Cabecera y fondo comparten fase.
class SkySurface extends StatefulWidget {
  const SkySurface({
    required this.child,
    this.stars = true,
    this.intensity = .65,
    super.key,
  });

  final Widget child;

  /// Conserva el parámetro previo; ahora controla todas las decoraciones.
  final bool stars;
  final double intensity;

  @override
  State<SkySurface> createState() => _SkySurfaceState();
}

class _SkySurfaceState extends State<SkySurface> with WidgetsBindingObserver {
  final ValueNotifier<double> _motion = ValueNotifier(0);
  Timer? _timer;
  ValueListenable<TickerModeData>? _tickerMode;
  double _elapsedSeconds = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextTickerMode = TickerMode.getValuesNotifier(context);
    if (_tickerMode != nextTickerMode) {
      _tickerMode?.removeListener(_syncMotion);
      _tickerMode = nextTickerMode;
      _tickerMode!.addListener(_syncMotion);
    }
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant SkySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    final palette = SkyPalette.of(context);
    final media = MediaQuery.maybeOf(context);
    final reduced =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    final active =
        widget.stars &&
        palette.decorationsEnabled &&
        !reduced &&
        _foreground &&
        (_tickerMode?.value.enabled ?? true);
    if (active && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 125), (_) {
        _elapsedSeconds += .125;
        _motion.value = _elapsedSeconds;
      });
    } else if (!active && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_syncMotion);
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyPalette.of(context);
    return _SkyMotionScope(
      motion: _motion,
      child: ColoredBox(
        color: palette.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.stars)
              Positioned.fill(
                child: SkyAmbientLayer(intensity: widget.intensity),
              ),
            Material(type: MaterialType.transparency, child: widget.child),
          ],
        ),
      ),
    );
  }
}
