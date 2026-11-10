import 'package:flutter/material.dart';

/// Una decisión cerrada de moderación; no contiene datos editables del negocio.
class DecisionModeracion {
  const DecisionModeracion({required this.publicar});
  final bool publicar;
}

class ModeracionEstablecimientoDialog extends StatefulWidget {
  const ModeracionEstablecimientoDialog({
    required this.nombre,
    required this.aprobar,
    super.key,
  });

  final String nombre;
  final bool aprobar;

  @override
  State<ModeracionEstablecimientoDialog> createState() =>
      _ModeracionEstablecimientoDialogState();
}

class _ModeracionEstablecimientoDialogState
    extends State<ModeracionEstablecimientoDialog> {
  bool _publicar = true;

  @override
  Widget build(BuildContext context) => AlertDialog(
    titleTextStyle: Theme.of(context).textTheme.titleLarge
        ?.merge(Theme.of(context).dialogTheme.titleTextStyle),
    contentTextStyle: Theme.of(context).textTheme.bodyMedium
        ?.merge(Theme.of(context).dialogTheme.contentTextStyle),
    title: Text(
      widget.aprobar ? 'Aprobar establecimiento' : 'Rechazar establecimiento',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.nombre),
          const SizedBox(height: 12),
          Text(
            widget.aprobar
                ? 'La aprobación y la publicación son decisiones distintas. Los datos de la ficha no se editan aquí.'
                : 'La ficha quedará rechazada y dejará de estar publicada.',
          ),
          if (widget.aprobar)
            CheckboxListTile(
              key: const Key('moderacion-publicar'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _publicar,
              onChanged: (value) => setState(() => _publicar = value ?? false),
              title: const Text('Publicar para los usuarios de Cercly'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('confirmar-moderacion'),
        onPressed: () => Navigator.pop(
          context,
          DecisionModeracion(publicar: widget.aprobar && _publicar),
        ),
        child: Text(
          widget.aprobar
              ? (_publicar ? 'Aprobar y publicar' : 'Aprobar sin publicar')
              : 'Rechazar y retirar publicación',
        ),
      ),
    ],
  );
}
