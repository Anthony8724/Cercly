import 'package:cloud_firestore/cloud_firestore.dart';

class PromocionModel {
  const PromocionModel({
    required this.id,
    required this.establecimientoId,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.radioAlertaMetros,
    required this.activa,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String establecimientoId;
  final String titulo;
  final String descripcion;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int radioAlertaMetros;
  final bool activa;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  bool get estaVigente {
    final ahora = DateTime.now();

    return activa && !ahora.isBefore(fechaInicio) && !ahora.isAfter(fechaFin);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'establecimientoId': establecimientoId,
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
      'radioAlertaMetros': radioAlertaMetros,
      'activa': activa,
      'creadoEn': creadoEn == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(creadoEn!),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  factory PromocionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data();

    if (datos == null) {
      throw StateError('La promoción ${documento.id} no contiene datos.');
    }

    return PromocionModel(
      id: documento.id,
      establecimientoId: datos['establecimientoId'] as String,
      titulo: datos['titulo'] as String,
      descripcion: datos['descripcion'] as String,
      fechaInicio: (datos['fechaInicio'] as Timestamp).toDate(),
      fechaFin: (datos['fechaFin'] as Timestamp).toDate(),
      radioAlertaMetros: datos['radioAlertaMetros'] as int,
      activa: datos['activa'] as bool,
      creadoEn: (datos['creadoEn'] as Timestamp?)?.toDate(),
      actualizadoEn: (datos['actualizadoEn'] as Timestamp?)?.toDate(),
    );
  }
}
