import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/estadisticas_admin_model.dart';

enum GranularidadRegistros { dia, semana, mes }

extension GranularidadRegistrosX on GranularidadRegistros {
  /// Valor que espera la función `admin_estadisticas_registros`.
  String get valorRpc => switch (this) {
    GranularidadRegistros.dia => 'dia',
    GranularidadRegistros.semana => 'semana',
    GranularidadRegistros.mes => 'mes',
  };

  String get etiqueta => switch (this) {
    GranularidadRegistros.dia => 'Día',
    GranularidadRegistros.semana => 'Semana',
    GranularidadRegistros.mes => 'Mes',
  };
}

/// Lee estadísticas agregadas del panel de administración.
///
/// La autorización se verifica en el backend (las funciones RPC llaman a
/// `es_administrador()`); este servicio no decide quién puede ver los datos.
class EstadisticasAdministradorService {
  EstadisticasAdministradorService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<EstadisticasResumenModel> obtenerResumen({
    int diasActivos = 30,
  }) async {
    final respuesta = await _supabase.rpc(
      'admin_estadisticas_resumen',
      params: {'p_dias_activos': diasActivos},
    );

    if (respuesta is! Map) {
      throw const FormatException('Respuesta de resumen inesperada.');
    }

    return EstadisticasResumenModel.fromJson(
      Map<String, dynamic>.from(respuesta),
    );
  }

  Future<List<RegistroPeriodoModel>> obtenerRegistros({
    required DateTime desde,
    required DateTime hasta,
    GranularidadRegistros granularidad = GranularidadRegistros.dia,
  }) async {
    final respuesta = await _supabase.rpc(
      'admin_estadisticas_registros',
      params: {
        'p_desde': _fechaIso(desde),
        'p_hasta': _fechaIso(hasta),
        'p_granularidad': granularidad.valorRpc,
      },
    );

    if (respuesta is! List) {
      throw const FormatException('Respuesta de registros inesperada.');
    }

    return respuesta
        .map<RegistroPeriodoModel>(
          (fila) => RegistroPeriodoModel.fromJson(
            Map<String, dynamic>.from(fila as Map),
          ),
        )
        .toList();
  }

  static const int _tamanoPagina = 200;

  Stream<List<DetalleEstadisticaItem>> streamDetalleIndicador(
    TipoIndicadorAdmin tipo, {
    int diasActivos = 30,
  }) {
    return Stream.fromFuture(
      obtenerDetalleIndicador(tipo, diasActivos: diasActivos),
    );
  }

  Future<List<DetalleEstadisticaItem>> obtenerDetalleIndicador(
    TipoIndicadorAdmin tipo, {
    int diasActivos = 30,
  }) async {
    final autorizado = await _supabase.rpc('es_administrador');

    if (autorizado != true) {
      throw const PostgrestException(message: 'No autorizado', code: '42501');
    }

    switch (tipo) {
      case TipoIndicadorAdmin.usuariosRegistrados:
        return _paginar(
          (inicio, fin) async => await _supabase
              .from('usuarios')
              .select('id,nombre,rol')
              .order('nombre', ascending: true)
              .order('id', ascending: true)
              .range(inicio, fin),
          (filas) async => filas
              .map(
                (r) => DetalleEstadisticaItem(
                  titulo: (r['nombre'] ?? 'Sin nombre').toString(),
                  subtitulo: _etiquetaRol(r['rol']?.toString()),
                ),
              )
              .toList(),
        );

      case TipoIndicadorAdmin.propietarios:
        return _paginar(
          (inicio, fin) async => await _supabase
              .from('usuarios')
              .select('id,nombre,rol')
              .eq('rol', 'propietario')
              .order('nombre', ascending: true)
              .order('id', ascending: true)
              .range(inicio, fin),
          (filas) async => filas
              .map(
                (r) => DetalleEstadisticaItem(
                  titulo: (r['nombre'] ?? 'Sin nombre').toString(),
                  subtitulo: 'Propietario',
                ),
              )
              .toList(),
        );

      case TipoIndicadorAdmin.usuariosActivos:
        return _obtenerUsuariosActivos30Dias(diasActivos);

      case TipoIndicadorAdmin.solicitudesPendientes:
        return _paginar(
          (inicio, fin) async => await _supabase
              .from('solicitudes_establecimientos')
              .select('id,mensaje,tipo,establecimiento_id,solicitante_id')
              .eq('estado', 'pendiente')
              .order('id', ascending: true)
              .range(inicio, fin),
          _obtenerDetalleSolicitudesPendientes,
        );

      case TipoIndicadorAdmin.establecimientos:
        return _paginar(
          (inicio, fin) async => await _supabase
              .from('establecimientos')
              .select('id,nombre,estado')
              .order('nombre', ascending: true)
              .order('id', ascending: true)
              .range(inicio, fin),
          (filas) async => filas
              .map(
                (r) => DetalleEstadisticaItem(
                  titulo: (r['nombre'] ?? 'Sin nombre').toString(),
                  subtitulo: (r['estado'] ?? '').toString(),
                ),
              )
              .toList(),
        );

      case TipoIndicadorAdmin.promocionesActivas:
        return _paginar(
          (inicio, fin) async => await _supabase
              .from('promociones')
              .select('id,titulo')
              .eq('activa', true)
              .order('titulo', ascending: true)
              .order('id', ascending: true)
              .range(inicio, fin),
          (filas) async => filas
              .map(
                (r) => DetalleEstadisticaItem(
                  titulo: (r['titulo'] ?? 'Promoción').toString(),
                  subtitulo: 'Activa',
                ),
              )
              .toList(),
        );
    }
  }

  Future<List<DetalleEstadisticaItem>> _paginar(
    Future<List<Map<String, dynamic>>> Function(int inicio, int fin)
    obtenerPagina,
    Future<List<DetalleEstadisticaItem>> Function(
      List<Map<String, dynamic>> filas,
    )
    convertir,
  ) async {
    final resultado = <DetalleEstadisticaItem>[];
    final ids = <String>{};
    var inicio = 0;

    while (true) {
      final filas = await obtenerPagina(inicio, inicio + _tamanoPagina - 1);

      if (filas.length > _tamanoPagina) {
        throw const FormatException('Página inválida.');
      }

      for (final fila in filas) {
        final id = fila['id'];

        if (id is! String || id.isEmpty || !ids.add(id)) {
          throw const FormatException('Identificador inválido o duplicado.');
        }
      }

      resultado.addAll(await convertir(filas));

      if (filas.length < _tamanoPagina) {
        break;
      }

      inicio += _tamanoPagina;
    }

    return resultado;
  }

  // Limita la longitud de las URLs con filtros UUID.
  static const int _tamanoLoteRelacion = 40;

  Future<Map<String, String>> _obtenerNombresPorLotes(
    String tabla,
    Set<String> ids,
  ) async {
    final nombres = <String, String>{};
    final lista = ids.toList();

    for (var inicio = 0; inicio < lista.length; inicio += _tamanoLoteRelacion) {
      final lote = lista.skip(inicio).take(_tamanoLoteRelacion).toList();

      final filas = await _supabase
          .from(tabla)
          .select('id,nombre')
          .inFilter('id', lote);

      for (final fila in filas) {
        final id = fila['id']?.toString().trim();
        final nombre = fila['nombre']?.toString().trim();

        if (id != null &&
            id.isNotEmpty &&
            nombre != null &&
            nombre.isNotEmpty) {
          nombres[id] = nombre;
        }
      }
    }

    return nombres;
  }

  Future<List<DetalleEstadisticaItem>> _obtenerDetalleSolicitudesPendientes(
    List<dynamic> rows,
  ) async {
    if (rows.isEmpty) {
      return const <DetalleEstadisticaItem>[];
    }

    final normalizadas = rows
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    final estIds = <String>{};
    final solIds = <String>{};

    for (final r in normalizadas) {
      final estId = r['establecimiento_id']?.toString().trim();
      if (estId != null && estId.isNotEmpty) {
        estIds.add(estId);
      }
      final solId = r['solicitante_id']?.toString().trim();
      if (solId != null && solId.isNotEmpty) {
        solIds.add(solId);
      }
    }

    final nombresEstablecimientos = await _obtenerNombresPorLotes(
      'establecimientos',
      estIds,
    );

    final nombresSolicitantes = await _obtenerNombresPorLotes(
      'usuarios',
      solIds,
    );

    final items = <DetalleEstadisticaItem>[];
    for (final r in normalizadas) {
      String titulo = (r['mensaje'] ?? '').toString().trim();
      String subtitulo = (r['tipo'] ?? 'Pendiente de revisión')
          .toString()
          .trim();

      final estId = r['establecimiento_id']?.toString().trim();
      if (estId != null && estId.isNotEmpty) {
        final nombreEst = nombresEstablecimientos[estId];
        if (nombreEst != null && nombreEst.isNotEmpty) {
          titulo = nombreEst;
        }
      }

      final solId = r['solicitante_id']?.toString().trim();
      if (solId != null && solId.isNotEmpty) {
        final nombreUsr = nombresSolicitantes[solId];
        if (nombreUsr != null && nombreUsr.isNotEmpty) {
          subtitulo = 'Solicitante: $nombreUsr';
        }
      }

      if (titulo.isEmpty) {
        titulo = 'Solicitud';
      }

      items.add(DetalleEstadisticaItem(titulo: titulo, subtitulo: subtitulo));
    }

    return items;
  }

  Future<List<DetalleEstadisticaItem>> _obtenerUsuariosActivos30Dias(
    int diasActivos,
  ) {
    return _paginar(
      (inicio, fin) async {
        final rpc = await _supabase.rpc(
          'admin_usuarios_activos_detalle',
          params: {
            'p_dias_activos': diasActivos,
            'p_limite': fin - inicio + 1,
            'p_offset': inicio,
          },
        );

        if (rpc is! List) {
          throw const FormatException(
            'Respuesta de usuarios activos inesperada.',
          );
        }

        return rpc
            .map((fila) => Map<String, dynamic>.from(fila as Map))
            .toList();
      },
      (filas) async => filas
          .map(
            (fila) => DetalleEstadisticaItem(
              titulo: (fila['nombre'] ?? 'Sin nombre').toString(),
              subtitulo: _etiquetaRol(fila['rol']?.toString()),
              estado: 'Activo',
            ),
          )
          .toList(),
    );
  }

  String _etiquetaRol(String? rol) => switch (rol) {
    'propietario' => 'Propietario',
    'administrador' => 'Administrador',
    _ => 'Usuario',
  };

  /// Mensajes seguros para mostrar en la interfaz.
  static String mensajeError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'No tienes permisos de administrador para ver estas estadísticas.';
      }
      if (error.code == 'PGRST202') {
        return 'Las estadísticas no están disponibles. '
            'Falta aplicar la migración correspondiente.';
      }
      return 'No se pudieron cargar las estadísticas.';
    }

    if (error is FormatException) {
      return 'La respuesta de estadísticas no tiene el formato esperado.';
    }

    return 'No se pudieron cargar las estadísticas. Revisa tu conexión.';
  }

  static String _fechaIso(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }
}
