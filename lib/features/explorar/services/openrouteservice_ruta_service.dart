import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/ruta_model.dart';
import 'ruta_service.dart';
import 'politica_rutas.dart';

/// Adaptador legado de protocolo ORS conservado para pruebas y migraciones.
/// En esta candidata, todo endpoint real está bloqueado por PoliticaRutas.
/// Los transportes inyectados a dominios reservados .test verifican el parser
/// sin transmitir a un proveedor. Una futura integración real debe pasar por
/// el servidor, mantener sus secretos allí y acreditar condiciones aplicables.
class OpenRouteServiceRutaService implements RutaService {
  OpenRouteServiceRutaService({
    http.Client? cliente,
    String? apiKey,
    String? baseUrl,
    this.tiempoMaximo = const Duration(seconds: 12),
  }) : _cliente = cliente ?? http.Client(),
       _clienteInyectado = cliente != null,
       _apiKey = apiKey ?? _claveDefecto,
       _baseUrl = baseUrl ?? _urlDefecto;

  static const String _claveDefecto = String.fromEnvironment('ORS_API_KEY');
  static const String _urlDefecto = String.fromEnvironment(
    'ORS_BASE_URL',
    defaultValue: 'https://api.heigit.org/openrouteservice',
  );

  final http.Client _cliente;
  final bool _clienteInyectado;
  final String _apiKey;
  final String _baseUrl;

  /// Tiempo máximo de espera de la respuesta.
  final Duration tiempoMaximo;

  @override
  Future<RutaModel> calcularRuta({
    required LatLng origen,
    required LatLng destino,
    PerfilRuta perfil = PerfilRuta.aPie,
  }) async {
    // El adaptador legado no puede enviar coordenadas a un proveedor real.
    // Solo los transportes inyectados a dominios reservados .test conservan
    // el recorrido de pruebas del protocolo, sin habilitar un endpoint público.
    final host = Uri.tryParse(_baseUrl)?.host ?? '';
    if (!_clienteInyectado || !host.endsWith('.test')) {
      PoliticaRutas.exigirProveedorAutorizado();
    }
    if (_apiKey.isEmpty) {
      throw const RutaException(
        TipoErrorRuta.servicioNoConfigurado,
        'El servicio de rutas no está configurado.',
      );
    }

    final uri = Uri.parse('$_baseUrl/v2/directions/${perfil.valorOrs}/geojson');

    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(
            uri,
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/geo+json, application/json',
            },
            // GeoJSON usa el orden [longitud, latitud].
            body: jsonEncode({
              'coordinates': [
                [origen.longitude, origen.latitude],
                [destino.longitude, destino.latitude],
              ],
            }),
          )
          .timeout(tiempoMaximo);
    } on TimeoutException {
      throw const RutaException(
        TipoErrorRuta.tiempoAgotado,
        'El servicio de rutas tardó demasiado en responder.',
      );
    } on http.ClientException {
      throw const RutaException(
        TipoErrorRuta.sinConexion,
        'No hay conexión para calcular la ruta.',
      );
    }

    switch (respuesta.statusCode) {
      case 200:
        return _interpretar(respuesta);
      case 401:
        throw const RutaException(
          TipoErrorRuta.servicioNoConfigurado,
          'El servicio de rutas no está configurado correctamente.',
        );
      case 403:
      case 429:
        throw const RutaException(
          TipoErrorRuta.cuotaAgotada,
          'El servicio de rutas está ocupado. Inténtalo más tarde.',
        );
      case 400:
      case 404:
        throw const RutaException(
          TipoErrorRuta.sinRuta,
          'No encontramos una ruta hasta este lugar.',
        );
      default:
        throw const RutaException(
          TipoErrorRuta.servicioNoDisponible,
          'El servicio de rutas no está disponible por ahora.',
        );
    }
  }

  RutaModel _interpretar(http.Response respuesta) {
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      final rasgo = (datos['features'] as List).first as Map<String, dynamic>;
      final coordenadas =
          (rasgo['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      final resumen =
          (rasgo['properties'] as Map<String, dynamic>)['summary']
              as Map<String, dynamic>;

      final puntos = coordenadas.map<LatLng>((par) {
        final valores = par as List;
        return LatLng(
          (valores[1] as num).toDouble(),
          (valores[0] as num).toDouble(),
        );
      }).toList();

      if (puntos.length < 2) {
        throw const FormatException('La ruta tiene menos de dos puntos.');
      }

      return RutaModel(
        puntos: puntos,
        distanciaMetros: (resumen['distance'] as num).toDouble(),
        duracionSegundos: (resumen['duration'] as num).toDouble(),
      );
    } catch (_) {
      throw const RutaException(
        TipoErrorRuta.respuestaInvalida,
        'No pudimos interpretar la ruta recibida.',
      );
    }
  }
}
