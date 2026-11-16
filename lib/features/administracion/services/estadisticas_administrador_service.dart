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
