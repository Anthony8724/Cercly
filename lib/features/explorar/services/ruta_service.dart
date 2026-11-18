import 'package:latlong2/latlong.dart';

import '../models/ruta_model.dart';

enum PerfilRuta {
  aPie('foot-walking'),
  auto('driving-car');

  const PerfilRuta(this.valorOrs);

  /// Nombre del perfil en OpenRouteService.
  final String valorOrs;
}

enum TipoErrorRuta {
  /// Falta la clave o es inválida.
  servicioNoConfigurado,
  sinConexion,
  tiempoAgotado,

  /// No hay ruta posible entre los dos puntos (por ejemplo, lejos de una vía).
  sinRuta,

  /// Se agotó la cuota diaria o por minuto del servicio.
  cuotaAgotada,
  respuestaInvalida,
  servicioNoDisponible,
}

class RutaException implements Exception {
  const RutaException(this.tipo, this.mensaje);

  final TipoErrorRuta tipo;

  /// Mensaje legible para mostrar al usuario.
  final String mensaje;

  @override
  String toString() => 'RutaException(${tipo.name}): $mensaje';
}

/// Calcula rutas entre dos puntos. La app depende de esta interfaz y no de un
/// proveedor concreto, para poder cambiar de servicio sin tocar las pantallas.
abstract interface class RutaService {
  Future<RutaModel> calcularRuta({
    required LatLng origen,
    required LatLng destino,
    PerfilRuta perfil = PerfilRuta.aPie,
  });
}
