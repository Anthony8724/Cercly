import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';

import '../../../sky/sky_theme.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../../establecimientos/models/establecimiento_model.dart';
import '../models/promocion_model.dart';
import '../services/promocion_service.dart';
import 'registro_promocion_screen.dart';

class PromocionesEstablecimientoScreen extends StatefulWidget {
  const PromocionesEstablecimientoScreen({
    required this.establecimiento,
    super.key,
  });

  final EstablecimientoModel establecimiento;

  @override
  State<PromocionesEstablecimientoScreen> createState() =>
      _PromocionesEstablecimientoScreenState();
}

class _PromocionesEstablecimientoScreenState
    extends State<PromocionesEstablecimientoScreen> {
  final _service = PromocionService();

  late Future<List<_PromocionVista>> _promocionesFuture;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _promocionesFuture = _cargarPromociones();
  }

  Future<List<_PromocionVista>> _cargarPromociones() async {
    final promociones = await _service.listarPorEstablecimiento(
      widget.establecimiento.id,
    );

    return Future.wait(
      promociones.map((promocion) async {
        final url = await _service.obtenerUrlImagen(promocion);

        return _PromocionVista(promocion: promocion, urlImagen: url);
      }),
    );
  }

  Future<void> _recargar() async {
    setState(_cargar);
    await _promocionesFuture;
  }

  Future<void> _abrirRegistro() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            RegistroPromocionScreen(establecimiento: widget.establecimiento),
      ),
    );

    if (creada == true && mounted) {
      setState(_cargar);
    }
  }

  Future<void> _abrirEdicion(_PromocionVista vista) async {
    final actualizada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RegistroPromocionScreen(
          establecimiento: widget.establecimiento,
          promocion: vista.promocion,
          urlImagenActual: vista.urlImagen,
        ),
      ),
    );

    if (actualizada == true && mounted) {
      setState(_cargar);
    }
  }

  Future<void> _cambiarEstado(PromocionModel promocion, bool activa) async {
    if (_procesando) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _service.cambiarEstado(
        promocionId: promocion.id,
        establecimientoId: promocion.establecimientoId,
        activa: activa,
      );

      if (mounted) {
        _mostrarMensaje(
          activa ? 'Promoción activada.' : 'Promoción desactivada.',
        );
        setState(_cargar);
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje('No se pudo actualizar la promoción: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _eliminar(PromocionModel promocion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar promoción'),
          content: Text(
            '¿Deseas eliminar la promoción '
            '"${promocion.titulo}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      await _service.eliminar(promocion);

      if (mounted) {
        _mostrarMensaje('Promoción eliminada.');
        setState(_cargar);
      }
    } catch (error) {
      if (mounted) {
        _mostrarMensaje('No se pudo eliminar la promoción: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkyPalette.of(context).background,
      body: SkySurface(
        child: Column(
          children: [
            CerclyPageHeader(
              title: 'Promociones',
              subtitle: widget.establecimiento.nombre,
              icon: Icons.local_offer_rounded,
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                CerclyHeaderAction(
                  icon: Icons.add_rounded,
                  tooltip: 'Nueva promoción',
                  onPressed: _abrirRegistro,
                ),
              ],
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: _recargar,
                  child: FutureBuilder<List<_PromocionVista>>(
                    future: _promocionesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                          children: [
                            CerclySectionCard(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No se pudieron cargar las promociones.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: SkyPalette.of(context).text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(_cargar);
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      final promociones = snapshot.data ?? <_PromocionVista>[];

                      if (promociones.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                          children: [
                            CerclySectionCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: SkyPalette.of(context).soft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.local_offer_outlined,
                                        size: 36,
                                        color: SkyPalette.of(context).primary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Todavía no existen promociones',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: SkyPalette.of(context).text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      'Crea una promoción para destacar tu establecimiento y atraer clientes cercanos.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: SkyPalette.of(context).muted,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: _abrirRegistro,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: SkyPalette.of(context)
                                            .primary,
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text(
                                        'Crear primera promoción',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Stack(
                        children: [
                          ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                            children: [
                              const CerclySectionTitle(
                                title: 'Promociones del negocio',
                                subtitle: 'Activa, edita o elimina las promociones publicadas.',
                                icon: Icons.campaign_rounded,
                              ),
                              const SizedBox(height: 14),
                              for (final vista in promociones)
                                _TarjetaPromocion(
                                  vista: vista,
                                  procesando: _procesando,
                                  formatearFecha: _formatearFecha,
                                  onEditar: () => _abrirEdicion(vista),
                                  onEliminar: () => _eliminar(vista.promocion),
                                  onCambiarEstado: (valor) =>
                                      _cambiarEstado(vista.promocion, valor),
                                ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _procesando
                                      ? null
                                      : _abrirRegistro,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: SkyPalette.of(context)
                                        .primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text(
                                    'Nueva promoción',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_procesando)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x33031A3A),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPromocion extends StatelessWidget {
  const _TarjetaPromocion({
    required this.vista,
    required this.procesando,
    required this.formatearFecha,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiarEstado,
  });

  final _PromocionVista vista;
  final bool procesando;
  final String Function(DateTime) formatearFecha;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final ValueChanged<bool> onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final promocion = vista.promocion;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SkyPalette.of(context).surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SkyPalette.of(context).border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12031A3A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vista.urlImagen != null)
            Image.network(
              vista.urlImagen!,
              height: 190,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => SizedBox(
                height: 120,
                child: ColoredBox(
                  color: SkyPalette.of(context).soft,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: SkyPalette.of(context).primary,
                      size: 42,
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ColoredBox(
                color: SkyPalette.of(context).soft,
                child: Center(
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: SkyPalette.of(context).primary,
                    size: 42,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        promocion.titulo,
                        style: TextStyle(
                          color: SkyPalette.of(context).text,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: promocion.activa
                            ? const Color(0xFFEAF8EF)
                            : const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        promocion.activa ? 'Activa' : 'Inactiva',
                        style: TextStyle(
                          color: promocion.activa
                              ? const Color(0xFF218B4C)
                              : SkyPalette.of(context).muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (promocion.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    promocion.descripcion,
                    style: TextStyle(
                      color: SkyPalette.of(context).muted,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 17,
                      color: SkyPalette.of(context).primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${formatearFecha(promocion.fechaInicio)} - ${formatearFecha(promocion.fechaFin)}',
                        style: TextStyle(
                          color: SkyPalette.of(context).muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 17,
                      color: SkyPalette.of(context).primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Radio de alerta: ${promocion.radioAlertaMetros} m',
                      style: TextStyle(
                        color: SkyPalette.of(context).muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Publicación',
                          style: TextStyle(
                            color: SkyPalette.of(context).text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          promocion.activa
                              ? 'Visible para los usuarios'
                              : 'Oculta temporalmente',
                          style: TextStyle(
                            color: SkyPalette.of(context).muted,
                            fontSize: 12,
                          ),
                        ),
                        value: promocion.activa,
                        onChanged: procesando ? null : onCambiarEstado,
                      ),
                    ),
                    IconButton(
                      key: Key('editar-promocion-${promocion.id}'),
                      onPressed: procesando ? null : onEditar,
                      tooltip: 'Editar',
                      icon: Icon(
                        Icons.edit_rounded,
                        color: SkyPalette.of(context).primary,
                      ),
                    ),
                    IconButton(
                      onPressed: procesando ? null : onEliminar,
                      tooltip: 'Eliminar',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromocionVista {
  const _PromocionVista({required this.promocion, required this.urlImagen});

  final PromocionModel promocion;
  final String? urlImagen;
}
