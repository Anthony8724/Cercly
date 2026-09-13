enum EstadoUbicacion {
  inicial,
  cargando,
  disponible,
  servicioDesactivado,
  permisoDenegado,
  permisoDenegadoPermanentemente,
  error,
}

class UbicacionUsuario {
  const UbicacionUsuario({required this.latitud, required this.longitud});

  final double latitud;
  final double longitud;
}

class ResultadoUbicacion {
  const ResultadoUbicacion({
    required this.estado,
    this.ubicacion,
    this.mensaje,
  });

  final EstadoUbicacion estado;
  final UbicacionUsuario? ubicacion;
  final String? mensaje;
}
