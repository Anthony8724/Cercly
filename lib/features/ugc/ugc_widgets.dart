import 'package:flutter/material.dart';

import 'ugc_service.dart';
import 'ugc_screen.dart';

Future<bool> asegurarNormasPublicacion(
  BuildContext context, {
  UgcService? service,
}) async {
  final api = service ?? UgcService();
  try {
    final normas = await api.normas();
    if (normas['aceptadas'] == true) return true;
    if (!context.mounted) return false;
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('Normas y términos de publicación'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text('${normas['texto']}\n\nVersión: ${normas['version']}'),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('ugc-cancelar-normas'),
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('ugc-aceptar-normas'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('He leído y acepto'),
          ),
        ],
      ),
    );
    if (aceptar != true) return false;
    await api.aceptar(normas);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron verificar las normas. No se enviará contenido. Inicia sesión o reintenta.',
          ),
        ),
      );
    }
    return false;
  }
}

class AccionesContenido extends StatelessWidget {
  const AccionesContenido({
    required this.tipo,
    required this.id,
    this.service,
    this.alBloquear,
    super.key,
  });
  final String tipo, id;
  final UgcService? service;
  final VoidCallback? alBloquear;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Denunciar o bloquear',
    icon: const Icon(Icons.shield_outlined),
    onSelected: (accion) async {
      final api = service ?? UgcService();
      if (accion == 'seguridad') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => UgcScreen(service: api)),
        );
      } else if (accion == 'denunciar') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DenunciarScreen(tipo: tipo, id: id, service: api),
          ),
        );
      } else {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Bloquear al responsable'),
            content: const Text(
              'Se ocultarán para tu cuenta los establecimientos y publicaciones de esta cuenta responsable. No recibirá tu identidad. Puedes desbloquearla en Seguridad y contenido. Las fichas sin responsable de cuenta solo se pueden denunciar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Bloquear'),
              ),
            ],
          ),
        );
        if (confirmar != true) return;
        try {
          await api.bloquear(tipo, id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Responsable bloqueado. El catálogo se actualizará.',
              ),
            ),
          );
          alBloquear?.call();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo bloquear. Inicia sesión; la ficha debe tener un responsable disponible.',
                ),
              ),
            );
          }
        }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'denunciar', child: Text('Denunciar contenido')),
      PopupMenuItem(value: 'bloquear', child: Text('Bloquear al responsable')),
      PopupMenuItem(value: 'seguridad', child: Text('Seguridad y contenido')),
    ],
  );
}

class DenunciarScreen extends StatefulWidget {
  const DenunciarScreen({
    required this.tipo,
    required this.id,
    required this.service,
    super.key,
  });
  final String tipo, id;
  final UgcService service;
  @override
  State<DenunciarScreen> createState() => _DenunciarScreenState();
}

class _DenunciarScreenState extends State<DenunciarScreen> {
  String _motivo = 'ofensivo';
  final _detalle = TextEditingController();
  bool _enviando = false;
  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      await widget.service.denunciar(
        widget.tipo,
        widget.id,
        _motivo,
        _detalle.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Denuncia registrada para revisión. No retira automáticamente el contenido.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se registró la denuncia. Inicia sesión y reintenta. Hay límites de frecuencia y no se duplican denuncias abiertas.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Denunciar ${widget.tipo}')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'No incluyas contraseñas, datos privados ni información de otras personas. La denuncia se revisa sin mostrar tu identidad al responsable.',
        ),
        DropdownButtonFormField<String>(
          initialValue: _motivo,
          decoration: const InputDecoration(labelText: 'Motivo'),
          items:
              const {
                    'ofensivo': 'Ofensivo o acoso',
                    'ilegal': 'Ilegal',
                    'enganoso': 'Engañoso o fraude',
                    'discriminatorio': 'Discriminatorio',
                    'derechos': 'Vulnera derechos de terceros',
                    'privacidad': 'Expone datos privados',
                    'spam': 'Spam',
                    'otro': 'Otro',
                  }.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
          onChanged: _enviando ? null : (v) => setState(() => _motivo = v!),
        ),
        TextField(
          controller: _detalle,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Detalle opcional'),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando…' : 'Enviar denuncia'),
        ),
      ],
    ),
  );
}
