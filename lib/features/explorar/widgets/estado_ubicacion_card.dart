import 'package:flutter/material.dart';

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
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(child: Text('Ubicación actual lista')),
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
      color: const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_off, color: Color(0xFFD97706)),
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
