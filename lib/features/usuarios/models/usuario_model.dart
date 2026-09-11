import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioModel {
  const UsuarioModel({required this.uid, required this.nombre, this.creadoEn});

  final String uid;
  final String nombre;
  final DateTime? creadoEn;

  factory UsuarioModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data();

    if (datos == null) {
      throw StateError('El perfil del usuario no existe.');
    }

    final nombre = datos['nombre'];
    final fecha = datos['creadoEn'];

    if (nombre is! String) {
      throw const FormatException('El nombre del usuario no es válido.');
    }

    if (fecha != null && fecha is! Timestamp) {
      throw const FormatException('La fecha de creación no es válida.');
    }

    return UsuarioModel(
      uid: documento.id,
      nombre: nombre,
      creadoEn: fecha is Timestamp ? fecha.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestoreParaCrear() {
    return {'nombre': nombre.trim(), 'creadoEn': FieldValue.serverTimestamp()};
  }
}
