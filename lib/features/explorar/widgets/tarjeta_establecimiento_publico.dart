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
    final detalle = establecimiento.descripcion.trim().isNotEmpty
        ? establecimiento.descripcion.trim()
        : establecimiento.direccion.trim();

    return Card(
      key: Key('establecimiento-${establecimiento.id}'),
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x241769FF),
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4ECF7)),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 98,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(7),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 88,
                    child: _Portada(establecimiento),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 9, 5, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              establecimiento.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF102A56),
                                fontSize: 14.5,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF1769FF),
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              establecimiento.categoria.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF55729D),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (detalle.isNotEmpty) ...[
                            const Text(
                              '  •  ',
                              style: TextStyle(
                                color: Color(0xFF9AA8BB),
                                fontSize: 10,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                detalle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6F819A),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (establecimiento.estadoHorario != null)
                            Flexible(
                              child: _EstadoHorarioLinea(
                                estado: establecimiento.estadoHorario!,
                              ),
                            ),
                          if (establecimiento.estadoHorario != null &&
                              establecimiento.distanciaFormateada.isNotEmpty)
                            const SizedBox(width: 10),
                          if (establecimiento.distanciaFormateada.isNotEmpty)
                            _DatoLinea(
                              icono: Icons.location_on_rounded,
                              texto: establecimiento.distanciaFormateada,
                              color: const Color(0xFF54749F),
                            ),
                        ],
                      ),
                      if (establecimiento.tienePromociones) ...[
                        const SizedBox(height: 3),
                        const _DatoLinea(
                          key: Key('indicador-promocion'),
                          icono: Icons.local_offer_rounded,
                          texto: 'Promoción activa',
                          color: Color(0xFFE85D22),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 7),
            ],
          ),
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
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDDEBFF), Color(0xFFCFE2FF)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 38,
            color: Color(0xFF1769FF),
          ),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 360,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFDBEAFE),
        child: Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 38,
            color: Color(0xFF1769FF),
          ),
        ),
      ),
    );
  }
}

class _EstadoHorarioLinea extends StatelessWidget {
  const _EstadoHorarioLinea({required this.estado});

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

    final color = abierto
        ? const Color(0xFF138A4B)
        : cerrado
            ? const Color(0xFFC84646)
            : const Color(0xFF73839A);

    return _DatoLinea(
      key: Key('estado-horario-$estado'),
      icono: Icons.schedule_rounded,
      texto: texto,
      color: color,
    );
  }
}

class _DatoLinea extends StatelessWidget {
  const _DatoLinea({
    required this.icono,
    required this.texto,
    required this.color,
    super.key,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
