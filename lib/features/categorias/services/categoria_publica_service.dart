import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/categoria_model.dart';
import '../models/subcategoria_model.dart';

class CategoriaPublicaService {
  CategoriaPublicaService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<CategoriaModel>> listarCategorias() async {
    final respuesta = await _supabase
        .from('categorias')
        .select('id, nombre, slug, icono, activa, orden')
        .eq('activa', true)
        .order('orden');

    return List<Map<String, dynamic>>.from(respuesta)
        .map(CategoriaModel.fromSupabase)
        .toList(growable: false);
  }

  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async {
    final respuesta = await _supabase
        .from('subcategorias')
        .select('id, categoria_id, nombre, slug, icono, activa, orden')
        .eq('categoria_id', categoriaId)
        .eq('activa', true)
        .order('orden');

    return List<Map<String, dynamic>>.from(respuesta)
        .map(SubcategoriaModel.fromSupabase)
        .toList(growable: false);
  }
}
