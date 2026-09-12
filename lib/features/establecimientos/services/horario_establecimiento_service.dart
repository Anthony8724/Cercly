import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_model.dart';
import '../models/turno_horario.dart';

class HorarioEstablecimientoService {
  HorarioEstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<Map<String, List<TurnoHorario>>> obtener(
    String establecimientoId,
  ) async {
    final respuesta = await _supabase
        .from('horarios_establecimiento')
        .select(
          'dia_semana, apertura_minutos, cierre_minutos, '
          'cierra_al_dia_siguiente',
        )
        .eq('establecimiento_id', establecimientoId)
        .order('dia_semana')
        .order('apertura_minutos');

    final horario = {
      for (final dia in EstablecimientoModel.diasSemana) dia: <TurnoHorario>[],
    };

    for (final fila in respuesta) {
      final numeroDia = fila['dia_semana'] as int;

      if (numeroDia < 1 || numeroDia > EstablecimientoModel.diasSemana.length) {
        continue;
      }

      final nombreDia = EstablecimientoModel.diasSemana[numeroDia - 1];

      horario[nombreDia]!.add(
        TurnoHorario(
          aperturaMinutos: fila['apertura_minutos'] as int,
          cierreMinutos: fila['cierre_minutos'] as int,
          cierraAlDiaSiguiente:
              fila['cierra_al_dia_siguiente'] as bool? ?? false,
        ),
      );
    }

    return horario;
  }

  Future<void> guardar({
    required String establecimientoId,
    required Map<String, List<TurnoHorario>> horario,
  }) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final establecimiento = await _supabase
        .from('establecimientos')
        .select('id')
        .eq('id', establecimientoId)
        .eq('propietario_id', usuario.id)
        .maybeSingle();

    if (establecimiento == null) {
      throw StateError('No tienes permiso para modificar estos horarios.');
    }

    if (horario.length != EstablecimientoModel.diasSemana.length ||
        !EstablecimientoModel.diasSemana.every(horario.containsKey)) {
      throw ArgumentError('El horario debe incluir los siete días.');
    }

    final filas = <Map<String, dynamic>>[];

    for (
      var indice = 0;
      indice < EstablecimientoModel.diasSemana.length;
      indice++
    ) {
      final dia = EstablecimientoModel.diasSemana[indice];
      final turnos = horario[dia] ?? <TurnoHorario>[];

      for (final turno in turnos) {
        filas.add({
          'dia_semana': indice + 1,
          'apertura_minutos': turno.aperturaMinutos,
          'cierre_minutos': turno.cierreMinutos,
          'cierra_al_dia_siguiente': turno.cierraAlDiaSiguiente,
        });
      }
    }

    await _supabase.rpc(
      'reemplazar_horarios_establecimiento',
      params: {'p_establecimiento_id': establecimientoId, 'p_horarios': filas},
    );
  }
}
