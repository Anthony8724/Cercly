import 'package:flutter/material.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({super.key, required this.child, this.staging});

  final Widget child;
  final bool? staging;

  @override
  Widget build(BuildContext context) {
    final showStaging = staging ?? const bool.fromEnvironment('CERCLY_STAGING');
    if (!showStaging) return child;
    return Banner(
      message: 'STAGING',
      location: BannerLocation.topEnd,
      color: const Color(0xffa83a18),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
      child: child,
    );
  }
}
