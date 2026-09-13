import 'turno_horario.dart';

class EstablecimientoModel {
  EstablecimientoModel({
    required this.id,
    required this.propietarioId,
    required this.nombre,
    required this.descripcion,
    required this.categoriaId,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.telefonoPublico,
    required Map<String, List<TurnoHorario>> horario,
    required this.zonaHoraria,
    this.estado = 'pendiente',
  }) : horario = Map.unmodifiable({
         for (final entry in horario.entries)
           entry.key: List<TurnoHorario>.unmodifiable(entry.value),
       }) {
    if (propietarioId.trim().isEmpty ||
        nombre.trim().length < 2 ||
        categoriaId.trim().isEmpty ||
        direccion.trim().isEmpty ||
        zonaHoraria.trim().isEmpty) {
      throw ArgumentError('Faltan datos obligatorios del establecimiento.');
    }

    if (latitud < -90 || latitud > 90) {
      throw ArgumentError('La latitud debe estar entre -90 y 90.');
    }

    if (longitud < -180 || longitud > 180) {
      throw ArgumentError('La longitud debe estar entre -180 y 180.');
    }

    if (horario.length != diasSemana.length ||
        !diasSemana.every(horario.containsKey)) {
      throw ArgumentError('El horario debe incluir los siete días.');
    }
  }

  static const List<String> diasSemana = [
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
  final double latitud;
  final double longitud;
  final String telefonoPublico;
  final Map<String, List<TurnoHorario>> horario;
  final String zonaHoraria;
  final String estado;

  Map<String, dynamic> toSupabaseParaCrear() {
    return {
      'propietario_id': propietarioId,
      'categoria_id': categoriaId,
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'direccion': direccion.trim(),
      'latitud': latitud,
      'longitud': longitud,
      'telefono_publico': telefonoPublico.trim(),
      'zona_horaria': zonaHoraria.trim(),
      'estado': 'pendiente',
    };
  }

  List<Map<String, dynamic>> horariosParaSupabase(String establecimientoId) {
    final filas = <Map<String, dynamic>>[];

    for (var indice = 0; indice < diasSemana.length; indice++) {
      final dia = diasSemana[indice];
      final turnos = horario[dia] ?? const <TurnoHorario>[];

      for (final turno in turnos) {
        filas.add({
          'establecimiento_id': establecimientoId,
          'dia_semana': indice + 1,
          'apertura_minutos': turno.aperturaMinutos,
          'cierre_minutos': turno.cierreMinutos,
          'cierra_al_dia_siguiente': turno.cierraAlDiaSiguiente,
        });
      }
    }

    return filas;
  }

  factory EstablecimientoModel.fromSupabase(
    Map<String, dynamic> datos, {
    Map<String, List<TurnoHorario>>? horario,
  }) {
    return EstablecimientoModel(
      id: datos['id'] as String,
      propietarioId: datos['propietario_id'] as String,
      nombre: datos['nombre'] as String,
      descripcion: datos['descripcion'] as String? ?? '',
      categoriaId: datos['categoria_id'] as String,
      direccion: datos['direccion'] as String,
      latitud: (datos['latitud'] as num).toDouble(),
      longitud: (datos['longitud'] as num).toDouble(),
      telefonoPublico: datos['telefono_publico'] as String? ?? '',
      horario: horario ?? {for (final dia in diasSemana) dia: <TurnoHorario>[]},
      zonaHoraria: datos['zona_horaria'] as String? ?? 'America/Guayaquil',
      estado: datos['estado'] as String? ?? 'pendiente',
    );
  }
}
