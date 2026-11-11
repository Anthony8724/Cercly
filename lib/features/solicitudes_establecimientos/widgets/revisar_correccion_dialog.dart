import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../models/propuesta_correccion.dart';

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
    this.actuales,
    this.establecimiento = '',
    this.solicitante = '',
    this.fecha,
  });
  final Map<String, dynamic> cambios;
  final String solicitud;
  final List<Map<String, dynamic>> categorias;
  final Map<String, dynamic>? actuales;
  final String establecimiento;
  final String solicitante;
  final DateTime? fecha;
  @override
  State<RevisarCorreccionDialog> createState() =>
      _RevisarCorreccionDialogState();
}

class _RevisarCorreccionDialogState extends State<RevisarCorreccionDialog> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validos = PropuestaCorreccion.validar(widget.cambios);
    final obsoleta =
        widget.actuales != null &&
        widget.cambios.entries.any(
          (e) =>
              e.value is! Map || widget.actuales![e.key] != e.value['anterior'],
        );
    return AlertDialog(
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: SkyPalette.of(context).text,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: SkyPalette.of(context).text),
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
                if (widget.establecimiento.isNotEmpty)
                  Text('Establecimiento: ${widget.establecimiento}'),
                if (widget.solicitante.isNotEmpty)
                  Text('Solicitante: ${widget.solicitante}'),
                if (widget.fecha != null)
                  Text('Fecha: ${widget.fecha!.toLocal()}'),
                const Text('Estado: Pendiente'),
                Text(
                  'Motivo del solicitante: ${widget.solicitud.isEmpty ? 'Sin motivo adicional' : widget.solicitud}',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Al aprobar se aplicarán exactamente estos valores. Para pedir otros, rechaza la solicitud.',
                ),
                const SizedBox(height: 12),
                if (widget.cambios.isEmpty)
                  const Text(
                    'Esta solicitud antigua no contiene campos estructurados y no puede aprobarse.',
                  ),
                DiferenciasCorreccion(
                  cambios: widget.cambios,
                  actuales: widget.actuales,
                  categorias: widget.categorias,
                ),
                if (obsoleta)
                  const Text(
                    'La ficha cambió desde la solicitud. No se puede aplicar esta propuesta; solicita una revisión nueva.',
                  ),
                if (widget.actuales == null && widget.cambios.isNotEmpty)
                  const Text('No se ha verificado la ficha actual.'),
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
          onPressed: validos == null || obsoleta || widget.actuales == null
              ? null
              : () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      CorreccionRevisada(_motivo.text.trim()),
                    );
                  }
                },
          child: const Text('Aprobar y aplicar'),
        ),
      ],
    );
  }
}

class DiferenciasCorreccion extends StatelessWidget {
  const DiferenciasCorreccion({
    super.key,
    required this.cambios,
    this.actuales,
    this.categorias = const [],
  });
  final Map<String, dynamic> cambios;
  final Map<String, dynamic>? actuales;
  final List<Map<String, dynamic>> categorias;
  String mostrar(String campo, Object? value) {
    if (value == null) return 'Sin dato';
    if (campo == 'categoria_id') {
      for (final c in categorias) {
        if (c['id'] == value) return c['nombre'] as String;
      }
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in cambios.entries)
        if (PropuestaCorreccion.etiquetas.containsKey(e.key) && e.value is Map)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PropuestaCorreccion.etiquetas[e.key]!,
                  style: TextStyle(
                    color: SkyPalette.of(context).text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Al solicitar: ${mostrar(e.key, e.value['anterior'])}',
                  style: TextStyle(color: SkyPalette.of(context).muted),
                ),
                if (actuales != null)
                  Text('Actual: ${mostrar(e.key, actuales![e.key])}'),
                Text('Propuesto: ${mostrar(e.key, e.value['nuevo'])}'),
              ],
            ),
          ),
      if (PropuestaCorreccion.validar(cambios) == null)
        const Text(
          'La propuesta estructurada no es válida y no se puede aplicar.',
        ),
    ],
  );
}
