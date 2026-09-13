import 'package:cercly/features/establecimientos/models/turno_horario.dart';
import 'package:cercly/features/establecimientos/services/estado_horario_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = EstadoHorarioService();

  Map<String, List<TurnoHorario>> horarioVacio() {
    return {
      'lunes': [],
      'martes': [],
      'miercoles': [],
      'jueves': [],
      'viernes': [],
      'sabado': [],
      'domingo': [],
    };
  }

  test('devuelve sinHorario cuando no existen turnos', () {
    final horario = horarioVacio();

    final estado = service.calcular(
      ahora: DateTime(2026, 9, 14, 10, 0),
      horario: horario,
    );

    expect(estado, EstadoHorario.sinHorario);
  });

  test('devuelve abierto dentro del horario normal', () {
    final horario = horarioVacio();
    horario['lunes'] = [
      TurnoHorario(aperturaMinutos: 8 * 60, cierreMinutos: 18 * 60),
    ];

    final estado = service.calcular(
      ahora: DateTime(2026, 9, 14, 10, 30),
      horario: horario,
    );

    expect(estado, EstadoHorario.abierto);
  });

  test('devuelve cerrado fuera del horario normal', () {
    final horario = horarioVacio();
    horario['lunes'] = [
      TurnoHorario(aperturaMinutos: 8 * 60, cierreMinutos: 18 * 60),
    ];

    final estado = service.calcular(
      ahora: DateTime(2026, 9, 14, 20, 0),
      horario: horario,
    );

    expect(estado, EstadoHorario.cerrado);
  });

  test('detecta negocio abierto después de medianoche', () {
    final horario = horarioVacio();
    horario['lunes'] = [
      TurnoHorario(
        aperturaMinutos: 20 * 60,
        cierreMinutos: 2 * 60,
        cierraAlDiaSiguiente: true,
      ),
    ];

    final estado = service.calcular(
      ahora: DateTime(2026, 9, 15, 1, 0),
      horario: horario,
    );

    expect(estado, EstadoHorario.abierto);
  });

  test('detecta cerrado después del cierre de madrugada', () {
    final horario = horarioVacio();
    horario['lunes'] = [
      TurnoHorario(
        aperturaMinutos: 20 * 60,
        cierreMinutos: 2 * 60,
        cierraAlDiaSiguiente: true,
      ),
    ];

    final estado = service.calcular(
      ahora: DateTime(2026, 9, 15, 3, 0),
      horario: horario,
    );

    expect(estado, EstadoHorario.cerrado);
  });

  test('soporta varios turnos en el mismo día', () {
    final horario = horarioVacio();
    horario['lunes'] = [
      TurnoHorario(aperturaMinutos: 8 * 60, cierreMinutos: 12 * 60),
      TurnoHorario(aperturaMinutos: 14 * 60, cierreMinutos: 18 * 60),
    ];

    final estado = service.calcular(
      ahora: DateTime(2026, 9, 14, 15, 0),
      horario: horario,
    );

    expect(estado, EstadoHorario.abierto);
  });
}
