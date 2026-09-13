import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promocion_destacada_model.dart';

class PromocionPublicaService {
  PromocionPublicaService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static const String bucketPromociones = 'promociones-imagenes';
  static const double radioTierraMetros = 6371000;

  final SupabaseClient _supabase;

  static const String _columnasPublicas = '''
    id,
    titulo,
    descripcion,
    imagen_ruta_storage,
    fecha_inicio,
    fecha_fin,
    radio_alerta_metros,
    establecimientos!inner(
      id,
      nombre,
      categoria_id,
      latitud,
      longitud,
      estado,
      categorias!inner(
        nombre
      )
    )
  ''';

  Future<List<PromocionDestacadaModel>> listarVigentes({
    String? categoriaId,
    double? latitudUsuario,
    double? longitudUsuario,
    double? radioMaximoMetros,
  }) async {
    _validarUbicacion(
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
      radioMaximoMetros: radioMaximoMetros,
    );

    final ahora = DateTime.now().toUtc().toIso8601String();

    var consulta = _supabase
        .from('promociones')
        .select(_columnasPublicas)
        .eq('activa', true)
        .lte('fecha_inicio', ahora)
        .gte('fecha_fin', ahora)
        .eq('establecimientos.estado', 'aprobado');

    final categoria = categoriaId?.trim();

    if (categoria != null && categoria.isNotEmpty) {
      consulta = consulta.eq('establecimientos.categoria_id', categoria);
    }

    final respuesta = await consulta.order('fecha_fin');

    final filas = List<Map<String, dynamic>>.from(respuesta);

    final promociones = await Future.wait(
      filas.map(
        (fila) => _convertirPromocion(
          fila,
          latitudUsuario: latitudUsuario,
          longitudUsuario: longitudUsuario,
        ),
      ),
    );

    final resultado = promociones.where((promocion) {
      if (radioMaximoMetros == null) {
        return true;
      }

      final distancia = promocion.distanciaMetros;

      return distancia != null && distancia <= radioMaximoMetros;
    }).toList();

    if (latitudUsuario != null && longitudUsuario != null) {
      resultado.sort((primera, segunda) {
        return (primera.distanciaMetros ?? double.infinity).compareTo(
          segunda.distanciaMetros ?? double.infinity,
        );
      });
    } else {
      resultado.sort((primera, segunda) {
        return primera.fechaFin.compareTo(segunda.fechaFin);
      });
    }

    return resultado;
  }

  Future<List<PromocionDestacadaModel>> listarCercanas({
    required double latitudUsuario,
    required double longitudUsuario,
  }) async {
    final promociones = await listarVigentes(
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
    );

    return promociones
        .where((promocion) {
          final distancia = promocion.distanciaMetros;

          return distancia != null && distancia <= promocion.radioAlertaMetros;
        })
        .toList(growable: false);
  }

  Future<PromocionDestacadaModel?> obtenerPorId(
    String promocionId, {
    double? latitudUsuario,
    double? longitudUsuario,
  }) async {
    final id = promocionId.trim();

    if (id.isEmpty) {
      throw ArgumentError('El identificador de la promoción es obligatorio.');
    }

    _validarUbicacion(
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
    );

    final ahora = DateTime.now().toUtc().toIso8601String();

    final respuesta = await _supabase
        .from('promociones')
        .select(_columnasPublicas)
        .eq('id', id)
        .eq('activa', true)
        .lte('fecha_inicio', ahora)
        .gte('fecha_fin', ahora)
        .eq('establecimientos.estado', 'aprobado')
        .maybeSingle();

    if (respuesta == null) {
      return null;
    }

    return _convertirPromocion(
      respuesta,
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
    );
  }

  Future<PromocionDestacadaModel> _convertirPromocion(
    Map<String, dynamic> datos, {
    double? latitudUsuario,
    double? longitudUsuario,
  }) async {
    final promocion = PromocionDestacadaModel.fromSupabase(datos);

    String? urlImagen;

    final ruta = promocion.imagenRutaStorage;

    if (ruta != null && ruta.isNotEmpty) {
      urlImagen = await _crearUrlTemporal(ruta);
    }

    double? distanciaMetros;

    if (latitudUsuario != null && longitudUsuario != null) {
      distanciaMetros = calcularDistanciaMetros(
        latitudOrigen: latitudUsuario,
        longitudOrigen: longitudUsuario,
        latitudDestino: promocion.latitud,
        longitudDestino: promocion.longitud,
      );
    }

    return promocion.copiarCon(
      urlImagen: urlImagen,
      distanciaMetros: distanciaMetros,
    );
  }

  Future<String?> _crearUrlTemporal(String ruta) async {
    try {
      return await _supabase.storage
          .from(bucketPromociones)
          .createSignedUrl(ruta, 3600);
    } catch (_) {
      return null;
    }
  }

  double calcularDistanciaMetros({
    required double latitudOrigen,
    required double longitudOrigen,
    required double latitudDestino,
    required double longitudDestino,
  }) {
    _validarCoordenada(latitud: latitudOrigen, longitud: longitudOrigen);

    _validarCoordenada(latitud: latitudDestino, longitud: longitudDestino);

    final latitud1 = _gradosARadianes(latitudOrigen);
    final latitud2 = _gradosARadianes(latitudDestino);

    final diferenciaLatitud = _gradosARadianes(latitudDestino - latitudOrigen);

    final diferenciaLongitud = _gradosARadianes(
      longitudDestino - longitudOrigen,
    );

    final a =
        math.sin(diferenciaLatitud / 2) * math.sin(diferenciaLatitud / 2) +
        math.cos(latitud1) *
            math.cos(latitud2) *
            math.sin(diferenciaLongitud / 2) *
            math.sin(diferenciaLongitud / 2);

    final valorSeguro = a.clamp(0.0, 1.0).toDouble();

    final angulo =
        2 * math.atan2(math.sqrt(valorSeguro), math.sqrt(1 - valorSeguro));

    return radioTierraMetros * angulo;
  }

  void _validarUbicacion({
    required double? latitudUsuario,
    required double? longitudUsuario,
    double? radioMaximoMetros,
  }) {
    final tieneLatitud = latitudUsuario != null;
    final tieneLongitud = longitudUsuario != null;

    if (tieneLatitud != tieneLongitud) {
      throw ArgumentError('La latitud y la longitud deben enviarse juntas.');
    }

    if (latitudUsuario != null && longitudUsuario != null) {
      _validarCoordenada(latitud: latitudUsuario, longitud: longitudUsuario);
    }

    if (radioMaximoMetros != null) {
      if (!tieneLatitud || !tieneLongitud) {
        throw ArgumentError(
          'Para aplicar un radio debes indicar la ubicación.',
        );
      }

      if (radioMaximoMetros <= 0) {
        throw ArgumentError('El radio máximo debe ser mayor que cero.');
      }
    }
  }

  void _validarCoordenada({required double latitud, required double longitud}) {
    if (latitud < -90 || latitud > 90) {
      throw ArgumentError('La latitud debe estar entre -90 y 90.');
    }

    if (longitud < -180 || longitud > 180) {
      throw ArgumentError('La longitud debe estar entre -180 y 180.');
    }
  }

  double _gradosARadianes(double grados) {
    return grados * math.pi / 180;
  }
}
