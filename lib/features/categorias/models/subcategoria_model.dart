class SubcategoriaModel {
  const SubcategoriaModel({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.slug,
    required this.icono,
    required this.activa,
    required this.orden,
  });

  final String id;
  final String categoriaId;
  final String nombre;
  final String slug;
  final String icono;
  final bool activa;
  final int orden;

  factory SubcategoriaModel.fromSupabase(Map<String, dynamic> datos) {
    return SubcategoriaModel(
      id: datos['id'] as String,
      categoriaId: datos['categoria_id'] as String,
      nombre: datos['nombre'] as String,
      slug: datos['slug'] as String,
      icono: datos['icono'] as String? ?? 'category',
      activa: datos['activa'] as bool? ?? true,
      orden: datos['orden'] as int? ?? 0,
    );
  }
}
