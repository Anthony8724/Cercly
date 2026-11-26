import 'package:flutter/material.dart';

import 'ugc_service.dart';
import 'ugc_widgets.dart';

class UgcScreen extends StatefulWidget {
  const UgcScreen({this.service, this.administracion = false, super.key});
  final UgcService? service;
  final bool administracion;
  @override
  State<UgcScreen> createState() => _UgcScreenState();
}

class _UgcScreenState extends State<UgcScreen> {
  late final UgcService _api = widget.service ?? UgcService();
  late Future<List<List<Map<String, dynamic>>>> _datos;
  String _estado = 'nueva';
  bool _ocupado = false;
  final _contextos = <String, Future<Map<String, dynamic>>>{};
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _contextos.clear();
    _datos = Future.wait([
      widget.administracion
          ? Future.value(<Map<String, dynamic>>[])
          : _api.bloqueos(),
      _api.denuncias(estado: widget.administracion ? _estado : null),
    ]);
  }

  Future<void> _accion(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) setState(_cargar);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo completar. Comprueba tu sesión, permisos y los datos.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _revisar(Map<String, dynamic> d, String estado) async {
    var texto = '';
    final motivo = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Decisión: $estado'),
        content: TextField(
          onChanged: (value) => texto = value,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Motivo (mínimo 10 caracteres)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (texto.trim().length >= 10) {
                Navigator.pop(dialog, texto.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (motivo != null) {
      await _accion(() => _api.revisar(d['id'] as String, estado, motivo));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.administracion
            ? 'Denuncias y moderación'
            : 'Seguridad y contenido',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!widget.administracion)
          FilledButton(
            onPressed: _ocupado
                ? null
                : () async {
                    await asegurarNormasPublicacion(context, service: _api);
                  },
            child: const Text('Leer normas de publicación'),
          ),
        if (widget.administracion)
          DropdownButton<String>(
            value: _estado,
            items: [
              'nueva',
              'en_revision',
              'retirada',
              'desestimada',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: _ocupado
                ? null
                : (s) => setState(() {
                    _estado = s!;
                    _cargar();
                  }),
          ),
        FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: _datos,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text(
                    'No disponible. Inicia sesión y comprueba permisos.',
                  ),
                  TextButton(
                    onPressed: () => setState(_cargar),
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bloqueos = snapshot.data![0], denuncias = snapshot.data![1];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.administracion) ...[
                  Text('Responsables bloqueados: ${bloqueos.length}'),
                  for (var i = 0; i < bloqueos.length; i++)
                    ListTile(
                      title: Text(
                        'Responsable de ${bloqueos[i]['referencia'] ?? 'publicación ${i + 1}'}',
                      ),
                      subtitle: Text('${bloqueos[i]['fecha']}'),
                      trailing: TextButton(
                        onPressed: _ocupado
                            ? null
                            : () => _accion(
                                () => _api.desbloquear(
                                  bloqueos[i]['id'] as String,
                                ),
                              ),
                        child: const Text('Desbloquear'),
                      ),
                    ),
                ],
                Text(
                  widget.administracion ? 'Cola de denuncias' : 'Mis denuncias',
                ),
                if (denuncias.isEmpty)
                  const Text('Sin denuncias en esta lista.'),
                for (final d in denuncias)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d['tipo']} · ${d['motivo']} · ${d['estado']}',
                          ),
                          Text('${d['detalle']}'),
                          if (widget.administracion) ...[
                            Text('Contenido: ${d['objetivo_id']}'),
                            FutureBuilder<Map<String, dynamic>>(
                              future: _contextos.putIfAbsent(
                                d['id'] as String,
                                () => _api.contexto(d['id'] as String),
                              ),
                              builder: (context, c) {
                                if (c.hasError) {
                                  return const Text(
                                    'No se pudo cargar el contenido. Reintenta antes de decidir.',
                                  );
                                }
                                if (!c.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                final data = c.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${data['nombre'] ?? 'Contenido ya no disponible'}',
                                    ),
                                    Text('${data['titulo'] ?? ''}'),
                                    Text(
                                      '${data['texto'] ?? data['descripcion'] ?? ''}',
                                    ),
                                    if (data['url'] is String)
                                      Image.network(
                                        data['url'] as String,
                                        height: 180,
                                        errorBuilder: (_, _, _) => const Text(
                                          'No se pudo cargar la imagen.',
                                        ),
                                      ),
                                    Text(
                                      'Historial: ${data['historial'] ?? []}',
                                    ),
                                  ],
                                );
                              },
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final estado in [
                                  'en_revision',
                                  'retirada',
                                  'desestimada',
                                ])
                                  if (![
                                    'retirada',
                                    'desestimada',
                                  ].contains(d['estado']))
                                    TextButton(
                                      onPressed: _ocupado
                                          ? null
                                          : () => _revisar(d, estado),
                                      child: Text(
                                        estado == 'retirada'
                                            ? 'Retirar del catálogo'
                                            : estado == 'en_revision'
                                            ? 'Iniciar revisión'
                                            : 'Desestimar',
                                      ),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
