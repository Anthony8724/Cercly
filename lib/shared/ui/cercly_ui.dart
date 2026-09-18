import 'package:flutter/material.dart';

class CerclyColors {
  const CerclyColors._();

  static const blue = Color(0xFF1769FF);
  static const blueDark = Color(0xFF0B4EA9);
  static const navy = Color(0xFF0A2A66);
  static const background = Color(0xFFF5F8FE);
  static const border = Color(0xFFE2E9F5);
  static const text = Color(0xFF102A56);
  static const muted = Color(0xFF65758C);
  static const softBlue = Color(0xFFEAF3FF);
}

class CerclyPageHeader extends StatelessWidget {
  const CerclyPageHeader({
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
    this.onBack,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3F7FE8),
            Color(0xFF174FAD),
            CerclyColors.navy,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 18,
            right: 34,
            child: _Star(size: 5),
          ),
          const Positioned(
            top: 52,
            right: 88,
            child: _Star(size: 3),
          ),
          const Positioned(
            bottom: 26,
            right: 18,
            child: _Star(size: 4),
          ),
          const Positioned(
            bottom: 18,
            left: 92,
            child: _Star(size: 3),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (onBack != null) ...[
                    _HeaderButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Volver',
                      onPressed: onBack!,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    ...actions,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CerclyHeaderAction extends StatelessWidget {
  const CerclyHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _HeaderButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class CerclySectionCard extends StatelessWidget {
  const CerclySectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CerclyColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12031A3A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CerclySectionTitle extends StatelessWidget {
  const CerclySectionTitle({
    required this.title,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CerclyColors.softBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: CerclyColors.blue, size: 21),
          ),
          const SizedBox(width: 11),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: CerclyColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: CerclyColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class CerclyInfoBanner extends StatelessWidget {
  const CerclyInfoBanner({
    required this.text,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CerclyColors.softBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFD8FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CerclyColors.blue, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: CerclyColors.text,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
    );
  }
}
