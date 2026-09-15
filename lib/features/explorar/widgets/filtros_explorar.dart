import 'package:flutter/material.dart';

import '../controllers/explorar_controller.dart';

class FiltrosExplorar extends StatelessWidget {
  const FiltrosExplorar({required this.controller, super.key});

  final ExplorarController controller;

  @override
  Widget build(BuildContext context) {
    return ChipTheme(
      data: ChipTheme.of(context).copyWith(
        backgroundColor: const Color(0xFFEFF4FC),
        selectedColor: const Color(0xFF1769FF),
        checkmarkColor: Colors.white,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? Colors.white : const Color(0xFF0A2A66),
          fontWeight: FontWeight.w600,
        )),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34 + MediaQuery.textScalerOf(context).scale(20),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: const Key('categoria-todas'),
                  label: const Text('Todas'),
                  selected: controller.categoriaId == null,
                  onSelected: (_) => controller.cambiarCategoria(null),
                ),
              ),
              for (final categoria in controller.categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('categoria-${categoria.slug}'),
                    label: Text(categoria.nombre),
                    selected: controller.categoriaId == categoria.id,
                    onSelected: (_) =>
                        controller.cambiarCategoria(categoria.id),
                  ),
                ),
            ],
          ),
        ),
        if (controller.categoriaId != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 30 + MediaQuery.textScalerOf(context).scale(20),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          key: const Key('subcategoria-todas'),
                          label: const Text('Todas las subcategorías'),
                          selected: controller.subcategoriaId == null,
                          onSelected: (_) =>
                              controller.cambiarSubcategoria(null),
                        ),
                      ),
                      for (final subcategoria in controller.subcategorias)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            key: Key('subcategoria-${subcategoria.slug}'),
                            label: Text(subcategoria.nombre),
                            selected:
                                controller.subcategoriaId == subcategoria.id,
                            onSelected: (_) =>
                                controller.cambiarSubcategoria(subcategoria.id),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('filtro-radio'),
                initialValue: controller.radioMetros,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Radio de búsqueda',
                  prefixIcon: Icon(Icons.radar),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
            const SizedBox(width: 10),
            FilterChip(
              key: const Key('solo-promociones'),
              avatar: const Icon(Icons.local_offer_outlined, size: 18),
              label: const Text('Promos'),
              selected: controller.soloPromociones,
              onSelected: controller.cambiarSoloPromociones,
            ),
          ],
        ),
      ],
      ),
    );
  }

  static String _formatearRadio(int metros) {
    if (metros < 1000) return '$metros m';
    return '${metros ~/ 1000} km';
  }
}
