class PreferenciasUsuario {
  const PreferenciasUsuario({
    this.categoriasIds = const <String>{},
    this.radioMetros = 5000,
    this.priorizarPromociones = false,
    this.revision = 0,
    this.pendienteSincronizar = false,
  });

  static const radiosPermitidos = <int?>[1000, 3000, 5000, 10000, null];
  final Set<String> categoriasIds;
  final int? radioMetros;
  final bool priorizarPromociones;
  final int revision;
  final bool pendienteSincronizar;

  PreferenciasUsuario copyWith({
    Set<String>? categoriasIds,
    int? radioMetros,
    bool limpiarRadio = false,
    bool? priorizarPromociones,
    int? revision,
    bool? pendienteSincronizar,
  }) => PreferenciasUsuario(
    categoriasIds: categoriasIds ?? this.categoriasIds,
    radioMetros: limpiarRadio ? null : radioMetros ?? this.radioMetros,
    priorizarPromociones: priorizarPromociones ?? this.priorizarPromociones,
    revision: revision ?? this.revision,
    pendienteSincronizar: pendienteSincronizar ?? this.pendienteSincronizar,
  );

  Map<String, Object?> toJson() => {
    'categorias_ids': categoriasIds.toList()..sort(),
    'radio_metros': radioMetros,
    'priorizar_promociones': priorizarPromociones,
    'revision': revision,
    'pendiente_sincronizar': pendienteSincronizar,
  };

  factory PreferenciasUsuario.fromJson(Map<String, dynamic> json) {
    final radio = json['radio_metros'];
    final revis = json['revision'];
    return PreferenciasUsuario(
      categoriasIds: Set<String>.from(
        json['categorias_ids'] as List? ?? const [],
      ),
      radioMetros: radio is num ? radio.toInt() : null,
      priorizarPromociones: json['priorizar_promociones'] as bool? ?? false,
      revision: revis is num ? revis.toInt() : 0,
      pendienteSincronizar: json['pendiente_sincronizar'] as bool? ?? false,
    );
  }
}
