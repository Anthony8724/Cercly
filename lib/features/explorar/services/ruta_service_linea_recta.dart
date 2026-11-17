import 'package:latlong2/latlong.dart';

import '../models/ruta_model.dart';
import 'ruta_service.dart';

/// Servicio de rutas de PRUEBA: devuelve una línea recta entre origen y
/// destino, con distancia y tiempo estimados a velocidad constante.
///
/// NO es un recorrido real por calles. Existe para ver la pantalla de ruta
/// funcionando sin clave ni internet, y para pruebas. La pantalla lo avisa
/// al usuario. Se activa con `--dart-define=CERCLY_RUTAS_SIMULADAS=true`.
class RutaServiceLineaRecta implements RutaService {
  const RutaServiceLineaRecta({
    this.retardo = const Duration(milliseconds: 400),
  });

  /// Espera artificial para poder ver el estado de carga.
  final Duration retardo;

  static const int _tramos = 8;

  // Velocidades medias: 5 km/h a pie y 30 km/h en auto, en metros por segundo.
  static const double _velocidadAPie = 1.4;
  static const double _velocidadAuto = 8.3;

  @override
  Future<RutaModel> calcularRuta({
    required LatLng origen,
    required LatLng destino,
    PerfilRuta perfil = PerfilRuta.aPie,
  }) async {
    await Future<void>.delayed(retardo);

    final puntos = <LatLng>[
      for (var i = 0; i <= _tramos; i++)
        LatLng(
          origen.latitude + (destino.latitude - origen.latitude) * i / _tramos,
          origen.longitude +
              (destino.longitude - origen.longitude) * i / _tramos,
        ),
    ];

    final metros = const Distance().as(LengthUnit.Meter, origen, destino);
    final velocidad = perfil == PerfilRuta.aPie
        ? _velocidadAPie
        : _velocidadAuto;

    return RutaModel(
      puntos: puntos,
      distanciaMetros: metros,
      duracionSegundos: metros / velocidad,
    );
  }
}
