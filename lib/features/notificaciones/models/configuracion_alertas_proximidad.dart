enum FrecuenciaAlertasProximidad {
  baja(3, 'Bajo'),
  normal(6, 'Normal'),
  alta(10, 'Alto');

  const FrecuenciaAlertasProximidad(this.maximoPorDia, this.etiqueta);

  final int maximoPorDia;
  final String etiqueta;
}

class HorarioDescanso {
  const HorarioDescanso({required this.inicioMinutos, required this.finMinutos})
    : assert(inicioMinutos >= 0 && inicioMinutos < 1440),
      assert(finMinutos >= 0 && finMinutos < 1440),
      assert(inicioMinutos != finMinutos);

  final int inicioMinutos;
  final int finMinutos;

  bool contiene(DateTime instante) {
    final local = instante.toLocal();
    final minuto = local.hour * 60 + local.minute;
    if (inicioMinutos < finMinutos) {
      return minuto >= inicioMinutos && minuto < finMinutos;
    }
    return minuto >= inicioMinutos || minuto < finMinutos;
  }
}

class ConfiguracionAlertasProximidad {
  const ConfiguracionAlertasProximidad({
    this.activadas = false,
    this.radioMetros = radioPredeterminadoMetros,
    this.frecuencia = FrecuenciaAlertasProximidad.normal,
    this.horarioDescanso,
  });

  static const int radioPredeterminadoMetros = 1500;
  static const List<int> radiosDisponiblesMetros = [
    1000,
    1500,
    3000,
    5000,
    10000,
  ];

  final bool activadas;
  final int radioMetros;
  final FrecuenciaAlertasProximidad frecuencia;
  final HorarioDescanso? horarioDescanso;

  ConfiguracionAlertasProximidad copiarCon({
    bool? activadas,
    int? radioMetros,
    FrecuenciaAlertasProximidad? frecuencia,
    HorarioDescanso? horarioDescanso,
    bool quitarHorarioDescanso = false,
  }) {
    return ConfiguracionAlertasProximidad(
      activadas: activadas ?? this.activadas,
      radioMetros: radioMetros ?? this.radioMetros,
      frecuencia: frecuencia ?? this.frecuencia,
      horarioDescanso: quitarHorarioDescanso
          ? null
          : horarioDescanso ?? this.horarioDescanso,
    );
  }
}
