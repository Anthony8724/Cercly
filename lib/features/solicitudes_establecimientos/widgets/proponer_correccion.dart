import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';

class ProponerCorreccion extends StatefulWidget {
  const ProponerCorreccion({
    super.key,
    required this.actuales,
    required this.categorias,
    required this.onChanged,
  });
  final Map<String, dynamic> actuales;
  final List<Map<String, dynamic>> categorias;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  State<ProponerCorreccion> createState() => _ProponerCorreccionState();
}

class _ProponerCorreccionState extends State<ProponerCorreccion> {
  static const etiquetas = <String, String>{
    'nombre': 'Nombre',
    'direccion': 'Dirección',
    'categoria_id': 'Categoría',
    'descripcion': 'Descripción',
    'telefono_publico': 'Teléfono público',
    'latitud': 'Latitud',
    'longitud': 'Longitud',
  };
  final seleccionados = <String>{};
  late final Map<String, TextEditingController> controles = {
    for (final campo in etiquetas.keys)
      if (campo != 'categoria_id')
        campo: TextEditingController(text: '${widget.actuales[campo] ?? ''}'),
  };
  late String? categoria =
      widget.categorias.any((c) => c['id'] == widget.actuales['categoria_id'])
      ? widget.actuales['categoria_id'] as String?
      : null;
  @override
  void dispose() {
    for (final c in controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  void publicar() {
    final cambios = <String, dynamic>{};
    for (final campo in seleccionados) {
      final nuevo = campo == 'categoria_id'
          ? categoria
          : campo == 'latitud' || campo == 'longitud'
          ? double.tryParse(controles[campo]!.text.trim())
          : controles[campo]!.text.trim();
      cambios[campo] = {'anterior': widget.actuales[campo], 'nuevo': nuevo};
    }
    widget.onChanged(cambios);
  }

  String actual(String campo) {
    if (campo == 'categoria_id') {
      for (final c in widget.categorias) {
        if (c['id'] == widget.actuales[campo]) return c['nombre'] as String;
      }
    }
    return '${widget.actuales[campo] ?? 'Sin dato'}';
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return FormField<Map<String, dynamic>>(
      validator: (_) => seleccionados.isEmpty
          ? 'Selecciona al menos un dato para corregir.'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cambios propuestos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final campo in etiquetas.keys) ...[
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: ValueKey('seleccionar-$campo'),
                contentPadding: EdgeInsets.zero,
                title: Text(etiquetas[campo]!),
                subtitle: Text(
                  'Actual: ${actual(campo)}',
                  style: TextStyle(color: sky.muted),
                ),
                value: seleccionados.contains(campo),
                onChanged: (valor) {
                  setState(() {
                    if (valor == true) {
                      seleccionados.add(campo);
                    } else {
                      seleccionados.remove(campo);
                    }
                  });
                  publicar();
                  field.didChange({});
                },
              ),
            ),
            if (seleccionados.contains(campo)) ...[
              if (campo == 'categoria_id')
                DropdownButtonFormField<String>(
                  key: const Key('nuevo-categoria_id'),
                  initialValue: categoria,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría propuesta',
                  ),
                  items: widget.categorias
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id'] as String,
                          child: Text(
                            c['nombre'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      categoria = v;
                      publicar();
                    }
                  },
                  validator: (v) => v == null || v == widget.actuales[campo]
                      ? 'Elige una categoría diferente.'
                      : null,
                )
              else
                TextFormField(
                  key: ValueKey('nuevo-$campo'),
                  controller: controles[campo],
                  decoration: InputDecoration(
                    labelText: 'Nuevo ${etiquetas[campo]!.toLowerCase()}',
                  ),
                  onChanged: (_) => publicar(),
                  validator: (v) {
                    final texto = (v ?? '').trim();
                    if (campo == 'latitud' || campo == 'longitud') {
                      final n = double.tryParse(texto);
                      final limite = campo == 'latitud' ? 90 : 180;
                      if (n == null || !n.isFinite || n.abs() > limite) {
                        return 'Coordenada inválida.';
                      }
                      if (n == widget.actuales[campo]) {
                        return 'El valor no cambió.';
                      }
                      return null;
                    }
                    final limite = switch (campo) {
                      'nombre' => 120,
                      'direccion' => 250,
                      'telefono_publico' => 20,
                      _ => 1000,
                    };
                    if (texto.length > limite ||
                        (campo == 'nombre' && texto.length < 2) ||
                        (campo == 'direccion' && texto.isEmpty)) {
                      return 'Valor inválido.';
                    }
                    if (texto == widget.actuales[campo]) {
                      return 'El valor no cambió.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
            ],
          ],
          if (field.hasError)
            Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
