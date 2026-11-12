import 'package:flutter/material.dart';

import '../../../shared/ui/cercly_ui.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../../establecimientos/services/establecimiento_publico_service.dart';
import '../../explorar/screens/detalle_establecimiento_screen.dart';
import '../models/promocion_destacada_model.dart';
import '../services/promocion_publica_service.dart';

/// Pestaña pública, independiente de la ubicación y las notificaciones.
class PromocionesScreen extends StatefulWidget {
  const PromocionesScreen({
    this.cargarPromociones,
    this.ciudad = 'Tulcán',
    this.provincia = 'Carchi',
    this.resolverEstablecimiento,
    this.crearDetalle,
    super.key,
  });

  final Future<List<PromocionDestacadaModel>> Function()? cargarPromociones;
  final String ciudad;
  final String provincia;
  final Future<EstablecimientoPublicoModel?> Function(String id)?
  resolverEstablecimiento;
  final Widget Function(
    BuildContext context,
    EstablecimientoPublicoModel establecimiento,
  )?
  crearDetalle;

  @override
  State<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends State<PromocionesScreen> {
  List<PromocionDestacadaModel> _promociones = const [];
  bool _cargando = true;
  bool _error = false;
  String _busqueda = '';
  String? _abriendoEstablecimiento;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PromocionesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ciudad != widget.ciudad ||
        oldWidget.provincia != widget.provincia ||
        oldWidget.cargarPromociones != widget.cargarPromociones) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    if (mounted) {
      setState(() {
        _cargando = true;
        _error = false;
      });
    }
    try {
      final promociones =
          await (widget.cargarPromociones?.call() ??
              PromocionPublicaService().listarVigentes(
                ciudad: widget.ciudad,
                provincia: widget.provincia,
              ));
      if (!mounted) return;
      setState(() {
        _promociones = promociones;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  Future<void> _abrirNegocio(String establecimientoId) async {
    if (_abriendoEstablecimiento != null) return;
    setState(() => _abriendoEstablecimiento = establecimientoId);
    try {
      // Comprobamos de nuevo que la ficha siga siendo pública.
      final establecimiento =
          await (widget.resolverEstablecimiento?.call(establecimientoId) ??
              EstablecimientoPublicoService().obtenerPorId(establecimientoId));
      if (!mounted) return;
      if (establecimiento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este negocio ya no está disponible.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) =>
              widget.crearDetalle?.call(routeContext, establecimiento) ??
              DetalleEstablecimientoScreen(establecimiento: establecimiento),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el negocio. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _abriendoEstablecimiento = null);
    }
  }

  List<PromocionDestacadaModel> get _resultados {
    final ahora = DateTime.now();
    final texto = _busqueda.trim().toLowerCase();
    return _promociones
        .where((p) {
          if (!p.activa || !p.estaVigenteEn(ahora)) return false;
          if (texto.isEmpty) return true;
          return p.titulo.toLowerCase().contains(texto) ||
              p.descripcion.toLowerCase().contains(texto) ||
              p.establecimientoNombre.toLowerCase().contains(texto) ||
              p.categoriaNombre.toLowerCase().contains(texto);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final resultados = _resultados;

    return SkySurface(
      child: Column(
        children: [
          CerclyPageHeader(
            title: 'Promociones',
            subtitle:
                'Ofertas vigentes en ${widget.ciudad}, ${widget.provincia}',
            icon: Icons.local_offer_rounded,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_city_rounded, color: sky.interactive),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mostrando promociones de ${widget.ciudad}, ${widget.provincia}',
                          key: const Key('ciudad-promociones'),
                          style: TextStyle(
                            color: sky.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('buscar-promociones'),
                    onChanged: (valor) => setState(() => _busqueda = valor),
                    decoration: const InputDecoration(
                      hintText: 'Buscar promociones o negocios',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error)
                    CerclySectionCard(
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'No pudimos cargar las promociones.',
                            style: TextStyle(color: sky.text),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _cargar,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  else if (resultados.isEmpty)
                    CerclySectionCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 44,
                            color: sky.muted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _busqueda.trim().isEmpty
                                ? 'Aún no hay promociones vigentes.'
                                : 'No encontramos promociones con esa búsqueda.',
                            style: TextStyle(color: sky.text),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      '${resultados.length} promociones disponibles',
                      style: TextStyle(
                        color: sky.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final promocion in resultados) ...[
                      _TarjetaPromocionPublica(
                        promocion: promocion,
                        abriendo:
                            _abriendoEstablecimiento ==
                            promocion.establecimientoId,
                        habilitada: _abriendoEstablecimiento == null,
                        onAbrir: () =>
                            _abrirNegocio(promocion.establecimientoId),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPromocionPublica extends StatelessWidget {
  const _TarjetaPromocionPublica({
    required this.promocion,
    required this.abriendo,
    required this.habilitada,
    required this.onAbrir,
  });

  final PromocionDestacadaModel promocion;
  final bool abriendo;
  final bool habilitada;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final imagen = promocion.urlImagen;
    final vence = promocion.fechaFin;
    final vigencia =
        '${vence.day.toString().padLeft(2, '0')}/'
        '${vence.month.toString().padLeft(2, '0')}/${vence.year}';

    return CerclySectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 98,
                height: 102,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: sky.soft,
                ),
                child: imagen == null || imagen.isEmpty
                    ? Icon(
                        Icons.local_offer_rounded,
                        color: sky.interactive,
                        size: 38,
                      )
                    : Image.network(
                        imagen,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.local_offer_rounded,
                          color: sky.interactive,
                          size: 38,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promocion.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sky.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      promocion.establecimientoNombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sky.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promocion.categoriaNombre,
                      style: TextStyle(color: sky.interactive, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (promocion.descripcion.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              promocion.descripcion,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: sky.text),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Válida hasta $vigencia',
                  style: TextStyle(color: sky.muted, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: habilitada ? onAbrir : null,
                icon: abriendo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('Ver negocio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
