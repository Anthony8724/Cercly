import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../../establecimientos/services/establecimiento_publico_service.dart';
import '../../explorar/screens/detalle_establecimiento_screen.dart';
import '../../promociones/models/promocion_destacada_model.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../controllers/monitor_proximidad_controller.dart';

/// Radar foreground integrado sobre el mapa. La sesión se apaga al salir de
/// Mapa; la preferencia de alertas sigue siendo un consentimiento separado.
class RadarCerclyPanel extends StatefulWidget {
  const RadarCerclyPanel({required this.controller, super.key});

  final MonitorProximidadController controller;

  @override
  State<RadarCerclyPanel> createState() => _RadarCerclyPanelState();
}

class _RadarCerclyPanelState extends State<RadarCerclyPanel> {
  String? _abriendo;

  Future<void> _abrir(PromocionDestacadaModel promocion) async {
    if (_abriendo != null) return;
    setState(() => _abriendo = promocion.id);
    try {
      // La promoción y el establecimiento pueden haber cambiado desde el GPS.
      final vigente = await PromocionPublicaService().obtenerPorId(
        promocion.id,
      );
      if (!mounted) return;
      if (vigente == null ||
          !vigente.activa ||
          !vigente.estaVigenteEn(DateTime.now()) ||
          vigente.establecimientoId != promocion.establecimientoId) {
        _mostrarMensaje('La promoción ya no está disponible.');
        return;
      }
      final establecimiento = await EstablecimientoPublicoService()
          .obtenerPorId(promocion.establecimientoId);
      if (!mounted) return;
      if (establecimiento == null) {
        _mostrarMensaje('Este establecimiento ya no está disponible.');
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              DetalleEstablecimientoScreen(establecimiento: establecimiento),
        ),
      );
    } catch (_) {
      if (mounted) _mostrarMensaje('No pudimos abrir la promoción.');
    } finally {
      if (mounted) setState(() => _abriendo = null);
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final activo = widget.controller.radarActivo;
        final promociones = widget.controller.promocionesRadar;
        return Material(
          elevation: 5,
          color: sky.surface,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.radar_rounded, color: sky.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Radar Cercly Sky',
                        style: TextStyle(
                          color: sky.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      key: const Key('radar-cercly-toggle'),
                      value: activo,
                      onChanged: widget.controller.setRadarActivo,
                    ),
                  ],
                ),
                Text(
                  'Ubicación solo mientras Mapa está visible. '
                  'Las alertas dependen de tus preferencias.',
                  style: TextStyle(color: sky.muted, fontSize: 11),
                ),
                if (activo) ...[
                  if (widget.controller.cargandoRadar)
                    const LinearProgressIndicator(key: Key('radar-cargando')),
                  if (promociones.isEmpty && !widget.controller.cargandoRadar)
                    Text(switch (widget.controller.ultimoResultadoDiagnostico) {
                      'permiso_ubicacion_pendiente' ||
                      'permiso_ubicacion_revocado' =>
                        'Autoriza la ubicación para usar el Radar.',
                      'ubicacion_servicio_desactivado' =>
                        'Activa la ubicación del teléfono.',
                      'ubicacion_imprecisa_o_desactualizada' =>
                        'Esperando una ubicación actual y precisa.',
                      'error_evaluacion' || 'error_ubicacion' =>
                        'No pudimos actualizar el Radar. Inténtalo de nuevo.',
                      _ => 'Sin promociones cercanas vigentes.',
                    }, style: TextStyle(color: sky.muted)),
                  if (promociones.isNotEmpty)
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        key: const Key('radar-promociones'),
                        scrollDirection: Axis.horizontal,
                        itemCount: promociones.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final promo = promociones[index];
                          return SizedBox(
                            width: 190,
                            child: OutlinedButton(
                              key: Key('radar-promocion-${promo.id}'),
                              onPressed: _abriendo == null
                                  ? () => _abrir(promo)
                                  : null,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    promo.establecimientoNombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    promo.titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(promo.distanciaFormateada),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
