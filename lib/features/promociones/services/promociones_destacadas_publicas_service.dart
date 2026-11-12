import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promocion_destacada_model.dart';

/// Solo consulta campanas aprobadas por administracion para Explorar.
/// El catalogo gratuito usa PromocionPublicaService por separado.
class PromocionesDestacadasPublicasService {
  PromocionesDestacadasPublicasService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _columnas = '''
    promocion_id,
    promociones!inner(
      id,
      titulo,
      descripcion,
      imagen_ruta_storage,
      fecha_inicio,
      fecha_fin,
      radio_alerta_metros,
      activa,
      establecimientos!inner(
        id,
        nombre,
        categoria_id,
        latitud,
        longitud,
        estado,
        publicable,
        ciudad,
        provincia,
        categorias!inner(nombre)
      )
    )
  ''';

  Future<List<PromocionDestacadaModel>> listarVigentes({
    String ciudad = 'Tulcán',
    String provincia = 'Carchi',
    int limite = 8,
  }) async {
    final ciudadNormalizada = ciudad.trim();
    final provinciaNormalizada = provincia.trim();
    if (ciudadNormalizada.isEmpty || provinciaNormalizada.isEmpty) {
      throw ArgumentError('La ciudad y la provincia son obligatorias.');
    }
    if (limite < 1 || limite > 20) {
      throw ArgumentError.value(limite, 'limite', 'Debe estar entre 1 y 20.');
    }

    final ahora = DateTime.now().toUtc().toIso8601String();

    // La base de datos aplica RLS. Filtramos explicitamente tambien porque
    // los administradores pueden consultar campanas pendientes por su rol.
    final respuesta = await _supabase
        .from('promociones_destacadas')
        .select(_columnas)
        .eq('estado', 'aprobada')
        .lte('fecha_inicio', ahora)
        .gte('fecha_fin', ahora)
        .eq('promociones.activa', true)
        .lte('promociones.fecha_inicio', ahora)
        .gte('promociones.fecha_fin', ahora)
        .eq('promociones.establecimientos.estado', 'aprobado')
        .eq('promociones.establecimientos.publicable', true)
        .ilike('promociones.establecimientos.ciudad', ciudadNormalizada)
        .ilike('promociones.establecimientos.provincia', provinciaNormalizada)
        .order('fecha_inicio', ascending: false)
        .limit(limite);

    final vistas = <String>{};
    final promociones = <PromocionDestacadaModel>[];
    for (final fila in respuesta) {
      final datos = fila['promociones'];
      if (datos is! Map) continue;
      final promocion = PromocionDestacadaModel.fromSupabase(
        Map<String, dynamic>.from(datos),
      );
      if (!vistas.add(promocion.id) ||
          !promocion.activa ||
          !promocion.estaVigente) {
        continue;
      }
      promociones.add(promocion);
    }

    // Al igual que el servicio publico, usar URL temporal para las imagenes.
    return Future.wait(
      promociones.map((promocion) async {
        final ruta = promocion.imagenRutaStorage;
        if (ruta == null || ruta.trim().isEmpty) return promocion;
        try {
          final url = await _supabase.storage
              .from('promociones-imagenes')
              .createSignedUrl(ruta, 3600);
          return promocion.copiarCon(urlImagen: url);
        } catch (_) {
          return promocion; // La tarjeta usara su imagen de respaldo.
        }
      }),
    );
  }
}
