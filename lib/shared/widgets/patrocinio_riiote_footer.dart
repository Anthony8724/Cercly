import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reconocimiento discreto al patrocinador, fuera del flujo principal.
class PatrocinioRiioteFooter extends StatelessWidget {
  const PatrocinioRiioteFooter({super.key, this.abrirEnlace});

  /// Permite probar el enlace sin abrir el navegador.
  final Future<bool> Function(Uri uri)? abrirEnlace;

  static final Uri sitioOficial = Uri.parse('https://riiote.org/');

  Future<void> _abrirSitio(BuildContext context) async {
    var abierto = false;
    try {
      abierto =
          await (abrirEnlace?.call(sitioOficial) ??
              launchUrl(sitioOficial, mode: LaunchMode.externalApplication));
    } catch (_) {
      abierto = false;
    }
    if (!abierto && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el sitio de RIIOTE.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gris = Theme.of(context).colorScheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        key: const Key('patrocinador-riiote'),
        onPressed: () => _abrirSitio(context),
        style: TextButton.styleFrom(
          foregroundColor: gris,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
        child: const Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          runSpacing: 3,
          children: [
            Icon(Icons.handshake_outlined, size: 15),
            Text('Con el patrocinio de ', style: TextStyle(fontSize: 12)),
            Text(
              'RIIOTE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            Icon(Icons.open_in_new, size: 12),
          ],
        ),
      ),
    );
  }
}
