class TurnoHorario {
  TurnoHorario({
    required this.aperturaMinutos,
    required this.cierreMinutos,
    this.cierraAlDiaSiguiente = false,
  }) {
    if (aperturaMinutos < 0 || aperturaMinutos > 1439) {
      throw ArgumentError('La hora de apertura no es válida.');
    }

    if (cierreMinutos < 0 || cierreMinutos > 1439) {
      throw ArgumentError('La hora de cierre no es válida.');
    }

    final duracion =
        cierreMinutos + (cierraAlDiaSiguiente ? 1440 : 0) - aperturaMinutos;

    if (duracion <= 0 || duracion > 1440) {
      throw ArgumentError('El turno debe durar entre 1 minuto y 24 horas.');
    }
  }

  final int aperturaMinutos;
  final int cierreMinutos;
  final bool cierraAlDiaSiguiente;

  Map<String, dynamic> toMap() {
    return {
      'aperturaMinutos': aperturaMinutos,
      'cierreMinutos': cierreMinutos,
      'cierraAlDiaSiguiente': cierraAlDiaSiguiente,
    };
  }

  factory TurnoHorario.fromMap(Map<String, dynamic> datos) {
    final apertura = datos['aperturaMinutos'];
    final cierre = datos['cierreMinutos'];
    final diaSiguiente = datos['cierraAlDiaSiguiente'];

    if (apertura is! int || cierre is! int || diaSiguiente is! bool) {
      throw const FormatException('El turno tiene campos inválidos.');
    }

    return TurnoHorario(
      aperturaMinutos: apertura,
      cierreMinutos: cierre,
      cierraAlDiaSiguiente: diaSiguiente,
    );
  }
}
