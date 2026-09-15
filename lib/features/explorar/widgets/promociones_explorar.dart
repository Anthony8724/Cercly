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
        padding: EdgeInsets.symmetric(vertical: 14),
        child: LinearProgressIndicator(key: Key('promociones-loading')),
      );
    }
    if (_error) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('promociones-reintentar'),
          onPressed: () => setState(_cargar),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('No pudimos cargar promociones. Reintentar'),
        ),
      );
    }

    final ahora = DateTime.now();
    final items = [
      for (final establecimiento in widget.establecimientos)
        for (final promocion in _promociones)
          if (promocion.establecimientoId == establecimiento.id &&
              promocion.activa &&
              promocion.estaVigenteEn(ahora))
            (establecimiento, promocion),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.star_rounded,
              color: Color(0xFF1769FF),
              size: 23,
            ),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                'Promociones cerca de ti',
                style: TextStyle(
                  color: Color(0xFF102A56),
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.25,
                ),
              ),
            ),
            TextButton(
              key: const Key('ver-todas-promociones'),
              onPressed: widget.onVerTodas,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1769FF),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todas',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final (establecimiento, promocion) = items[index];
              return _TarjetaPromocion(
                key: Key('promocion-${promocion.id}'),
                establecimiento: establecimiento,
                promocion: promocion,
                onTap: () => widget.onEstablecimiento(establecimiento),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaPromocion extends StatelessWidget {
  const _TarjetaPromocion({
    required this.establecimiento,
    required this.promocion,
    required this.onTap,
    super.key,
  });

  final EstablecimientoPublicoModel establecimiento;
  final PromocionDestacadaModel promocion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x241769FF),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 88,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ImagenPromocion(
                      promocion: promocion,
                      establecimiento: establecimiento,
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _colorEtiqueta(promocion.id.hashCode),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _etiqueta(promocion),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promocion.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF102A56),
                          fontSize: 12.5,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        establecimiento.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71819A),
                          fontSize: 10.5,
                          height: 1.05,
                        ),
                      ),
                      const Spacer(),
                      if (establecimiento.distanciaFormateada.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF5E7BA5),
                              size: 13,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'a ${establecimiento.distanciaFormateada}',
                              style: const TextStyle(
                                color: Color(0xFF5E6F89),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _etiqueta(PromocionDestacadaModel promocion) {
    final contenido = '${promocion.titulo} ${promocion.descripcion}';
    final porcentaje = RegExp(r'\b\d{1,2}\s*%').firstMatch(contenido)?.group(0);
    if (porcentaje != null) return porcentaje.replaceAll(' ', '');

    final dosPorUno = RegExp(r'\b2\s*[xX]\s*1\b').firstMatch(contenido)?.group(0);
    if (dosPorUno != null) return dosPorUno.replaceAll(' ', '').toLowerCase();

    return 'Promo';
  }

  static Color _colorEtiqueta(int semilla) {
    const colores = [
      Color(0xFFF04452),
      Color(0xFFCF2CC9),
      Color(0xFF1769FF),
    ];
    return colores[semilla.abs() % colores.length];
  }
}

class _ImagenPromocion extends StatelessWidget {
  const _ImagenPromocion({
    required this.promocion,
    required this.establecimiento,
  });

  final PromocionDestacadaModel promocion;
  final EstablecimientoPublicoModel establecimiento;

  @override
  Widget build(BuildContext context) {
    final urlPromocion = promocion.urlImagen;
    if (urlPromocion != null && urlPromocion.isNotEmpty) {
      return Image.network(
        urlPromocion,
        fit: BoxFit.cover,
        cacheWidth: 420,
        errorBuilder: (_, _, _) => _FallbackImagen(establecimiento: establecimiento),
      );
    }
    return _FallbackImagen(establecimiento: establecimiento);
  }
}

class _FallbackImagen extends StatelessWidget {
  const _FallbackImagen({required this.establecimiento});

  final EstablecimientoPublicoModel establecimiento;

  @override
  Widget build(BuildContext context) {
    final url = establecimiento.urlFotoPortada;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 420,
        errorBuilder: (_, _, _) => const _SinImagen(),
      );
    }
    return const _SinImagen();
  }
}

class _SinImagen extends StatelessWidget {
  const _SinImagen();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF2FF), Color(0xFFD8E8FF)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.local_offer_outlined,
            color: Color(0xFF1769FF),
            size: 32,
          ),
        ),
      );
}
