class PromocionDestacadaModel {
  const PromocionDestacadaModel({
    required this.id,
    required this.establecimientoId,
    required this.establecimientoNombre,
    required this.categoriaNombre,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.radioAlertaMetros,
    required this.latitud,
    required this.longitud,
    this.imagenRutaStorage,
    this.urlImagen,
    this.distanciaMetros,
  });

  final String id;
  final String establecimientoId;
  final String establecimientoNombre;
  final String categoriaNombre;
  final String titulo;
  final String descripcion;
  final String? imagenRutaStorage;
  final String? urlImagen;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int radioAlertaMetros;
  final double latitud;
  final double longitud;
  final double? distanciaMetros;

  bool get estaVigente {
    final ahora = DateTime.now();

    return !ahora.isBefore(fechaInicio) && !ahora.isAfter(fechaFin);
  }

  String get distanciaFormateada {
    final distancia = distanciaMetros;

    if (distancia == null) {
      return '';
    }

    if (distancia < 1000) {
      return '${distancia.round()} m';
    }

    return '${(distancia / 1000).toStringAsFixed(1)} km';
  }

  PromocionDestacadaModel copiarCon({
    String? urlImagen,
    double? distanciaMetros,
  }) {
    return PromocionDestacadaModel(
      id: id,
      establecimientoId: establecimientoId,
      establecimientoNombre: establecimientoNombre,
      categoriaNombre: categoriaNombre,
      titulo: titulo,
      descripcion: descripcion,
      imagenRutaStorage: imagenRutaStorage,
      urlImagen: urlImagen ?? this.urlImagen,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      radioAlertaMetros: radioAlertaMetros,
      latitud: latitud,
      longitud: longitud,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
    );
  }

  factory PromocionDestacadaModel.fromSupabase(Map<String, dynamic> datos) {
    final establecimiento = Map<String, dynamic>.from(
      datos['establecimientos'] as Map,
    );

    final categoria = Map<String, dynamic>.from(
      establecimiento['categorias'] as Map,
    );

    return PromocionDestacadaModel(
      id: datos['id'] as String,
      establecimientoId: establecimiento['id'] as String,
      establecimientoNombre: establecimiento['nombre'] as String,
      categoriaNombre: categoria['nombre'] as String,
      titulo: datos['titulo'] as String,
      descripcion: datos['descripcion'] as String? ?? '',
      imagenRutaStorage: datos['imagen_ruta_storage'] as String?,
      fechaInicio: DateTime.parse(datos['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(datos['fecha_fin'] as String).toLocal(),
      radioAlertaMetros: datos['radio_alerta_metros'] as int? ?? 100,
      latitud: (establecimiento['latitud'] as num).toDouble(),
      longitud: (establecimiento['longitud'] as num).toDouble(),
    );
  }
}
