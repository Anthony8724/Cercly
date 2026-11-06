import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';

class CorreccionRevisada {
  const CorreccionRevisada(this.motivo);
  final String motivo;
}

class RevisarCorreccionDialog extends StatefulWidget {
  const RevisarCorreccionDialog({
    super.key,
    required this.cambios,
    required this.solicitud,
    this.categorias = const [],
  });
  final Map<String, dynamic> cambios;
  final String solicitud;
  final List<Map<String, dynamic>> categorias;
  @override
  State<RevisarCorreccionDialog> createState() =>
      _RevisarCorreccionDialogState();
}

class _RevisarCorreccionDialogState extends State<RevisarCorreccionDialog> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  static const etiquetas = {
    'nombre': 'Nombre',
    'direccion': 'Dirección',
    'categoria_id': 'Categoría',
    'descripcion': 'Descripción',
    'telefono_publico': 'Teléfono público',
    'latitud': 'Latitud',
    'longitud': 'Longitud',
  };
  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  String mostrar(String campo, Object? valor) {
    if (campo == 'categoria_id') {
      for (final categoria in widget.categorias) {
        if (categoria['id'] == valor) return categoria['nombre'] as String;
      }
    }
    return '$valor';
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return AlertDialog(
      title: const Text('Revisar corrección solicitada'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Motivo del solicitante: ${widget.solicitud}'),
                const SizedBox(height: 14),
                const Text(
                  'Al aprobar se aplicarán exactamente estos valores. Para pedir otros, rechaza la solicitud.',
                ),
                const SizedBox(height: 12),
                if (widget.cambios.isEmpty)
                  const Text(
                    'Esta solicitud antigua no contiene campos estructurados y no puede aprobarse.',
                  ),
                for (final item in widget.cambios.entries)
                  if (etiquetas.containsKey(item.key))
                    ListTile(
                      title: Text(etiquetas[item.key]!),
                      subtitle: Text(
                        'Actual: ${mostrar(item.key, item.value['anterior'])}\nPropuesto: ${mostrar(item.key, item.value['nuevo'])}',
                        style: TextStyle(color: sky.muted),
                      ),
                      isThreeLine: true,
                    ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motivo,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la aprobación',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Explica la revisión.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: widget.cambios.isEmpty
              ? null
              : () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      CorreccionRevisada(_motivo.text.trim()),
                    );
                  }
                },
          child: const Text('Aprobar cambios solicitados'),
        ),
      ],
    );
  }
}
