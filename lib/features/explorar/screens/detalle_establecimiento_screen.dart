import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../services/mapas_externos_service.dart';

class DetalleEstablecimientoScreen extends StatelessWidget {
  const DetalleEstablecimientoScreen({
    required this.establecimiento,
    this.mapasService,
    super.key,
  });

  final EstablecimientoPublicoModel establecimiento;
  final MapasExternosService? mapasService;

  Future<void> _comoLlegar(BuildContext context) async {
    final abierto = await (mapasService ?? MapasExternosService()).comoLlegar(
      latitud: establecimiento.latitud,
      longitud: establecimiento.longitud,
    );

    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No encontramos una aplicación de mapas disponible.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del establecimiento')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const Key('boton-como-llegar'),
          onPressed: () => _comoLlegar(context),
          icon: const Icon(Icons.directions),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Cómo llegar'),
          ),
        ),
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _ImagenDetalle(url: establecimiento.urlFotoPortada),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        establecimiento.nombre,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (establecimiento.distanciaFormateada.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.near_me, size: 17),
                        label: Text(establecimiento.distanciaFormateada),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  establecimiento.categoria.nombre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (establecimiento.descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    establecimiento.descripcion,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 20),
                _DatoDetalle(
                  icono: Icons.location_on_outlined,
                  titulo: 'Dirección',
                  valor: establecimiento.direccion,
                ),
                if (establecimiento.telefonoPublico.trim().isNotEmpty)
                  _DatoDetalle(
                    icono: Icons.phone_outlined,
                    titulo: 'Teléfono',
                    valor: establecimiento.telefonoPublico,
                  ),
                if ((establecimiento.ciudad ?? '').isNotEmpty ||
                    (establecimiento.provincia ?? '').isNotEmpty)
                  _DatoDetalle(
                    icono: Icons.map_outlined,
                    titulo: 'Ubicación',
                    valor: [
                      establecimiento.ciudad,
                      establecimiento.provincia,
                    ].whereType<String>().where((v) => v.isNotEmpty).join(', '),
                  ),
                if (establecimiento.promociones.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Promociones activas',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  for (final promocion in establecimiento.promociones)
                    _PromocionCard(promocion: promocion),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagenDetalle extends StatelessWidget {
  const _ImagenDetalle({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFDBEAFE),
        child: Center(
          child: Icon(Icons.storefront, size: 80, color: Color(0xFF2563EB)),
        ),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFDBEAFE),
        child: Center(child: Icon(Icons.storefront, size: 80)),
      ),
    );
  }
}

class _DatoDetalle extends StatelessWidget {
  const _DatoDetalle({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(valor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromocionCard extends StatelessWidget {
  const _PromocionCard({required this.promocion});

  final PromocionPublicaModel promocion;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (promocion.urlImagen != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  promocion.urlImagen!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              )
            else
              const CircleAvatar(
                backgroundColor: Color(0xFFFED7AA),
                child: Icon(Icons.local_offer, color: Color(0xFFEA580C)),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promocion.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (promocion.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(promocion.descripcion),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Vigente hasta ${_fecha(promocion.fechaFin)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}
