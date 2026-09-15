import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../promociones/models/promocion_destacada_model.dart';
import '../../promociones/services/promocion_publica_service.dart';

typedef CargarPromocionesExplorar = Future<List<PromocionDestacadaModel>> Function();

/// Usa los establecimientos de la página actual, en el orden del RPC.
/// No calcula distancias ni sustituye los filtros de PostGIS.
class PromocionesExplorar extends StatefulWidget {
  const PromocionesExplorar({
    required this.establecimientos,
    required this.onEstablecimiento,
    required this.onVerTodas,
    this.cargarPromociones,
    super.key,
  });

  final List<EstablecimientoPublicoModel> establecimientos;
  final ValueChanged<EstablecimientoPublicoModel> onEstablecimiento;
  final VoidCallback onVerTodas;
  final CargarPromocionesExplorar? cargarPromociones;

  @override
  State<PromocionesExplorar> createState() => _PromocionesExplorarState();
}

class _PromocionesExplorarState extends State<PromocionesExplorar> {
  List<PromocionDestacadaModel> _promociones = const [];
  bool _cargando = false;
  bool _error = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PromocionesExplorar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.establecimientos, widget.establecimientos) ||
        oldWidget.cargarPromociones != widget.cargarPromociones) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final version = ++_version;
    _promociones = const [];
    _error = false;
    if (!widget.establecimientos.any((e) => e.tienePromociones)) {
      _cargando = false;
      return;
    }
    _cargando = true;
    try {
      // El servicio existente excluye inactivas, vencidas y negocios no públicos.
      final promociones = await (widget.cargarPromociones?.call() ??
          PromocionPublicaService().listarVigentes());
      if (!mounted || version != _version) return;
      setState(() {
        _promociones = promociones;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || version != _version) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(key: Key('promociones-loading')),
      );
    }
    if (_error) {
      return TextButton.icon(
        key: const Key('promociones-reintentar'),
        onPressed: () { setState(() { _cargar(); }); },
        icon: const Icon(Icons.refresh),
        label: const Text('No pudimos cargar promociones. Reintentar'),
      );
    }
    final ahora = DateTime.now();
    final items = [
      for (final establecimiento in widget.establecimientos)
        for (final promocion in _promociones)
          if (promocion.establecimientoId == establecimiento.id &&
              promocion.activa && promocion.estaVigenteEn(ahora))
            (establecimiento, promocion),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(children: [
          const Icon(Icons.star_rounded, color: Color(0xFF1769FF)),
          const SizedBox(width: 6),
          const Expanded(child: Text('Promociones cerca de ti', style: TextStyle(
            color: Color(0xFF0A2A66), fontSize: 18, fontWeight: FontWeight.w800))),
          TextButton(
            key: const Key('ver-todas-promociones'),
            onPressed: widget.onVerTodas,
            child: const Text('Ver todas ›'),
          ),
        ]),
        const Text('En los lugares mostrados', style: TextStyle(
          color: Color(0xFF6F819F), fontSize: 12)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final (establecimiento, promocion) in items)
              SizedBox(
                width: 190,
                child: Card(
                  key: Key('promocion-${promocion.id}'),
                  color: Colors.white,
                  elevation: 1,
                  margin: const EdgeInsets.only(right: 12, bottom: 6),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () => widget.onEstablecimiento(establecimiento),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 94, width: double.infinity,
                          child: promocion.urlImagen == null
                              ? const _SinImagen()
                              : Image.network(promocion.urlImagen!, fit: BoxFit.cover,
                                  cacheWidth: 480, errorBuilder: (_, _, _) => const _SinImagen()),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(promocion.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF0A2A66), fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(establecimiento.nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF6F819F), fontSize: 12)),
                              if (establecimiento.distanciaFormateada.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('a ${establecimiento.distanciaFormateada}',
                                  style: const TextStyle(color: Color(0xFF6F819F), fontSize: 12)),
                              ],
                            ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SinImagen extends StatelessWidget {
  const _SinImagen();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEAF2FF),
    child: Icon(Icons.local_offer_outlined, color: Color(0xFF1769FF), size: 32),
  );
}
