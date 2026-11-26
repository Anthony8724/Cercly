import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Créditos visibles y accesibles, también en pantallas estrechas.
class AtribucionMapa extends StatelessWidget {
  const AtribucionMapa({this.rutas = false, this.abrirEnlace, super.key});

  final bool rutas;
  final Future<bool> Function(Uri)? abrirEnlace;

  Future<void> _abrir(BuildContext context, String url) async {
    var abierto = false;
    try {
      final uri = Uri.parse(url);
      abierto =
          await (abrirEnlace?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      abierto = false;
    }
    if (!abierto && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la atribución.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _enlace(
          context,
          '© OpenStreetMap contributors',
          'https://www.openstreetmap.org/copyright',
        ),
        if (rutas)
          _enlace(
            context,
            '© openrouteservice by HeiGIT',
            'https://account.heigit.org/info/tos',
          ),
      ],
    ),
  );

  Widget _enlace(BuildContext context, String texto, String url) => TextButton(
    onPressed: () => _abrir(context, url),
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF253041),
      textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    ),
    child: Text(texto),
  );
}
