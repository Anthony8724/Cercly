import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../../establecimientos/models/establecimiento_publico_model.dart';

/// Ficha compacta compartida por resultados y recomendaciones.
class TarjetaEstablecimientoPublico extends StatelessWidget {
  const TarjetaEstablecimientoPublico({
    required this.establecimiento,
    required this.onTap,
    super.key,
  });
  final EstablecimientoPublicoModel establecimiento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final category = establecimiento.categoria.nombre.trim();
    final distance = establecimiento.distanciaFormateada;
    final icon = _iconoCategoria(establecimiento.categoria);
    final hasPhoto = establecimiento.urlFotoPortada?.trim().isNotEmpty == true;
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
        color: sky.surface,
        elevation: sky.environment == SkyEnvironment.noche ? 0 : .7,
        shadowColor: sky.headerStart.withValues(alpha: .09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: sky.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: sky.interactive.withValues(alpha: .10),
          highlightColor: sky.interactive.withValues(alpha: .05),
          focusColor: sky.interactive.withValues(alpha: .10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: hasPhoto ? 70 : 54,
                    height: hasPhoto ? 70 : 54,
                    child: _FotoEstablecimiento(
                      url: establecimiento.urlFotoPortada,
                      icono: icon,
                      sky: sky,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        establecimiento.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: sky.text,
                          fontSize: 15.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(icon, size: 14, color: sky.interactive),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              category.isEmpty ? 'Establecimiento' : category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: sky.muted,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (distance.isNotEmpty ||
                          establecimiento.tienePromociones) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 10,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (distance.isNotEmpty)
                              Row(
                                key: const Key('distancia-establecimiento'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: 13,
                                    color: sky.muted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    distance,
                                    style: TextStyle(
                                      color: sky.muted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            if (establecimiento.tienePromociones)
                              Container(
                                key: const Key('indicador-promocion'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: sky.soft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_offer_rounded,
                                      size: 12,
                                      color: sky.interactive,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Promoción',
                                      style: TextStyle(
                                        color: sky.interactive,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.chevron_right_rounded, size: 18, color: sky.muted),
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
  const _FotoEstablecimiento({
    required this.url,
    required this.icono,
    required this.sky,
  });
  final String? url;
  final IconData icono;
  final SkyPalette sky;
  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(color: sky.soft),
      child: Center(child: Icon(icono, size: 25, color: sky.interactive)),
    );
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 240,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, loaded) => loaded
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 220),
                  child: child,
                ),
          errorBuilder: (_, _, _) => fallback,
        ),
      ],
    );
  }
}
