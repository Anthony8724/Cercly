import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_publico_model.dart';
import '../models/turno_horario.dart';
import 'estado_horario_service.dart';

typedef EjecutarRpcCercanos = Future<List<Map<String, dynamic>>> Function(
  Map<String, dynamic> parametros,
);

typedef CargarDetallesPublicos = Future<List<Map<String, dynamic>>> Function(
  List<String> ids,
);

typedef CargarHorariosPublicos = Future<List<Map<String, dynamic>>> Function(
  List<String> ids,
);

abstract interface class EstablecimientoCercanoRepository {
  Future<List<EstablecimientoPublicoModel>> buscarCercanos({
    required double latitud,
    required double longitud,
    int radioMetros = 5000,
    String? categoriaId,
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    int limite = 20,
    int desplazamiento = 0,
  });
}

class EstablecimientoPublicoService
    implements EstablecimientoCercanoRepository {
  EstablecimientoPublicoService({
    SupabaseClient? supabase,
    EjecutarRpcCercanos? ejecutarRpcCercanos,
    CargarDetallesPublicos? cargarDetallesPublicos,
    CargarHorariosPublicos? cargarHorariosPublicos,
    EstadoHorarioService estadoHorarioService = const EstadoHorarioService(),
  }) : _supabase = supabase ?? Supabase.instance.client,
       _ejecutarRpcCercanos = ejecutarRpcCercanos,
       _cargarDetallesPublicos = cargarDetallesPublicos,
       _cargarHorariosPublicos = cargarHorariosPublicos,
       _estadoHorarioService = estadoHorarioService;

  static const String bucketEstablecimientos = 'establecimientos-imagenes';
  static const String bucketPromociones = 'promociones-imagenes';
  static const double radioTierraMetros = 6371000;

  final SupabaseClient _supabase;
  final EjecutarRpcCercanos? _ejecutarRpcCercanos;
  final CargarDetallesPublicos? _cargarDetallesPublicos;
  final CargarHorariosPublicos? _cargarHorariosPublicos;
  final EstadoHorarioService _estadoHorarioService;

  static const String _columnasPublicas = '''
    id,
    nombre,
    descripcion,
    direccion,
    latitud,
    longitud,
    telefono_publico,
    zona_horaria,
    ciudad,
    provincia,
    pais_codigo,
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
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    int limite = 20,
    int desplazamiento = 0,
  }) async {
    _validarUbicacion(
      latitudUsuario: latitudUsuario,
      longitudUsuario: longitudUsuario,
      radioMaximoMetros: radioMaximoMetros,
    );

    if (latitudUsuario != null && longitudUsuario != null) {
      return buscarCercanos(
        latitud: latitudUsuario,
        longitud: longitudUsuario,
        radioMetros: radioMaximoMetros?.round() ?? 5000,
        categoriaId: categoriaId,
        subcategoriaIds: subcategoriaIds,
        soloPromociones: soloPromociones,
        limite: limite,
        desplazamiento: desplazamiento,
      );
    }

    var consulta = _supabase
        .from('establecimientos')
        .select(_columnasPublicas)
        .eq('estado', 'aprobado')
        .eq('publicable', true);

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
      if (radioMaximoMetros == null) return true;
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

  @override
  Future<List<EstablecimientoPublicoModel>> buscarCercanos({
    required double latitud,
    required double longitud,
    int radioMetros = 5000,
    String? categoriaId,
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    int limite = 20,
    int desplazamiento = 0,
  }) async {
    _validarCoordenada(latitud: latitud, longitud: longitud);

    if (radioMetros < 1 || radioMetros > 50000) {
      throw ArgumentError('El radio debe estar entre 1 y 50000 metros.');
    }
    if (limite < 1 || limite > 100) {
      throw ArgumentError('El límite debe estar entre 1 y 100.');
    }
    if (desplazamiento < 0) {
      throw ArgumentError('El desplazamiento no puede ser negativo.');
    }

    final categoria = categoriaId?.trim();
    final subcategorias = subcategoriaIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final parametros = <String, dynamic>{
      'p_latitud': latitud,
      'p_longitud': longitud,
      'p_radio_metros': radioMetros,
      'p_categoria_id': categoria == null || categoria.isEmpty
          ? null
          : categoria,
      'p_subcategoria_ids': subcategorias == null || subcategorias.isEmpty
          ? null
          : subcategorias,
      'p_solo_promociones': soloPromociones,
      'p_limite': limite,
      'p_desplazamiento': desplazamiento,
    };

    final filasRpc = _ejecutarRpcCercanos == null
        ? List<Map<String, dynamic>>.from(
            await _supabase.rpc(
              'buscar_establecimientos_cercanos',
              params: parametros,
            ),
          )
        : await _ejecutarRpcCercanos(parametros);

    if (filasRpc.isEmpty) {
      return const <EstablecimientoPublicoModel>[];
    }

    final ids = filasRpc.map((fila) => fila['id'] as String).toList();

    final filasDetalles = _cargarDetallesPublicos == null
        ? List<Map<String, dynamic>>.from(
            await _supabase
                .from('establecimientos')
                .select(_columnasPublicas)
                .inFilter('id', ids)
                .eq('estado', 'aprobado')
                .eq('publicable', true),
          )
        : await _cargarDetallesPublicos(ids);

    final estadosHorario = await _cargarEstadosHorario(ids);
    final detallesPorId = <String, EstablecimientoPublicoModel>{};

    for (final fila in filasDetalles) {
      final detalle = await _convertirEstablecimiento(fila);
      detallesPorId[detalle.id] = detalle.copiarCon(
        estadoHorario: estadosHorario[detalle.id] ?? 'sinHorario',
      );
    }

    return filasRpc
        .map((filaRpc) {
          final id = filaRpc['id'] as String;
          final detalle = detallesPorId[id];

          if (detalle == null) return null;

          return detalle.copiarCon(
            distanciaMetros: (filaRpc['distancia_metros'] as num).toDouble(),
            tienePromocionesRpc: filaRpc['tiene_promociones'] as bool? ?? false,
          );
        })
        .whereType<EstablecimientoPublicoModel>()
        .toList(growable: false);
  }

  Future<Map<String, String>> _cargarEstadosHorario(List<String> ids) async {
    final filas = _cargarHorariosPublicos == null
        ? List<Map<String, dynamic>>.from(
            await _supabase
                .from('horarios_establecimiento')
                .select(
                  'establecimiento_id, dia_semana, apertura_minutos, '
                  'cierre_minutos, cierra_al_dia_siguiente',
                )
                .inFilter('establecimiento_id', ids),
          )
        : await _cargarHorariosPublicos(ids);

    final horariosPorEstablecimiento = <
      String,
      Map<String, List<TurnoHorario>>
    >{};

    const dias = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];

    for (final id in ids) {
      horariosPorEstablecimiento[id] = {
        for (final dia in dias) dia: <TurnoHorario>[],
      };
    }

    for (final fila in filas) {
      final id = fila['establecimiento_id'] as String?;
      final numeroDia = fila['dia_semana'] as int?;

      if (id == null ||
          numeroDia == null ||
          numeroDia < 1 ||
          numeroDia > 7 ||
          !horariosPorEstablecimiento.containsKey(id)) {
        continue;
      }

      horariosPorEstablecimiento[id]![dias[numeroDia - 1]]!.add(
        TurnoHorario(
          aperturaMinutos: fila['apertura_minutos'] as int,
          cierreMinutos: fila['cierre_minutos'] as int,
          cierraAlDiaSiguiente:
              fila['cierra_al_dia_siguiente'] as bool? ?? false,
        ),
      );
    }

    final ahora = DateTime.now();
    return {
      for (final entrada in horariosPorEstablecimiento.entries)
        entrada.key: _estadoHorarioService
            .calcular(ahora: ahora, horario: entrada.value)
            .name,
    };
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
        .eq('publicable', true)
        .maybeSingle();

    if (respuesta == null) return null;

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
        if (rutaImagen == null || rutaImagen.isEmpty) return promocion;

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
