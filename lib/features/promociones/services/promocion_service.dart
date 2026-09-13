import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promocion_model.dart';

class PromocionService {
  PromocionService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static const String bucket = 'promociones-imagenes';
  static const int maximoBytes = 5 * 1024 * 1024;

  final SupabaseClient _supabase;

  Future<bool> _puedeGestionar(String establecimientoId) async {
    final respuesta = await _supabase.rpc(
      'puede_gestionar_establecimiento',
      params: {'p_establecimiento_id': establecimientoId},
    );

    return respuesta == true;
  }

  Future<void> _verificarPermiso(String establecimientoId) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final tienePermiso = await _puedeGestionar(establecimientoId);

    if (!tienePermiso) {
      throw StateError(
        'No tienes permiso para administrar promociones '
        'de este establecimiento.',
      );
    }
  }

  Future<List<PromocionModel>> listarPorEstablecimiento(
    String establecimientoId,
  ) async {
    final respuesta = await _supabase
        .from('promociones')
        .select()
        .eq('establecimiento_id', establecimientoId)
        .order('fecha_inicio', ascending: false);

    return respuesta.map<PromocionModel>(PromocionModel.fromSupabase).toList();
  }

  Future<String?> obtenerUrlImagen(PromocionModel promocion) async {
    final ruta = promocion.imagenRutaStorage;

    if (ruta == null || ruta.isEmpty) {
      return null;
    }

    return _supabase.storage.from(bucket).createSignedUrl(ruta, 3600);
  }

  Future<String> crear({
    required PromocionModel promocion,
    XFile? imagen,
  }) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    await _verificarPermiso(promocion.establecimientoId);

    final datos = promocion.toSupabaseParaCrear()
      ..remove('imagen_ruta_storage');

    final respuesta = await _supabase
        .from('promociones')
        .insert(datos)
        .select('id')
        .single();

    final promocionId = respuesta['id'] as String;

    if (imagen == null) {
      return promocionId;
    }

    String? rutaSubida;

    try {
      rutaSubida = await _subirImagen(
        usuarioId: usuario.id,
        establecimientoId: promocion.establecimientoId,
        promocionId: promocionId,
        imagen: imagen,
      );

      await _supabase
          .from('promociones')
          .update({'imagen_ruta_storage': rutaSubida})
          .eq('id', promocionId);

      return promocionId;
    } catch (_) {
      if (rutaSubida != null) {
        await _supabase.storage.from(bucket).remove([rutaSubida]);
      }

      await _supabase.from('promociones').delete().eq('id', promocionId);

      rethrow;
    }
  }

  Future<void> cambiarEstado({
    required String promocionId,
    required String establecimientoId,
    required bool activa,
  }) async {
    await _verificarPermiso(establecimientoId);

    await _supabase
        .from('promociones')
        .update({'activa': activa})
        .eq('id', promocionId)
        .eq('establecimiento_id', establecimientoId);
  }

  Future<void> eliminar(PromocionModel promocion) async {
    await _verificarPermiso(promocion.establecimientoId);

    await _supabase
        .from('promociones')
        .delete()
        .eq('id', promocion.id)
        .eq('establecimiento_id', promocion.establecimientoId);

    final ruta = promocion.imagenRutaStorage;

    if (ruta != null && ruta.isNotEmpty) {
      await _supabase.storage.from(bucket).remove([ruta]);
    }
  }

  Future<String> _subirImagen({
    required String usuarioId,
    required String establecimientoId,
    required String promocionId,
    required XFile imagen,
  }) async {
    final bytes = await imagen.readAsBytes();

    if (bytes.length > maximoBytes) {
      throw StateError('La imagen supera el límite permitido de 5 MB.');
    }

    final extension = _obtenerExtension(imagen.name);
    final contentType = _obtenerContentType(extension);

    final ruta =
        '$usuarioId/$establecimientoId/'
        '$promocionId.$extension';

    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return ruta;
  }

  String _obtenerExtension(String nombre) {
    final partes = nombre.toLowerCase().split('.');
    final extension = partes.length > 1 ? partes.last : 'jpg';

    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw StateError('Solo se permiten imágenes JPG, PNG o WebP.');
    }

    return extension;
  }

  String _obtenerContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
