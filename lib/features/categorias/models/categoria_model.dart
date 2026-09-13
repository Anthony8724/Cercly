class CategoriaModel {
  CategoriaModel({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.icono,
    required this.activa,
    required this.orden,
    this.creadoEn,
    this.actualizadoEn,
  }) {
    if (nombre.trim().isEmpty) {
      throw ArgumentError('El nombre de la categoría es obligatorio.');
    }

    if (slug.trim().isEmpty) {
      throw ArgumentError('El slug de la categoría es obligatorio.');
    }

    if (icono.trim().isEmpty) {
      throw ArgumentError('El icono de la categoría es obligatorio.');
    }

    if (orden < 0) {
      throw ArgumentError('El orden no puede ser negativo.');
    }
  }

  final String id;
  final String nombre;
  final String slug;
  final String icono;
  final bool activa;
  final int orden;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  Map<String, dynamic> toSupabase() {
    return {
      'nombre': nombre.trim(),
      'slug': slug.trim(),
      'icono': icono.trim(),
      'activa': activa,
      'orden': orden,
    };
  }

  factory CategoriaModel.fromSupabase(Map<String, dynamic> datos) {
    return CategoriaModel(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String,
      slug: datos['slug'] as String,
      icono: datos['icono'] as String,
      activa: datos['activa'] as bool? ?? true,
      orden: datos['orden'] as int? ?? 0,
      creadoEn: datos['creado_en'] == null
          ? null
          : DateTime.parse(datos['creado_en'] as String).toLocal(),
      actualizadoEn: datos['actualizado_en'] == null
          ? null
          : DateTime.parse(datos['actualizado_en'] as String).toLocal(),
    );
  }
}
