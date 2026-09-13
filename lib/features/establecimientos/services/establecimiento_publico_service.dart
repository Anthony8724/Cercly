import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_publico_model.dart';

class EstablecimientoPublicoService {
  EstablecimientoPublicoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static const String bucketEstablecimientos = 'establecimientos-imagenes';

  static const String bucketPromociones = 'promociones-imagenes';

  static const double radioTierraMetros = 6371000;

  final SupabaseClient _supabase;

  static const String _columnasPublicas = '''
    id,
    nombre,
    descripcion,
    direccion,
    latitud,
    longitud,
    telefono_publico,
    zona_horaria,
    categorias!inner(
      id,
      nombre,
      slug,
      icono
    ),
    fotos_establecimiento(
      id,
      ruta_storage,
      es_portada,
      orden
    ),
    promociones(
      id,
      titulo,
      descripcion,
      imagen_ruta_storage,
      fecha_inicio,
      fecha_fin,
      radio_alerta_metros
    )
  ''';

  Future<List<EstablecimientoPublicoModel>> listar({
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

    var consulta = _supabase
        .from('establecimientos')
        .select(_columnasPublicas)
        .eq('estado', 'aprobado');

    final categoria = categoriaId?.trim();

    if (categoria != null && categoria.isNotEmpty) {
      consulta = consulta.eq('categoria_id', categoria);
    }

    final respuesta = await consulta.order('nombre');

    final filas = List<Map<String, dynamic>>.from(respuesta);

    final establecimientos = await Future.wait(
      filas.map(
        (fila) => _convertirEstablecimiento(
          fila,
          latitudUsuario: latitudUsuario,
          longitudUsuario: longitudUsuario,
        ),
      ),
    );

    final resultado = establecimientos.where((establecimiento) {
      if (radioMaximoMetros == null) {
        return true;
      }

      final distancia = establecimiento.distanciaMetros;

      return distancia != null && distancia <= radioMaximoMetros;
    }).toList();

    if (latitudUsuario != null && longitudUsuario != null) {
      resultado.sort((primero, segundo) {
        return (primero.distanciaMetros ?? double.infinity).compareTo(
          segundo.distanciaMetros ?? double.infinity,
        );
      });
    } else {
      resultado.sort((primero, segundo) {
        return primero.nombre.toLowerCase().compareTo(
          segundo.nombre.toLowerCase(),
        );
      });
    }

    return resultado;
  }

  Future<EstablecimientoPublicoModel?> obtenerPorId(
    String establecimientoId, {
    double? latitudUsuario,
    double? longitudUsuario,
  }) async {
    final id = establecimientoId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'El identificador del establecimiento es obligatorio.',
      );
    }

    _validarUbicacion(
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
    );

    final respuesta = await _supabase
        .from('establecimientos')
        .select(_columnasPublicas)
        .eq('id', id)
        .eq('estado', 'aprobado')
        .maybeSingle();

    if (respuesta == null) {
      return null;
    }

    return _convertirEstablecimiento(
      respuesta,
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
    );
  }

  Future<EstablecimientoPublicoModel> _convertirEstablecimiento(
    Map<String, dynamic> datos, {
    double? latitudUsuario,
    double? longitudUsuario,
  }) async {
    final establecimiento = EstablecimientoPublicoModel.fromSupabase(datos);

    final rutaPortada = establecimiento.rutaFotoPortada;

    final urlPortada = rutaPortada == null
        ? null
        : await _crearUrlTemporal(
            bucket: bucketEstablecimientos,
            ruta: rutaPortada,
          );

    final promocionesConImagen = await Future.wait(
      establecimiento.promociones.map((promocion) async {
        final rutaImagen = promocion.imagenRutaStorage;

        if (rutaImagen == null || rutaImagen.isEmpty) {
          return promocion;
        }

        final url = await _crearUrlTemporal(
          bucket: bucketPromociones,
          ruta: rutaImagen,
        );

        return promocion.copiarConUrl(url);
      }),
    );

    double? distancia;

    if (latitudUsuario != null && longitudUsuario != null) {
      distancia = calcularDistanciaMetros(
        latitudOrigen: latitudUsuario,
        longitudOrigen: longitudUsuario,
        latitudDestino: establecimiento.latitud,
        longitudDestino: establecimiento.longitud,
      );
    }

    return establecimiento.copiarCon(
      urlFotoPortada: urlPortada,
      promociones: promocionesConImagen,
      distanciaMetros: distancia,
    );
  }

  Future<String?> _crearUrlTemporal({
    required String bucket,
    required String ruta,
  }) async {
    try {
      return await _supabase.storage.from(bucket).createSignedUrl(ruta, 3600);
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
