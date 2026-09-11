import 'package:cloud_firestore/cloud_firestore.dart';

import 'turno_horario.dart';

class EstablecimientoModel {
  EstablecimientoModel({
    required this.id,
    required this.propietarioId,
    required this.nombre,
    required this.descripcion,
    required this.categoriaId,
    required this.direccion,
    required this.ubicacion,
    required this.telefonoPublico,
    required Map<String, List<TurnoHorario>> horario,
    required this.zonaHoraria,
  }) : horario = Map.unmodifiable({
         for (final entry in horario.entries)
           entry.key: List<TurnoHorario>.unmodifiable(entry.value),
       }) {
    if (propietarioId.trim().isEmpty ||
        nombre.trim().isEmpty ||
        categoriaId.trim().isEmpty ||
        direccion.trim().isEmpty ||
        zonaHoraria.trim().isEmpty) {
      throw ArgumentError('Faltan datos obligatorios del establecimiento.');
    }

    if (horario.length != diasSemana.length ||
        !diasSemana.every(horario.containsKey)) {
      throw ArgumentError('El horario debe incluir los siete días.');
    }
  }

  static const diasSemana = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  final String id;
  final String propietarioId;
  final String nombre;
  final String descripcion;
  final String categoriaId;
  final String direccion;
  final GeoPoint ubicacion;
  final String telefonoPublico;
  final Map<String, List<TurnoHorario>> horario;
  final String zonaHoraria;

  /// Solo para crear un documento nuevo, no para editar uno existente.
  Map<String, dynamic> toFirestoreParaCrear() {
    return {
      'propietarioId': propietarioId,
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'categoriaId': categoriaId,
      'direccion': direccion.trim(),
      'ubicacion': ubicacion,
      'telefonoPublico': telefonoPublico.trim(),
      'horario': {
        for (final dia in diasSemana)
          dia: horario[dia]!.map((turno) => turno.toMap()).toList(),
      },
      'zonaHoraria': zonaHoraria,
      'estado': 'pendiente',
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }
}
