class PromocionModel {
  PromocionModel({
    required this.id,
    required this.establecimientoId,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.radioAlertaMetros,
    required this.activa,
    this.imagenRutaStorage,
    this.creadoEn,
    this.actualizadoEn,
  }) {
    if (establecimientoId.trim().isEmpty) {
      throw ArgumentError('El establecimiento es obligatorio.');
    }

    if (titulo.trim().length < 2 || titulo.trim().length > 120) {
      throw ArgumentError('El título debe tener entre 2 y 120 caracteres.');
    }

    if (!fechaFin.isAfter(fechaInicio)) {
      throw ArgumentError(
        'La fecha final debe ser posterior a la fecha inicial.',
      );
    }

    if (radioAlertaMetros < 10 || radioAlertaMetros > 5000) {
      throw ArgumentError(
        'El radio de alerta debe estar entre 10 y 5000 metros.',
      );
    }
  }

  final String id;
  final String establecimientoId;
  final String titulo;
  final String descripcion;
  final String? imagenRutaStorage;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int radioAlertaMetros;
  final bool activa;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get estaVigente {
    final ahora = DateTime.now();

    return activa && !ahora.isBefore(fechaInicio) && !ahora.isAfter(fechaFin);
  }

  Map<String, dynamic> toSupabaseParaCrear() {
    return {
      'establecimiento_id': establecimientoId,
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'imagen_ruta_storage': imagenRutaStorage,
      'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
      'fecha_fin': fechaFin.toUtc().toIso8601String(),
      'radio_alerta_metros': radioAlertaMetros,
      'activa': activa,
    };
  }

  factory PromocionModel.fromSupabase(Map<String, dynamic> datos) {
    return PromocionModel(
      id: datos['id'] as String,
      establecimientoId: datos['establecimiento_id'] as String,
      titulo: datos['titulo'] as String,
      descripcion: datos['descripcion'] as String? ?? '',
      imagenRutaStorage: datos['imagen_ruta_storage'] as String?,
      fechaInicio: DateTime.parse(datos['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(datos['fecha_fin'] as String).toLocal(),
      radioAlertaMetros: datos['radio_alerta_metros'] as int? ?? 100,
      activa: datos['activa'] as bool? ?? true,
      creadoEn: datos['creado_en'] == null
          ? null
          : DateTime.parse(datos['creado_en'] as String).toLocal(),
      actualizadoEn: datos['actualizado_en'] == null
          ? null
          : DateTime.parse(datos['actualizado_en'] as String).toLocal(),
    );
  }
}
