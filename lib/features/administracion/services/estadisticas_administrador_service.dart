import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/estadisticas_admin_model.dart';

enum GranularidadRegistros { dia, semana, mes }

extension GranularidadRegistrosX on GranularidadRegistros {
  /// Valor que espera la funciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n `admin_estadisticas_registros`.
  String get valorRpc => switch (this) {
    GranularidadRegistros.dia => 'dia',
    GranularidadRegistros.semana => 'semana',
    GranularidadRegistros.mes => 'mes',
  };

  String get etiqueta => switch (this) {
    GranularidadRegistros.dia => 'DÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­a',
    GranularidadRegistros.semana => 'Semana',
    GranularidadRegistros.mes => 'Mes',
  };
}

/// Lee estadÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â­sticas agregadas del panel de administraciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n.
///
/// La autorizaciÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n se verifica en el backend (las funciones RPC llaman a
/// `es_administrador()`); este servicio no decide quiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©n puede ver los datos.
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

  Stream<List<DetalleEstadisticaItem>> streamDetalleIndicador(
    TipoIndicadorAdmin tipo, {
    int diasActivos = 30,
  }) {
    switch (tipo) {
      case TipoIndicadorAdmin.usuariosRegistrados:
        return _supabase
            .from('usuarios')
            .stream(primaryKey: ['id'])
            .order('nombre', ascending: true)
            .map(
              (rows) => rows
                  .map(
                    (r) => DetalleEstadisticaItem(
                      titulo: (r['nombre'] ?? 'Sin nombre').toString(),
                      subtitulo: _etiquetaRol(r['rol']?.toString()),
                    ),
                  )
                  .toList(),
            );

      case TipoIndicadorAdmin.propietarios:
        return _supabase
            .from('usuarios')
            .stream(primaryKey: ['id'])
            .eq('rol', 'propietario')
            .order('nombre', ascending: true)
            .map(
              (rows) => rows
                  .map(
                    (r) => DetalleEstadisticaItem(
                      titulo: (r['nombre'] ?? 'Sin nombre').toString(),
                      subtitulo: 'Propietario',
                    ),
                  )
                  .toList(),
            );

      case TipoIndicadorAdmin.usuariosActivos:
        return Stream.fromFuture(_obtenerUsuariosActivos30Dias(diasActivos));

      case TipoIndicadorAdmin.solicitudesPendientes:
        return _supabase
            .from('solicitudes_establecimientos')
            .stream(primaryKey: ['id'])
            .eq('estado', 'pendiente')
            .asyncMap(_obtenerDetalleSolicitudesPendientes);

      case TipoIndicadorAdmin.establecimientos:
        return _supabase
            .from('establecimientos')
            .stream(primaryKey: ['id'])
            .order('nombre', ascending: true)
            .map(
              (rows) => rows
                  .map(
                    (r) => DetalleEstadisticaItem(
                      titulo: (r['nombre'] ?? 'Sin nombre').toString(),
                      subtitulo: (r['estado'] ?? '').toString(),
                    ),
                  )
                  .toList(),
            );

      case TipoIndicadorAdmin.promocionesActivas:
        return _supabase
            .from('promociones')
            .stream(primaryKey: ['id'])
            .eq('activa', true)
            .map(
              (rows) => rows
                  .map(
                    (r) => DetalleEstadisticaItem(
                      titulo:
                          (r['titulo'] ??
                                  r['nombre'] ??
                                  'PromociÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n')
                              .toString(),
                      subtitulo: 'Activa',
                    ),
                  )
                  .toList(),
            );
    }
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

    final nombresEstablecimientos = <String, String>{};
    if (estIds.isNotEmpty) {
      final estRows = await _supabase
          .from('establecimientos')
          .select('id, nombre')
          .inFilter('id', estIds.toList());
      for (final fila in estRows as List) {
        final map = Map<String, dynamic>.from(fila as Map);
        final id = map['id']?.toString().trim();
        final nombre = map['nombre']?.toString().trim();
        if (id != null &&
            id.isNotEmpty &&
            nombre != null &&
            nombre.isNotEmpty) {
          nombresEstablecimientos[id] = nombre;
        }
      }
    }

    final nombresSolicitantes = <String, String>{};
    if (solIds.isNotEmpty) {
      final usrRows = await _supabase
          .from('usuarios')
          .select('id, nombre')
          .inFilter('id', solIds.toList());
      for (final fila in usrRows as List) {
        final map = Map<String, dynamic>.from(fila as Map);
        final id = map['id']?.toString().trim();
        final nombre = map['nombre']?.toString().trim();
        if (id != null &&
            id.isNotEmpty &&
            nombre != null &&
            nombre.isNotEmpty) {
          nombresSolicitantes[id] = nombre;
        }
      }
    }

    final items = <DetalleEstadisticaItem>[];
    for (final r in normalizadas) {
      String titulo = (r['mensaje'] ?? '').toString().trim();
      String subtitulo =
          (r['tipo'] ??
                  'Pendiente de revisiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â³n')
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
  ) async {
    final res = <DetalleEstadisticaItem>[];
    var offset = 0;
    const limite = 200;
    while (true) {
      final rpc = await _supabase.rpc(
        'admin_usuarios_activos_detalle',
        params: {
          'p_dias_activos': diasActivos,
          'p_limite': limite,
          'p_offset': offset,
        },
      );
      if (rpc is! List)
        throw const FormatException(
          'Respuesta de usuarios activos inesperada.',
        );
      final pagina = rpc
          .map((f) => Map<String, dynamic>.from(f as Map))
          .toList();
      for (final map in pagina) {
        res.add(
          DetalleEstadisticaItem(
            titulo: (map['nombre'] ?? 'Sin nombre').toString(),
            subtitulo: _etiquetaRol(map['rol']?.toString()),
            estado: 'Activo',
          ),
        );
      }
      if (pagina.length < limite) {
        break;
      }
      offset += limite;
    }
    return res;
  }

  String _etiquetaRol(String? rol) => switch (rol) {
    'propietario' => 'Propietario',
    'administrador' => 'Administrador',
    _ => 'Usuario',
  };

  static String mensajeError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'No tienes permisos de administrador para ver estas estad\u00edsticas.';
      }
      if (error.code == 'PGRST202') {
        return 'Falta aplicar la migraci\u00f3n de estad\u00edsticas en la base de datos.';
      }
      return error.message.isNotEmpty
          ? error.message
          : 'Error de base de datos.';
    }
    if (error is FormatException) {
      return 'Formato de respuesta inesperado: ' + error.message;
    }
    return 'Error de conexi\u00f3n o inesperado: ' + error.toString();
  }

  static String _fechaIso(DateTime fecha) {
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }
}
