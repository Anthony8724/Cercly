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
              titulo: (r['titulo'] ?? r['nombre'] ?? 'Promoción')
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
  final items = <DetalleEstadisticaItem>[];

  for (final r in rows) {
  String titulo = (r['mensaje'] ?? '').toString().trim();
  String subtitulo = (r['tipo'] ?? 'Pendiente de revisión')
      .toString()
      .trim();

  final estId = r['establecimiento_id']?.toString();
  if (estId != null && estId.isNotEmpty) {
  try {
  final est = await _supabase
      .from('establecimientos')
      .select('nombre')
      .eq('id', estId)
      .maybeSingle();
  final nombreEst = est?['nombre']?.toString().trim();
  if (nombreEst != null && nombreEst.isNotEmpty) {
  titulo = nombreEst;
  }
  } catch (_) {}
  }

  final solId = r['solicitante_id']?.toString();
  if (solId != null && solId.isNotEmpty) {
  try {
  final usr = await _supabase
      .from('usuarios')
      .select('nombre')
      .eq('id', solId)
      .maybeSingle();
  final nombreUsr = usr?['nombre']?.toString().trim();
  if (nombreUsr != null && nombreUsr.isNotEmpty) {
  subtitulo = 'Solicitante: $nombreUsr';
  }
  } catch (_) {}
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
  try {
  final rpc = await _supabase.rpc(
  'admin_usuarios_activos_detalle',
  params: {'p_dias_activos': diasActivos},
  );
  if (rpc is List) {
  return rpc.map((fila) {
  final map = Map<String, dynamic>.from(fila as Map);
  return DetalleEstadisticaItem(
  titulo: (map['nombre'] ?? 'Sin nombre').toString(),
  subtitulo: _etiquetaRol(map['rol']?.toString()),
  estado: 'Activo',
  );
  }).toList();
  }
  } on PostgrestException catch (e) {
  if (e.code != 'PGRST202') rethrow;
  }

  final corte = DateTime.now()
      .subtract(Duration(days: diasActivos))
      .toUtc()
      .toIso8601String();
  final rows = await _supabase
      .from('usuarios')
      .select('id, nombre, rol')
      .gte('creado_en', corte)
      .order('nombre', ascending: true);

  return (rows as List)
      .map(
  (r) => DetalleEstadisticaItem(
  titulo: (r['nombre'] ?? 'Sin nombre').toString(),
  subtitulo: _etiquetaRol(r['rol']?.toString()),
  estado: 'Activo',
  ),
  )
      .toList();
  }

  String _etiquetaRol(String? rol) => switch (rol) {
  'propietario' => 'Propietario',
  'administrador' => 'Administrador',
  _ => 'Usuario',
  };

  static String _fechaIso(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year.toString().padLeft(4, '0')}-$mes-$dia';
  }

  /// Mensaje legible para mostrar en pantalla.
  static String mensajeError(Object error) {
  if (error is PostgrestException) {
  if (error.code == '42501') {
  return 'No tienes permisos de administrador para ver estas '
  'estadísticas.';
  }
  if (error.code == 'PGRST202') {
  return 'Las estadísticas todavía no están disponibles en este '
  'entorno (falta aplicar la migración).';
  }
  return 'No se pudieron cargar las estadísticas.';
  }
  if (error is FormatException) {
  return 'La respuesta de estadísticas no tiene el formato esperado.';
  }
  return 'No se pudieron cargar las estadísticas. Revisa tu conexión.';
  }
}