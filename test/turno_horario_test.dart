import 'package:cercly/features/establecimientos/models/turno_horario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permite un turno de 08:00 a 18:00', () {
    final turno = TurnoHorario(aperturaMinutos: 480, cierreMinutos: 1080);

    expect(turno.cierraAlDiaSiguiente, isFalse);
  });

  test('permite un turno que termina al día siguiente', () {
    final turno = TurnoHorario(
      aperturaMinutos: 1080,
      cierreMinutos: 120,
      cierraAlDiaSiguiente: true,
    );

    expect(turno.cierraAlDiaSiguiente, isTrue);
  });

  test('rechaza un cierre anterior sin indicar el día siguiente', () {
    expect(
      () => TurnoHorario(aperturaMinutos: 1080, cierreMinutos: 120),
      throwsArgumentError,
    );
  });

  test('rechaza horas fuera del rango válido', () {
    expect(
      () => TurnoHorario(aperturaMinutos: -1, cierreMinutos: 1080),
      throwsArgumentError,
    );
  });

  test('conserva los datos al convertir a mapa y recuperarlos', () {
    final original = TurnoHorario(aperturaMinutos: 480, cierreMinutos: 720);

    final recuperado = TurnoHorario.fromMap(original.toMap());

    expect(recuperado.aperturaMinutos, original.aperturaMinutos);
    expect(recuperado.cierreMinutos, original.cierreMinutos);
    expect(recuperado.cierraAlDiaSiguiente, original.cierraAlDiaSiguiente);
  });
}
