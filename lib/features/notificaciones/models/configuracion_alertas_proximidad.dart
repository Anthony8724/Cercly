class ConfiguracionAlertasProximidad {
  const ConfiguracionAlertasProximidad({
    this.activadas = false,
    this.radioMetros = radioPredeterminadoMetros,
  });

  static const int radioPredeterminadoMetros = 5000;
  static const List<int> radiosDisponiblesMetros = [1000, 3000, 5000, 10000];

  final bool activadas;
  final int radioMetros;

  ConfiguracionAlertasProximidad copiarCon({
    bool? activadas,
    int? radioMetros,
  }) {
    return ConfiguracionAlertasProximidad(
      activadas: activadas ?? this.activadas,
      radioMetros: radioMetros ?? this.radioMetros,
    );
  }
}
