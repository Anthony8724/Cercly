import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';

/// Tarjeta compartida por los resultados generales y las recomendaciones.
/// Conserva toda la información de negocio en el modelo; aquí solo se presenta.
class TarjetaEstablecimientoPublico extends StatelessWidget {
  const TarjetaEstablecimientoPublico({
    required this.establecimiento,
    required this.onTap,
    super.key,
  });

  final EstablecimientoPublicoModel establecimiento;
  final VoidCallback onTap;

  static const _card = Color(0xFF19152D);
  static const _border = Color(0xFF3A3157);
  static const _accent = Color(0xFFBDA7FF);
  static const _text = Color(0xFFF8F5FF);
  static const _muted = Color(0xFFD0C9E4);

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final height = 148.0 * textScale;
    final category = establecimiento.categoria.nombre.trim();
    final distance = establecimiento.distanciaFormateada;

    return Semantics(
      button: true,
      label: [
        establecimiento.nombre,
        if (category.isNotEmpty) category,
        if (distance.isNotEmpty) distance,
        if (establecimiento.tienePromociones) 'Promoción activa',
      ].join(', '),
      child: Material(
        key: Key('establecimiento-${establecimiento.id}'),
        color: _card,
        elevation: 3,
        shadowColor: const Color(0x664E3D83),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: _accent.withValues(alpha: .12),
          highlightColor: _accent.withValues(alpha: .06),
          focusColor: _accent.withValues(alpha: .10),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 106,
                      height: height - 16,
                      child: _FotoEstablecimiento(
                        url: establecimiento.urlFotoPortada,
                        icono: _iconoCategoria(establecimiento.categoria),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 12, 13, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoriaLabel(
                          nombre: category,
                          icono: _iconoCategoria(establecimiento.categoria),
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              establecimiento.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 17,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.2,
                              ),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (distance.isNotEmpty)
                              _MetaChip(
                                key: const Key('distancia-establecimiento'),
                                icon: Icons.near_me_rounded,
                                text: distance,
                              ),
                            if (establecimiento.tienePromociones)
                              const _PromotionChip(),
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

  static IconData _iconoCategoria(CategoriaPublicaModel categoria) {
    final value = '${categoria.icono} ${categoria.slug}'.toLowerCase();
    if (value.contains('restaurant') ||
        value.contains('food') ||
        value.contains('comida')) {
      return Icons.restaurant_rounded;
    }
    if (value.contains('cafe') || value.contains('coffee')) {
      return Icons.local_cafe_rounded;
    }
    if (value.contains('health') ||
        value.contains('medical') ||
        value.contains('salud')) {
      return Icons.health_and_safety_rounded;
    }
    if (value.contains('beauty') ||
        value.contains('spa') ||
        value.contains('belleza')) {
      return Icons.spa_rounded;
    }
    if (value.contains('shop') ||
        value.contains('store') ||
        value.contains('tienda')) {
      return Icons.shopping_bag_rounded;
    }
    if (value.contains('hotel') ||
        value.contains('travel') ||
        value.contains('alojamiento')) {
      return Icons.hotel_rounded;
    }
    if (value.contains('sport') ||
        value.contains('fitness') ||
        value.contains('deporte')) {
      return Icons.fitness_center_rounded;
    }
    if (value.contains('school') ||
        value.contains('education') ||
        value.contains('educacion')) {
      return Icons.school_rounded;
    }
    return Icons.storefront_rounded;
  }
}

class _FotoEstablecimiento extends StatelessWidget {
  const _FotoEstablecimiento({required this.url, required this.icono});

  final String? url;
  final IconData icono;

  static const _accent = Color(0xFFBDA7FF);

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30284D), Color(0xFF211C3B), Color(0xFF17152C)],
        ),
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Icon(icono, size: 34, color: _accent),
          ),
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 480,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (_, _, _) => fallback,
        ),
      ],
    );
  }
}

class _CategoriaLabel extends StatelessWidget {
  const _CategoriaLabel({required this.nombre, required this.icono});

  final String nombre;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 15, color: TarjetaEstablecimientoPublico._accent),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            nombre.isEmpty ? 'Establecimiento' : nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TarjetaEstablecimientoPublico._muted,
              fontSize: 11.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: .15,
            ),
          ),
        ),
        const SizedBox(width: 3),
        const Icon(
          Icons.arrow_outward_rounded,
          size: 15,
          color: TarjetaEstablecimientoPublico._accent,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: TarjetaEstablecimientoPublico._muted),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: TarjetaEstablecimientoPublico._muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PromotionChip extends StatelessWidget {
  const _PromotionChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('indicador-promocion'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: TarjetaEstablecimientoPublico._accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: TarjetaEstablecimientoPublico._accent.withValues(alpha: .3),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_offer_rounded,
            size: 12,
            color: TarjetaEstablecimientoPublico._accent,
          ),
          SizedBox(width: 4),
          Text(
            'Promoción',
            maxLines: 1,
            style: TextStyle(
              color: TarjetaEstablecimientoPublico._accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
