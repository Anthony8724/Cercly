class CategoriaPublicaModel {
  const CategoriaPublicaModel({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.icono,
  });

  final String id;
  final String nombre;
  final String slug;
  final String icono;

  factory CategoriaPublicaModel.fromSupabase(Map<String, dynamic> datos) {
    return CategoriaPublicaModel(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String,
      slug: datos['slug'] as String? ?? '',
      icono: datos['icono'] as String? ?? '',
    );
  }
}

class PromocionPublicaModel {
  const PromocionPublicaModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.radioAlertaMetros,
    this.imagenRutaStorage,
    this.urlImagen,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String? imagenRutaStorage;
  final String? urlImagen;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int radioAlertaMetros;

  bool get estaVigente {
    final ahora = DateTime.now();

    return !ahora.isBefore(fechaInicio) && !ahora.isAfter(fechaFin);
  }

  PromocionPublicaModel copiarConUrl(String? nuevaUrl) {
    return PromocionPublicaModel(
      id: id,
      titulo: titulo,
      descripcion: descripcion,
      imagenRutaStorage: imagenRutaStorage,
      urlImagen: nuevaUrl,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      radioAlertaMetros: radioAlertaMetros,
    );
  }

  factory PromocionPublicaModel.fromSupabase(Map<String, dynamic> datos) {
    return PromocionPublicaModel(
      id: datos['id'] as String,
      titulo: datos['titulo'] as String,
      descripcion: datos['descripcion'] as String? ?? '',
      imagenRutaStorage: datos['imagen_ruta_storage'] as String?,
      fechaInicio: DateTime.parse(datos['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(datos['fecha_fin'] as String).toLocal(),
      radioAlertaMetros: datos['radio_alerta_metros'] as int? ?? 100,
    );
  }
}

class EstablecimientoPublicoModel {
  const EstablecimientoPublicoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.telefonoPublico,
    required this.zonaHoraria,
    required this.categoria,
    required this.promociones,
    this.ciudad,
    this.provincia,
    this.paisCodigo,
    this.rutaFotoPortada,
    this.urlFotoPortada,
    this.distanciaMetros,
    this.tienePromocionesRpc,
    this.estadoHorario,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String direccion;
  final double latitud;
  final double longitud;
  final String telefonoPublico;
  final String zonaHoraria;
  final CategoriaPublicaModel categoria;
  final String? ciudad;
  final String? provincia;
  final String? paisCodigo;
  final String? rutaFotoPortada;
  final String? urlFotoPortada;
  final List<PromocionPublicaModel> promociones;
  final double? distanciaMetros;
  final bool? tienePromocionesRpc;
  final String? estadoHorario;

  String get categoriaId => categoria.id;

  bool get tienePromociones =>
      tienePromocionesRpc ?? promociones.isNotEmpty;

  String get distanciaFormateada {
    final distancia = distanciaMetros;

    if (distancia == null) {
      return '';
    }

    if (distancia < 1000) {
      return '${distancia.round()} m';
    }

    return '${(distancia / 1000).toStringAsFixed(1)} km';
  }

  EstablecimientoPublicoModel copiarCon({
    String? rutaFotoPortada,
    String? urlFotoPortada,
    List<PromocionPublicaModel>? promociones,
    double? distanciaMetros,
    bool? tienePromocionesRpc,
    String? estadoHorario,
  }) {
    return EstablecimientoPublicoModel(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      direccion: direccion,
      latitud: latitud,
      longitud: longitud,
      telefonoPublico: telefonoPublico,
      zonaHoraria: zonaHoraria,
      categoria: categoria,
      ciudad: ciudad,
      provincia: provincia,
      paisCodigo: paisCodigo,
      rutaFotoPortada: rutaFotoPortada ?? this.rutaFotoPortada,
      urlFotoPortada: urlFotoPortada ?? this.urlFotoPortada,
      promociones: promociones ?? this.promociones,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      tienePromocionesRpc:
          tienePromocionesRpc ?? this.tienePromocionesRpc,
      estadoHorario: estadoHorario ?? this.estadoHorario,
    );
  }

  factory EstablecimientoPublicoModel.fromSupabase(Map<String, dynamic> datos) {
    final categoriaDatos = Map<String, dynamic>.from(
      datos['categorias'] as Map,
    );

    final fotosDatos = List<Map<String, dynamic>>.from(
      datos['fotos_establecimiento'] as List? ?? const <Map<String, dynamic>>[],
    );

    final promocionesDatos = List<Map<String, dynamic>>.from(
      datos['promociones'] as List? ?? const <Map<String, dynamic>>[],
    );

    fotosDatos.sort((primera, segunda) {
      final primeraEsPortada = primera['es_portada'] as bool? ?? false;
      final segundaEsPortada = segunda['es_portada'] as bool? ?? false;

      if (primeraEsPortada != segundaEsPortada) {
        return primeraEsPortada ? -1 : 1;
      }

      final primerOrden = primera['orden'] as int? ?? 0;
      final segundoOrden = segunda['orden'] as int? ?? 0;

      return primerOrden.compareTo(segundoOrden);
    });

    final rutaPortada = fotosDatos.isEmpty
        ? null
        : fotosDatos.first['ruta_storage'] as String?;

    return EstablecimientoPublicoModel(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String,
      descripcion: datos['descripcion'] as String? ?? '',
      direccion: datos['direccion'] as String,
      latitud: (datos['latitud'] as num).toDouble(),
      longitud: (datos['longitud'] as num).toDouble(),
      telefonoPublico: datos['telefono_publico'] as String? ?? '',
      zonaHoraria: datos['zona_horaria'] as String? ?? 'America/Guayaquil',
      categoria: CategoriaPublicaModel.fromSupabase(categoriaDatos),
      ciudad: datos['ciudad'] as String?,
      provincia: datos['provincia'] as String?,
      paisCodigo: datos['pais_codigo'] as String?,
      rutaFotoPortada: rutaPortada,
      promociones: promocionesDatos
          .map(PromocionPublicaModel.fromSupabase)
          .where((promocion) => promocion.estaVigente)
          .toList(growable: false),
    );
  }
}
