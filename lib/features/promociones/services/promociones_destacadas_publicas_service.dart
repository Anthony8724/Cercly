import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promocion_destacada_model.dart';

/// Calcula distancia ortodrómica sobre la esfera, suficiente para radios
/// urbanos de Cercly. No ejecuta consultas a Supabase.
double distanciaDestacadaMetros(
  double latitud1,
  double longitud1,
  double latitud2,
  double longitud2,
) {
  const radioTierra = 6371000.0;
  final dLat = (latitud2 - latitud1) * math.pi / 180;
  final dLon = (longitud2 - longitud1) * math.pi / 180;
  final rLat1 = latitud1 * math.pi / 180;
  final rLat2 = latitud2 * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rLat1) *
          math.cos(rLat2) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final seguro = a.clamp(0.0, 1.0).toDouble();
  return 2 * radioTierra * math.atan2(math.sqrt(seguro), math.sqrt(1 - seguro));
}

/// Aplica el radio exacto, ordena de la más cercana a la más lejana y limita
/// las tarjetas. Sin GPS conserva el orden de entrada (más reciente primero).
List<PromocionDestacadaModel> seleccionarDestacadas({
  required Iterable<PromocionDestacadaModel> candidatas,
  required int limite,
  double? latitudUsuario,
  double? longitudUsuario,
  double? radioMaximoMetros,
}) {
  if (limite < 1) throw ArgumentError.value(limite, 'limite');
  if ((latitudUsuario == null) != (longitudUsuario == null)) {
    throw ArgumentError('Latitud y longitud deben enviarse juntas.');
  }
  if (radioMaximoMetros != null &&
      (latitudUsuario == null || longitudUsuario == null)) {
    throw ArgumentError('El radio requiere una ubicación GPS.');
  }
  if (radioMaximoMetros != null &&
      (!radioMaximoMetros.isFinite || radioMaximoMetros <= 0)) {
    throw ArgumentError('El radio debe ser positivo y finito.');
  }
  final resultado = <PromocionDestacadaModel>[];
  for (final candidata in candidatas) {
    if (latitudUsuario == null || longitudUsuario == null) {
      resultado.add(candidata);
      continue;
    }
    final distancia = distanciaDestacadaMetros(
      latitudUsuario,
      longitudUsuario,
      candidata.latitud,
      candidata.longitud,
    );
    if (radioMaximoMetros != null && distancia > radioMaximoMetros) continue;
    resultado.add(candidata.copiarCon(distanciaMetros: distancia));
  }
  if (latitudUsuario != null) {
    resultado.sort(
      (a, b) => (a.distanciaMetros ?? double.infinity).compareTo(
        b.distanciaMetros ?? double.infinity,
      ),
    );
  }
  return resultado.take(limite).toList(growable: false);
}

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
    double? latitudUsuario,
    double? longitudUsuario,
    double? radioMaximoMetros,
    int limite = 8,
  }) async {
    if (limite < 1 || limite > 20) {
      throw ArgumentError.value(limite, 'limite', 'Debe estar entre 1 y 20.');
    }
    if ((latitudUsuario == null) != (longitudUsuario == null)) {
      throw ArgumentError('Latitud y longitud deben enviarse juntas.');
    }
    if (latitudUsuario != null &&
        (!latitudUsuario.isFinite ||
            latitudUsuario < -90 ||
            latitudUsuario > 90)) {
      throw ArgumentError('Latitud GPS inválida.');
    }
    if (longitudUsuario != null &&
        (!longitudUsuario.isFinite ||
            longitudUsuario < -180 ||
            longitudUsuario > 180)) {
      throw ArgumentError('Longitud GPS inválida.');
    }
    if (radioMaximoMetros != null &&
        (latitudUsuario == null ||
            longitudUsuario == null ||
            !radioMaximoMetros.isFinite ||
            radioMaximoMetros <= 0)) {
      throw ArgumentError('Un radio válido requiere coordenadas GPS.');
    }

    final ahora = DateTime.now().toUtc().toIso8601String();
    // Sólo campañas pagadas y aprobadas, independientemente de la ciudad.
    // La RLS aplica la misma regla incluso si el cliente omite los filtros.
    var consulta = _supabase
        .from('promociones_destacadas')
        .select(_columnas)
        .eq('estado', 'aprobada')
        .not('pago_confirmado_en', 'is', null)
        .lte('fecha_inicio', ahora)
        .gte('fecha_fin', ahora)
        .eq('promociones.activa', true)
        .lte('promociones.fecha_inicio', ahora)
        .gte('promociones.fecha_fin', ahora)
        .eq('promociones.establecimientos.estado', 'aprobado')
        .eq('promociones.establecimientos.publicable', true);

    if (latitudUsuario != null &&
        longitudUsuario != null &&
        radioMaximoMetros != null) {
      // Caja delimitadora en SQL: reduce las filas transferidas. El filtro
      // circular exacto se aplica a continuación mediante Haversine.
      final latDelta = radioMaximoMetros / 110000.0;
      final cosLatitud = math.cos(latitudUsuario * math.pi / 180).abs();
      final lonDelta =
          radioMaximoMetros / (110000.0 * math.max(0.01, cosLatitud));
      consulta = consulta
          .gte(
            'promociones.establecimientos.latitud',
            math.max(-90.0, latitudUsuario - latDelta),
          )
          .lte(
            'promociones.establecimientos.latitud',
            math.min(90.0, latitudUsuario + latDelta),
          )
          .gte(
            'promociones.establecimientos.longitud',
            math.max(-180.0, longitudUsuario - lonDelta),
          )
          .lte(
            'promociones.establecimientos.longitud',
            math.min(180.0, longitudUsuario + lonDelta),
          );
    }

    // Límite provisional para evitar consultas ilimitadas. El MVP no tiene
    // aún búsqueda geoespacial SQL; con >500 patrocinios en la caja podrá
    // requerirse PostGIS para garantizar las 8 campañas más cercanas.
    final topeCandidatos = latitudUsuario == null ? limite : 500;
    final respuesta = await consulta
        .order('fecha_inicio', ascending: false)
        .limit(topeCandidatos);

    final vistas = <String>{};
    final candidatas = <PromocionDestacadaModel>[];
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
      candidatas.add(promocion);
    }

    final seleccionadas = seleccionarDestacadas(
      candidatas: candidatas,
      limite: limite,
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
      radioMaximoMetros: radioMaximoMetros,
    );

    // Firmar URLs únicamente para las campañas que realmente se mostrarán.
    return Future.wait(
      seleccionadas.map((promocion) async {
        final ruta = promocion.imagenRutaStorage;
        if (ruta == null || ruta.trim().isEmpty) return promocion;
        try {
          final url = await _supabase.storage
              .from('promociones-imagenes')
              .createSignedUrl(ruta, 3600);
          return promocion.copiarCon(urlImagen: url);
        } catch (_) {
          return promocion;
        }
      }),
    );
  }
}
