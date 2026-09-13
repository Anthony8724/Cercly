import '../models/turno_horario.dart';

enum EstadoHorario { abierto, cerrado, sinHorario }

class EstadoHorarioService {
  const EstadoHorarioService();

  EstadoHorario calcular({
    required DateTime ahora,
    required Map<String, List<TurnoHorario>> horario,
  }) {
    if (horario.values.every((turnos) => turnos.isEmpty)) {
      return EstadoHorario.sinHorario;
    }

    const dias = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];

    final indiceDiaActual = ahora.weekday - 1;
    final diaActual = dias[indiceDiaActual];
    final diaAnterior = dias[(indiceDiaActual - 1 + 7) % 7];
    final minutosActuales = ahora.hour * 60 + ahora.minute;

    final turnosHoy = horario[diaActual] ?? const <TurnoHorario>[];

    for (final turno in turnosHoy) {
      if (!turno.cierraAlDiaSiguiente) {
        if (minutosActuales >= turno.aperturaMinutos &&
            minutosActuales < turno.cierreMinutos) {
          return EstadoHorario.abierto;
        }
      } else if (minutosActuales >= turno.aperturaMinutos) {
        return EstadoHorario.abierto;
      }
    }

    final turnosAyer = horario[diaAnterior] ?? const <TurnoHorario>[];

    for (final turno in turnosAyer) {
      if (turno.cierraAlDiaSiguiente &&
          minutosActuales < turno.cierreMinutos) {
        return EstadoHorario.abierto;
      }
    }

    return EstadoHorario.cerrado;
  }
}
