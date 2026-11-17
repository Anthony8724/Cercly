import 'package:latlong2/latlong.dart';

/// Ruta calculada entre dos puntos, lista para dibujarse sobre el mapa.
class RutaModel {
  const RutaModel({
    required this.puntos,
    required this.distanciaMetros,
    required this.duracionSegundos,
  });

  /// Puntos del recorrido, en orden, del origen al destino.
  final List<LatLng> puntos;

  final double distanciaMetros;

  /// Duración estimada sin tráfico en vivo.
  final double duracionSegundos;

  /// Ejemplos: `850 m`, `2,4 km`.
  String get distanciaTexto {
    if (distanciaMetros < 1000) return '${distanciaMetros.round()} m';
    final km = distanciaMetros / 1000;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Ejemplos: `menos de 1 min`, `12 min`, `1 h 5 min`.
  String get duracionTexto {
    final minutos = (duracionSegundos / 60).round();
    if (minutos < 1) return 'menos de 1 min';
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '$horas h' : '$horas h $resto min';
  }
}
