import 'package:flutter/material.dart';
import '../../../sky/sky_theme.dart';

import '../controllers/explorar_controller.dart';
import '../models/ubicacion_usuario.dart';

class EstadoUbicacionCard extends StatelessWidget {
  const EstadoUbicacionCard({required this.controller, super.key});

  final ExplorarController controller;

  @override
  Widget build(BuildContext context) {
    final estado = controller.estadoUbicacion;
    if (estado == EstadoUbicacion.disponible) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SkyPalette.of(context).soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: SkyPalette.of(context).success),
            const SizedBox(width: 8),
            const Expanded(child: Text('Ubicación actual lista')),
          ],
        ),
      );
    }

    if (estado == EstadoUbicacion.cargando) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Obteniendo tu ubicación…'),
      );
    }

    if (estado == EstadoUbicacion.inicial) {
      return const SizedBox.shrink();
    }

    final abreAplicacion =
        estado == EstadoUbicacion.permisoDenegadoPermanentemente;
    final servicioDesactivado = estado == EstadoUbicacion.servicioDesactivado;

    return Card(
      color: SkyPalette.of(context).surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_off, color: SkyPalette.of(context).warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.mensajeUbicacion ??
                        'No se pudo usar tu ubicación.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: controller.solicitarUbicacion,
                        child: const Text('Reintentar'),
                      ),
                      if (abreAplicacion || servicioDesactivado)
                        TextButton(
                          onPressed: abreAplicacion
                              ? controller.abrirAjustesAplicacion
                              : controller.abrirAjustesUbicacion,
                          child: const Text('Abrir ajustes'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
