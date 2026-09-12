import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_model.dart';

class EstablecimientoService {
  EstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listarCategoriasActivas() async {
    final respuesta = await _supabase
        .from('categorias')
        .select('id, nombre, slug, icono, orden')
        .eq('activa', true)
        .order('orden');

    return List<Map<String, dynamic>>.from(respuesta);
  }

  Future<List<EstablecimientoModel>> listarEstablecimientosDelUsuario() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final respuesta = await _supabase
        .from('establecimientos')
        .select()
        .eq('propietario_id', usuario.id)
        .order('creado_en', ascending: false);

    return respuesta.map(EstablecimientoModel.fromSupabase).toList();
  }

  Future<String> crear(EstablecimientoModel establecimiento) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError(
        'Debes iniciar sesión para registrar un establecimiento.',
      );
    }

    if (usuario.id != establecimiento.propietarioId) {
      throw StateError(
        'No puedes registrar un establecimiento para otro usuario.',
      );
    }

    final respuesta = await _supabase
        .from('establecimientos')
        .insert(establecimiento.toSupabaseParaCrear())
        .select('id')
        .single();

    final establecimientoId = respuesta['id'] as String;
    final horarios = establecimiento.horariosParaSupabase(establecimientoId);

    try {
      if (horarios.isNotEmpty) {
        await _supabase.from('horarios_establecimiento').insert(horarios);
      }

      return establecimientoId;
    } catch (_) {
      await _supabase
          .from('establecimientos')
          .delete()
          .eq('id', establecimientoId);

      rethrow;
    }
  }

  Future<EstablecimientoModel?> obtenerPorId(String id) async {
    final respuesta = await _supabase
        .from('establecimientos')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (respuesta == null) {
      return null;
    }

    return EstablecimientoModel.fromSupabase(respuesta);
  }

  Stream<Map<String, dynamic>?> observarPorId(String id) {
    return _supabase
        .from('establecimientos')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((filas) => filas.isEmpty ? null : filas.first);
  }
}
