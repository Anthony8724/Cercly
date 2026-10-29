import 'dart:math' as math;

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../models/preferencias_usuario.dart';

class RecomendadorEstablecimientos {
  const RecomendadorEstablecimientos();

  List<EstablecimientoPublicoModel> recomendar({
    required Iterable<EstablecimientoPublicoModel> establecimientos,
    required PreferenciasUsuario preferencias,
    double? latitud,
    double? longitud,
    int limite = 8,
  }) {
    if (preferencias.categoriasIds.isEmpty &&
        !preferencias.priorizarPromociones) {
      return const [];
    }
    final radio = preferencias.radioMetros;
    final scored = <({EstablecimientoPublicoModel item, double score})>[];
    final vistos = <String>{};
    for (final item in establecimientos) {
      if (!vistos.add(item.id)) continue;
      final distancia =
          item.distanciaMetros ??
          (latitud == null || longitud == null
              ? null
              : _distanciaMetros(
                  latitud,
                  longitud,
                  item.latitud,
                  item.longitud,
                ));
      if (latitud != null &&
          longitud != null &&
          radio != null &&
          (distancia == null || distancia > radio)) {
        continue;
      }
      final coincideCategoria = preferencias.categoriasIds.contains(
        item.categoriaId,
      );
      final promocion =
          preferencias.priorizarPromociones &&
          item.promociones.any((p) => p.estaVigente);
      if (!coincideCategoria && !promocion) continue;
      var score = coincideCategoria ? 60.0 : 0.0;
      if (latitud != null &&
          longitud != null &&
          distancia != null &&
          distancia.isFinite) {
        final referencia = (radio ?? 20000).toDouble();
        score += (30 * (1 - (distancia / referencia).clamp(0, 1))).toDouble();
      }
      if (promocion) score += 10;
      scored.add((item: item, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.item.nombre.toLowerCase().compareTo(b.item.nombre.toLowerCase());
    });
    return scored
        .take(limite)
        .map((entry) => entry.item)
        .toList(growable: false);
  }

  double _distanciaMetros(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a =
        sinLat * sinLat +
        math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * sinLon * sinLon;
    return earthRadius * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
