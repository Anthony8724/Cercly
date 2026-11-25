/// Modelos de las estadísticas agregadas del panel de administración.
///
/// Los datos vienen de las funciones RPC `admin_estadisticas_resumen` y
/// `admin_estadisticas_registros`. Si falta un campo, se lanza un
/// [FormatException]: nunca se rellena con ceros, para no mostrar como real
/// un dato que no llegó.
library;

int _entero(Map<String, dynamic> json, String clave) {
  final valor = json[clave];
  if (valor is num) return valor.toInt();
  throw FormatException(
    'Falta el campo numérico "$clave" en la respuesta de estadísticas.',
  );
}

Map<String, dynamic> _mapa(Map<String, dynamic> json, String clave) {
  final valor = json[clave];
  if (valor is Map) return Map<String, dynamic>.from(valor);
  throw FormatException(
    'Falta el bloque "$clave" en la respuesta de estadísticas.',
  );
}

class ConteoPorEstado {
  const ConteoPorEstado({
    required this.total,
    required this.pendientes,
    required this.aprobados,
    required this.rechazados,
  });

  final int total;
  final int pendientes;
  final int aprobados;
  final int rechazados;

  /// Los establecimientos usan "aprobados/rechazados" y las solicitudes
  /// "aprobadas/rechazadas"; por eso las claves son configurables.
  factory ConteoPorEstado.fromJson(
      Map<String, dynamic> json, {
        String claveAprobados = 'aprobados',
        String claveRechazados = 'rechazados',
      }) {
    return ConteoPorEstado(
      total: _entero(json, 'total'),
      pendientes: _entero(json, 'pendientes'),
      aprobados: _entero(json, claveAprobados),
      rechazados: _entero(json, claveRechazados),
    );
  }
}

class EstadisticasResumenModel {
  const EstadisticasResumenModel({
    required this.generadoEn,
    required this.usuariosTotal,
    required this.propietariosTotal,
    required this.usuariosNormalesTotal,
    required this.usuariosActivos,
    required this.diasUsuarioActivo,
    required this.establecimientos,
    required this.solicitudes,
    required this.promocionesTotal,
    required this.promocionesActivas,
  });

  final DateTime generadoEn;
  final int usuariosTotal;
  final int propietariosTotal;
  final int usuariosNormalesTotal;

  /// Usuarios con inicio de sesión en los últimos [diasUsuarioActivo] días.
  /// Es una medida aproximada: no refleja el uso real de la app.
  final int usuariosActivos;
  final int diasUsuarioActivo;

  final ConteoPorEstado establecimientos;
  final ConteoPorEstado solicitudes;
  final int promocionesTotal;
  final int promocionesActivas;

  factory EstadisticasResumenModel.fromJson(Map<String, dynamic> json) {
    final generado = json['generado_en'];
    if (generado is! String) {
      throw const FormatException(
        'Falta la fecha de generación en la respuesta de estadísticas.',
      );
    }
    final promociones = _mapa(json, 'promociones');

    return EstadisticasResumenModel(
      generadoEn: DateTime.parse(generado),
      usuariosTotal: _entero(json, 'usuarios_total'),
      propietariosTotal: _entero(json, 'propietarios_total'),
      usuariosNormalesTotal: _entero(json, 'usuarios_normales_total'),
      usuariosActivos: _entero(json, 'usuarios_activos'),
      diasUsuarioActivo: _entero(json, 'dias_usuario_activo'),
      establecimientos: ConteoPorEstado.fromJson(
        _mapa(json, 'establecimientos'),
      ),
      solicitudes: ConteoPorEstado.fromJson(
        _mapa(json, 'solicitudes'),
        claveAprobados: 'aprobadas',
        claveRechazados: 'rechazadas',
      ),
      promocionesTotal: _entero(promociones, 'total'),
      promocionesActivas: _entero(promociones, 'activas'),
    );
  }
}

class RegistroPeriodoModel {
  const RegistroPeriodoModel({
    required this.periodo,
    required this.tipoUsuario,
    required this.total,
  });

  /// Primer día del periodo (día, semana o mes según la granularidad).
  final DateTime periodo;

  /// `usuario` o `propietario`.
  final String tipoUsuario;
  final int total;

  factory RegistroPeriodoModel.fromJson(Map<String, dynamic> json) {
    final periodo = json['periodo'];
    final tipo = json['tipo_usuario'];
    if (periodo is! String || tipo is! String) {
      throw const FormatException(
        'Fila de registros con formato inesperado.',
      );
    }
    return RegistroPeriodoModel(
      periodo: DateTime.parse(periodo),
      tipoUsuario: tipo,
      total: _entero(json, 'total'),
    );
  }
}

enum TipoIndicadorAdmin {
  usuariosRegistrados,
  propietarios,
  usuariosActivos,
  solicitudesPendientes,
  establecimientos,
  promocionesActivas,
}

class DetalleEstadisticaItem {
  const DetalleEstadisticaItem({
    required this.titulo,
    this.subtitulo,
    this.estado,
  });

  final String titulo;
  final String? subtitulo;
  final String? estado;
}