import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FotoEstablecimiento {
  const FotoEstablecimiento({
    required this.id,
    required this.establecimientoId,
    required this.rutaStorage,
    required this.esPortada,
    required this.orden,
    required this.urlTemporal,
  });

  final String id;
  final String establecimientoId;
  final String rutaStorage;
  final bool esPortada;
  final int orden;
  final String urlTemporal;
}

class FotoEstablecimientoService {
  FotoEstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static const String bucket = 'establecimientos-imagenes';
  static const int maximoFotos = 5;
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
        'No tienes permiso para modificar este establecimiento.',
      );
    }
  }

  Future<List<FotoEstablecimiento>> listar(String establecimientoId) async {
    final respuesta = await _supabase
        .from('fotos_establecimiento')
        .select()
        .eq('establecimiento_id', establecimientoId)
        .order('orden');

    final fotos = <FotoEstablecimiento>[];

    for (final fila in respuesta) {
      final ruta = fila['ruta_storage'] as String;

      final url = await _supabase.storage
          .from(bucket)
          .createSignedUrl(ruta, 3600);

      fotos.add(
        FotoEstablecimiento(
          id: fila['id'] as String,
          establecimientoId: fila['establecimiento_id'] as String,
          rutaStorage: ruta,
          esPortada: fila['es_portada'] as bool? ?? false,
          orden: fila['orden'] as int? ?? 0,
          urlTemporal: url,
        ),
      );
    }

    return fotos;
  }

  Future<void> subir({
    required String establecimientoId,
    required List<XFile> archivos,
  }) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    await _verificarPermiso(establecimientoId);

    final existentes = await _supabase
        .from('fotos_establecimiento')
        .select('id')
        .eq('establecimiento_id', establecimientoId);

    if (existentes.length + archivos.length > maximoFotos) {
      throw StateError(
        'Cada establecimiento puede tener máximo 5 fotografías.',
      );
    }

    for (var indice = 0; indice < archivos.length; indice++) {
      final archivo = archivos[indice];
      final bytes = await archivo.readAsBytes();

      if (bytes.length > maximoBytes) {
        throw StateError('La imagen ${archivo.name} supera el límite de 5 MB.');
      }

      final extension = _obtenerExtension(archivo.name);
      final contentType = _obtenerContentType(extension);
      final nombre =
          '${DateTime.now().microsecondsSinceEpoch}_$indice.$extension';

      final ruta = '${usuario.id}/$establecimientoId/$nombre';

      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      try {
        await _supabase.from('fotos_establecimiento').insert({
          'establecimiento_id': establecimientoId,
          'ruta_storage': ruta,
          'es_portada': existentes.isEmpty && indice == 0,
          'orden': existentes.length + indice,
        });
      } catch (_) {
        await _supabase.storage.from(bucket).remove([ruta]);
        rethrow;
      }
    }
  }

  Future<void> establecerComoPortada({
    required String establecimientoId,
    required String fotoId,
  }) async {
    await _verificarPermiso(establecimientoId);

    await _supabase
        .from('fotos_establecimiento')
        .update({'es_portada': false})
        .eq('establecimiento_id', establecimientoId);

    await _supabase
        .from('fotos_establecimiento')
        .update({'es_portada': true})
        .eq('id', fotoId)
        .eq('establecimiento_id', establecimientoId);
  }

  Future<void> eliminar(FotoEstablecimiento foto) async {
    await _verificarPermiso(foto.establecimientoId);

    await _supabase.from('fotos_establecimiento').delete().eq('id', foto.id);

    await _supabase.storage.from(bucket).remove([foto.rutaStorage]);

    if (foto.esPortada) {
      final restantes = await _supabase
          .from('fotos_establecimiento')
          .select('id')
          .eq('establecimiento_id', foto.establecimientoId)
          .order('orden')
          .limit(1);

      if (restantes.isNotEmpty) {
        await establecerComoPortada(
          establecimientoId: foto.establecimientoId,
          fotoId: restantes.first['id'] as String,
        );
      }
    }
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
