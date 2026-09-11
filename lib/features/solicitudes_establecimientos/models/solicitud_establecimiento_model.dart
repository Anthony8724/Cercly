import 'package:cloud_firestore/cloud_firestore.dart';

class SolicitudEstablecimientoModel {
  const SolicitudEstablecimientoModel({
    required this.id,
    required this.solicitanteId,
    required this.establecimientoId,
    required this.mensaje,
    required this.estado,
    this.motivoRespuesta = '',
    this.creadoEn,
    this.actualizadoEn,
  });

  static const String estadoPendiente = 'pendiente';
  static const String estadoAprobada = 'aprobada';
  static const String estadoRechazada = 'rechazada';

  final String id;
  final String solicitanteId;
  final String establecimientoId;
  final String mensaje;
  final String estado;
  final String motivoRespuesta;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get estaPendiente => estado == estadoPendiente;
  bool get fueAprobada => estado == estadoAprobada;
  bool get fueRechazada => estado == estadoRechazada;

  Map<String, dynamic> toFirestore() {
    return {
      'solicitanteId': solicitanteId,
      'establecimientoId': establecimientoId,
      'mensaje': mensaje.trim(),
      'estado': estado,
      'motivoRespuesta': motivoRespuesta.trim(),
      'creadoEn': creadoEn == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(creadoEn!),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  factory SolicitudEstablecimientoModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data();

    if (datos == null) {
      throw StateError('La solicitud ${documento.id} no contiene datos.');
    }

    return SolicitudEstablecimientoModel(
      id: documento.id,
      solicitanteId: datos['solicitanteId'] as String,
      establecimientoId: datos['establecimientoId'] as String,
      mensaje: datos['mensaje'] as String,
      estado: datos['estado'] as String,
      motivoRespuesta: datos['motivoRespuesta'] as String? ?? '',
      creadoEn: (datos['creadoEn'] as Timestamp?)?.toDate(),
      actualizadoEn: (datos['actualizadoEn'] as Timestamp?)?.toDate(),
    );
  }
}
