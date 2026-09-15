import 'package:flutter/material.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';

class TarjetaEstablecimientoPublico extends StatelessWidget {
  const TarjetaEstablecimientoPublico({
    required this.establecimiento,
    required this.onTap,
    super.key,
  });

  final EstablecimientoPublicoModel establecimiento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x221769FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4EDFA)),
      ),
      key: Key('establecimiento-${establecimiento.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 86, height: 112, child: _Portada(establecimiento)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            establecimiento.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF1769FF)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      establecimiento.categoria.nombre,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      establecimiento.direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (establecimiento.estadoHorario != null)
                          _EstadoHorarioEtiqueta(
                            estado: establecimiento.estadoHorario!,
                          ),
                        if (establecimiento.distanciaFormateada.isNotEmpty)
                          _Etiqueta(
                            icono: Icons.near_me,
                            texto: establecimiento.distanciaFormateada,
                          ),
                        if (establecimiento.tienePromociones)
                          const _Etiqueta(
                            key: Key('indicador-promocion'),
                            icono: Icons.local_offer,
                            texto: 'Promoción',
                            promocion: true,
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
    );
  }
}

class _Portada extends StatelessWidget {
  const _Portada(this.establecimiento);

  final EstablecimientoPublicoModel establecimiento;

  @override
  Widget build(BuildContext context) {
    final url = establecimiento.urlFotoPortada;
    if (url == null || url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFDBEAFE),
        child: Center(
          child: Icon(Icons.storefront, size: 42, color: Color(0xFF2563EB)),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 336,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFDBEAFE),
        child: Center(child: Icon(Icons.storefront, size: 42)),
      ),
    );
  }
}

class _EstadoHorarioEtiqueta extends StatelessWidget {
  const _EstadoHorarioEtiqueta({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final abierto = estado == 'abierto';
    final cerrado = estado == 'cerrado';

    final texto = abierto
        ? 'Abierto'
        : cerrado
        ? 'Cerrado'
        : 'Horario no disponible';

    final icono = abierto
        ? Icons.check_circle
        : cerrado
        ? Icons.cancel
        : Icons.schedule;

    final color = abierto
        ? const Color(0xFF15803D)
        : cerrado
        ? const Color(0xFFB91C1C)
        : const Color(0xFF64748B);

    final fondo = abierto
        ? const Color(0xFFF0FDF4)
        : cerrado
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF8FAFC);

    return Container(
      key: Key('estado-horario-$estado'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icono,
    required this.texto,
    this.promocion = false,
    super.key,
  });

  final IconData icono;
  final String texto;
  final bool promocion;

  @override
  Widget build(BuildContext context) {
    final color = promocion ? const Color(0xFFEA580C) : const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: promocion ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
