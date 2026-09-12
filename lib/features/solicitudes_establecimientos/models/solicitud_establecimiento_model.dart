class SolicitudEstablecimientoModel {
  SolicitudEstablecimientoModel({
    required this.id,
    required this.solicitanteId,
    required this.establecimientoId,
    required this.mensaje,
    required this.tipo,
    this.estado = estadoPendiente,
    this.motivoRespuesta = '',
    this.creadoEn,
    this.actualizadoEn,
  }) {
    if (solicitanteId.trim().isEmpty) {
      throw ArgumentError('El solicitante es obligatorio.');
    }

    if (establecimientoId.trim().isEmpty) {
      throw ArgumentError('El establecimiento es obligatorio.');
    }

    if (!estadosPermitidos.contains(estado)) {
      throw ArgumentError('El estado de la solicitud no es válido.');
    }

    if (!tiposPermitidos.contains(tipo)) {
      throw ArgumentError('El tipo de solicitud no es válido.');
    }
  }

  static const String estadoPendiente = 'pendiente';
  static const String estadoAprobada = 'aprobada';
  static const String estadoRechazada = 'rechazada';

  static const Set<String> estadosPermitidos = {
    estadoPendiente,
    estadoAprobada,
    estadoRechazada,
  };

  static const String tipoReclamar = 'reclamar';
  static const String tipoAcceso = 'acceso';
  static const String tipoCorreccion = 'correccion';

  static const Set<String> tiposPermitidos = {
    tipoReclamar,
    tipoAcceso,
    tipoCorreccion,
  };

  final String id;
  final String solicitanteId;
  final String establecimientoId;
  final String mensaje;
  final String tipo;
  final String estado;
  final String motivoRespuesta;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get estaPendiente => estado == estadoPendiente;
  bool get fueAprobada => estado == estadoAprobada;
  bool get fueRechazada => estado == estadoRechazada;

  Map<String, dynamic> toSupabaseParaCrear() {
    return {
      'solicitante_id': solicitanteId,
      'establecimiento_id': establecimientoId,
      'mensaje': mensaje.trim(),
      'tipo': tipo,
    };
  }

  Map<String, dynamic> toSupabaseParaResponder() {
    return {'estado': estado, 'motivo_respuesta': motivoRespuesta.trim()};
  }

  factory SolicitudEstablecimientoModel.fromSupabase(
    Map<String, dynamic> datos,
  ) {
    return SolicitudEstablecimientoModel(
      id: datos['id'] as String,
      solicitanteId: datos['solicitante_id'] as String,
      establecimientoId: datos['establecimiento_id'] as String,
      mensaje: datos['mensaje'] as String? ?? '',
      tipo: datos['tipo'] as String? ?? tipoReclamar,
      estado: datos['estado'] as String? ?? estadoPendiente,
      motivoRespuesta: datos['motivo_respuesta'] as String? ?? '',
      creadoEn: datos['creado_en'] == null
          ? null
          : DateTime.parse(datos['creado_en'] as String).toLocal(),
      actualizadoEn: datos['actualizado_en'] == null
          ? null
          : DateTime.parse(datos['actualizado_en'] as String).toLocal(),
    );
  }
}
