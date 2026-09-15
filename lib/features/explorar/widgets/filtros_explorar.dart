import 'package:flutter/material.dart';

import '../controllers/explorar_controller.dart';

class FiltrosExplorar extends StatelessWidget {
  const FiltrosExplorar({required this.controller, super.key});

  final ExplorarController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _CategoriaChip(
                  key: const Key('categoria-todas'),
                  icono: Icons.grid_view_rounded,
                  texto: 'Todas',
                  seleccionado: controller.categoriaId == null,
                  onTap: () => controller.cambiarCategoria(null),
                ),
              ),
              for (final categoria in controller.categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoriaChip(
                    key: Key('categoria-${categoria.slug}'),
                    icono: _iconoCategoria(categoria.slug, categoria.nombre),
                    texto: categoria.nombre,
                    seleccionado: controller.categoriaId == categoria.id,
                    onTap: () => controller.cambiarCategoria(categoria.id),
                  ),
                ),
            ],
          ),
        ),
        if (controller.categoriaId != null) ...[
          const SizedBox(height: 9),
          SizedBox(
            height: 36,
            child: controller.cargandoTaxonomia
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SubcategoriaChip(
                          key: const Key('subcategoria-todas'),
                          texto: 'Todas las subcategorías',
                          seleccionado: controller.subcategoriaId == null,
                          onTap: () => controller.cambiarSubcategoria(null),
                        ),
                      ),
                      for (final subcategoria in controller.subcategorias)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SubcategoriaChip(
                            key: Key('subcategoria-${subcategoria.slug}'),
                            texto: subcategoria.nombre,
                            seleccionado:
                                controller.subcategoriaId == subcategoria.id,
                            onTap: () =>
                                controller.cambiarSubcategoria(subcategoria.id),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 58,
                child: DropdownButtonFormField<int>(
                  key: const Key('filtro-radio'),
                  initialValue: controller.radioMetros,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF52647F),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Radio de búsqueda',
                    labelStyle: const TextStyle(
                      color: Color(0xFF6B7A90),
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF24446F),
                      size: 23,
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(12, 4, 10, 5),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: Color(0xFFCBD7E8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(
                        color: Color(0xFF1769FF),
                        width: 1.4,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF16233A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  items: ExplorarController.radiosDisponibles
                      .map(
                        (radio) => DropdownMenuItem(
                          value: radio,
                          child: Text(_formatearRadio(radio)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (radio) {
                    if (radio != null) controller.cambiarRadio(radio);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _BotonPromos(
                seleccionado: controller.soloPromociones,
                onTap: () => controller
                    .cambiarSoloPromociones(!controller.soloPromociones),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconoCategoria(String slug, String nombre) {
    final texto = '$slug $nombre'.toLowerCase();
    if (texto.contains('restaur') || texto.contains('comida')) {
      return Icons.restaurant_rounded;
    }
    if (texto.contains('cafe') || texto.contains('cafeter')) {
      return Icons.local_cafe_rounded;
    }
    if (texto.contains('tienda') || texto.contains('comerc')) {
      return Icons.shopping_bag_rounded;
    }
    if (texto.contains('market') || texto.contains('mercado')) {
      return Icons.shopping_cart_rounded;
    }
    if (texto.contains('servicio') || texto.contains('oficio')) {
      return Icons.handyman_rounded;
    }
    if (texto.contains('entreten')) return Icons.movie_rounded;
    if (texto.contains('salud')) return Icons.local_hospital_rounded;
    if (texto.contains('belleza')) return Icons.spa_rounded;
    return Icons.more_horiz_rounded;
  }

  static String _formatearRadio(int metros) {
    if (metros < 1000) return '$metros m';
    return '${metros ~/ 1000} km';
  }
}

class _CategoriaChip extends StatelessWidget {
  const _CategoriaChip({
    required this.icono,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    super.key,
  });

  final IconData icono;
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fondo =
        seleccionado ? const Color(0xFF1769FF) : const Color(0xFFF3F6FB);
    final color = seleccionado ? Colors.white : const Color(0xFF233A5E);

    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: seleccionado
                  ? const Color(0xFF1769FF)
                  : const Color(0xFFE3EAF5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoriaChip extends StatelessWidget {
  const _SubcategoriaChip({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    super.key,
  });

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? const Color(0xFFE6F0FF) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado
                  ? const Color(0xFF84B5FF)
                  : const Color(0xFFDDE6F2),
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: seleccionado
                  ? const Color(0xFF0B58D4)
                  : const Color(0xFF44556F),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonPromos extends StatelessWidget {
  const _BotonPromos({required this.seleccionado, required this.onTap});

  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fondo = seleccionado ? const Color(0xFF1769FF) : Colors.white;
    final color = seleccionado ? Colors.white : const Color(0xFF1769FF);

    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: const Key('solo-promociones'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: seleccionado
                  ? const Color(0xFF1769FF)
                  : const Color(0xFF7EB0FF),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_offer_outlined, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                'Promos',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
