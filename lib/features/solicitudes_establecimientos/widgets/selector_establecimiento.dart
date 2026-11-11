import 'dart:async';

import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../models/solicitud_establecimiento_model.dart';
import '../services/solicitud_establecimiento_service.dart';

/// La selección identifica una ficha; nunca concede acceso a su administración.
class SelectorEstablecimiento extends StatefulWidget {
  const SelectorEstablecimiento({
    super.key,
    required this.service,
    required this.tipo,
    required this.asociados,
  });

  final SolicitudEstablecimientoRepository service;
  final String tipo;
  final List<EstablecimientoSolicitudOpcion> asociados;

  @override
  State<SelectorEstablecimiento> createState() =>
      _SelectorEstablecimientoState();
}

class _SelectorEstablecimientoState extends State<SelectorEstablecimiento> {
  final _busqueda = TextEditingController();
  Timer? _espera;
  List<EstablecimientoSolicitudOpcion> _resultados = [];
  bool _cargando = true;
  bool _error = false;
  bool _hayMas = false;
  int _offset = 0;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    if (widget.tipo == SolicitudEstablecimientoModel.tipoCorreccion) {
      _cargando = false; // Solo negocios asociados, obtenidos del servidor.
    } else {
      _cargar();
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _buscar(String _) {
    if (widget.tipo == SolicitudEstablecimientoModel.tipoCorreccion) {
      setState(() {});
      return;
    }
    _espera?.cancel();
    ++_version; // Invalidar una página anterior incluso durante el debounce.
    setState(() {
      _resultados = [];
      _offset = 0;
      _cargando = true;
      _error = false;
      _hayMas = false;
    });
    _espera = Timer(const Duration(milliseconds: 300), _cargar);
  }

  Future<void> _cargar() async {
    final version = ++_version;
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final pagina = await widget.service.listarEstablecimientosParaTipo(
        widget.tipo,
        busqueda: _busqueda.text,
        offset: _offset,
      );
      if (!mounted || version != _version) return;
      setState(() {
        _resultados = {
          for (final e in [..._resultados, ...pagina]) e.id: e,
        }.values.toList();
        _offset += pagina.length;
        _hayMas = pagina.length == 20;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || version != _version) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final texto = _busqueda.text.trim().toLowerCase();
    final asociados = widget.asociados
        .where((e) => e.nombre.toLowerCase().contains(texto))
        .toList();
    final ids = asociados.map((e) => e.id).toSet();
    final otros = _resultados.where((e) => !ids.contains(e.id)).toList();
    Widget opcion(EstablecimientoSolicitudOpcion e) => Material(
      color: sky.surface,
      child: ListTile(
        key: ValueKey('opcion-${e.id}'),
        leading: Icon(Icons.storefront_outlined, color: sky.interactive),
        title: Text(e.nombre, style: TextStyle(color: sky.text)),
        subtitle: Text(e.direccion, style: TextStyle(color: sky.muted)),
        onTap: () => Navigator.of(context).pop(e),
      ),
    );
    return Container(
      color: sky.surface,
      height: MediaQuery.sizeOf(context).height * .85,
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Elegir establecimiento',
                  style: TextStyle(
                    color: sky.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('buscar-establecimiento'),
            controller: _busqueda,
            onChanged: _buscar,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Buscar por nombre',
              prefixIcon: Icon(Icons.search),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (asociados.isNotEmpty) ...[
                  Text(
                    'Tus negocios asociados',
                    style: TextStyle(
                      color: sky.interactive,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ...asociados.map(opcion),
                ],
                if (otros.isNotEmpty) ...[
                  Text(
                    'Establecimientos disponibles',
                    style: TextStyle(color: sky.muted),
                  ),
                  ...otros.map(opcion),
                ],
                if (!_cargando && !_error && asociados.isEmpty && otros.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No se encontraron establecimientos.'),
                  ),
                if (_cargando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_error) ...[
                  const Text('No se pudieron cargar los resultados.'),
                  TextButton(
                    onPressed: _cargar,
                    child: const Text('Reintentar'),
                  ),
                ] else if (_hayMas && !_cargando)
                  TextButton(
                    onPressed: _cargar,
                    child: const Text('Cargar más'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
