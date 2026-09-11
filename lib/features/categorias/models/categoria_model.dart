import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriaModel {
  CategoriaModel({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.activa,
    required this.orden,
  }) {
    if (nombre.trim().isEmpty) {
      throw ArgumentError('El nombre de la categoría es obligatorio.');
    }

    if (icono.trim().isEmpty) {
      throw ArgumentError('El icono de la categoría es obligatorio.');
    }

    if (orden < 0) {
      throw ArgumentError('El orden no puede ser negativo.');
    }
  }

  final String id;
  final String nombre;
  final String icono;
  final bool activa;
  final int orden;

  Map<String, dynamic> toFirestoreParaCrear() {
    return {
      'nombre': nombre.trim(),
      'icono': icono.trim(),
      'activa': activa,
      'orden': orden,
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  factory CategoriaModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data();

    if (datos == null) {
      throw StateError('La categoría no existe.');
    }

    return CategoriaModel(
      id: documento.id,
      nombre: datos['nombre'] as String,
      icono: datos['icono'] as String,
      activa: datos['activa'] as bool,
      orden: datos['orden'] as int,
    );
  }
}
