import 'dart:convert';

import 'package:cercly/features/explorar/models/ruta_model.dart';
import 'package:cercly/features/explorar/services/openrouteservice_ruta_service.dart';
import 'package:cercly/features/explorar/services/ruta_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const _origen = LatLng(0.8116, -77.7172);
const _destino = LatLng(0.8150, -77.7200);

final _cuerpoValido = jsonEncode({
  'features': [
    {
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-77.7172, 0.8116],
          [-77.7185, 0.8130],
          [-77.7200, 0.8150],
        ],
      },
      'properties': {
        'summary': {'distance': 523.4, 'duration': 380.2},
      },
    },
  ],
});

http.Response _json(String cuerpo, int estado) => http.Response(
  cuerpo,
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

OpenRouteServiceRutaService _servicio(
  MockClient cliente, {
  String apiKey = 'clave-de-prueba',
}) => OpenRouteServiceRutaService(
  cliente: cliente,
  apiKey: apiKey,
  baseUrl: 'https://rutas.ejemplo.test',
);

Matcher _errorDeTipo(TipoErrorRuta tipo) =>
    isA<RutaException>().having((e) => e.tipo, 'tipo', tipo);

void main() {
  group('OpenRouteServiceRutaService', () {
    test('interpreta una ruta válida y envía [longitud, latitud]', () async {
      final cliente = MockClient((peticion) async {
        expect(peticion.method, 'POST');
        expect(peticion.url.path, '/v2/directions/foot-walking/geojson');
        expect(peticion.headers['Authorization'], 'clave-de-prueba');
        final cuerpo = jsonDecode(peticion.body) as Map<String, dynamic>;
        expect(cuerpo['coordinates'][0], [-77.7172, 0.8116]);
        expect(cuerpo['coordinates'][1], [-77.7200, 0.8150]);
        return _json(_cuerpoValido, 200);
      });

      final ruta = await _servicio(cliente)
          .calcularRuta(origen: _origen, destino: _destino);

      expect(ruta.puntos, hasLength(3));
      expect(ruta.puntos.first, const LatLng(0.8116, -77.7172));
      expect(ruta.puntos.last, const LatLng(0.8150, -77.7200));
      expect(ruta.distanciaMetros, 523.4);
      expect(ruta.duracionSegundos, 380.2);
    });

    test('usa el perfil de auto cuando se pide', () async {
      final cliente = MockClient((peticion) async {
        expect(peticion.url.path, '/v2/directions/driving-car/geojson');
        return _json(_cuerpoValido, 200);
      });

      await _servicio(cliente).calcularRuta(
        origen: _origen,
        destino: _destino,
        perfil: PerfilRuta.auto,
      );
    });

    test('sin clave no llama al servicio', () async {
      var llamadas = 0;
      final cliente = MockClient((_) async {
        llamadas++;
        return _json(_cuerpoValido, 200);
      });

      await expectLater(
        _servicio(
          cliente,
          apiKey: '',
        ).calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.servicioNoConfigurado)),
      );
      expect(llamadas, 0);
    });

    test('cuota agotada (403 y 429)', () async {
      for (final estado in [403, 429]) {
        final cliente = MockClient((_) async => _json('{}', estado));
        await expectLater(
          _servicio(cliente).calcularRuta(origen: _origen, destino: _destino),
          throwsA(_errorDeTipo(TipoErrorRuta.cuotaAgotada)),
        );
      }
    });

    test('clave inválida (401)', () async {
      final cliente = MockClient((_) async => _json('{}', 401));
      await expectLater(
        _servicio(cliente).calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.servicioNoConfigurado)),
      );
    });

    test('sin ruta posible (404)', () async {
      final cliente = MockClient((_) async => _json('{}', 404));
      await expectLater(
        _servicio(cliente).calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.sinRuta)),
      );
    });

    test('servicio caído (500)', () async {
      final cliente = MockClient((_) async => _json('{}', 500));
      await expectLater(
        _servicio(cliente).calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.servicioNoDisponible)),
      );
    });

    test('sin conexión', () async {
      final cliente = MockClient(
        (_) async => throw http.ClientException('sin red'),
      );
      await expectLater(
        _servicio(cliente).calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.sinConexion)),
      );
    });

    test('tiempo agotado', () async {
      final cliente = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json(_cuerpoValido, 200);
      });
      final servicio = OpenRouteServiceRutaService(
        cliente: cliente,
        apiKey: 'clave-de-prueba',
        baseUrl: 'https://rutas.ejemplo.test',
        tiempoMaximo: const Duration(milliseconds: 20),
      );

      await expectLater(
        servicio.calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.tiempoAgotado)),
      );
    });

    test('respuesta con formato inesperado', () async {
      final cliente = MockClient((_) async => _json('{"features": []}', 200));
      await expectLater(
        _servicio(cliente).calcularRuta(origen: _origen, destino: _destino),
        throwsA(_errorDeTipo(TipoErrorRuta.respuestaInvalida)),
      );
    });
  });

  group('RutaModel', () {
    RutaModel ruta(double metros, double segundos) => RutaModel(
      puntos: const [_origen, _destino],
      distanciaMetros: metros,
      duracionSegundos: segundos,
    );

    test('formatea la distancia', () {
      expect(ruta(850, 0).distanciaTexto, '850 m');
      expect(ruta(2430, 0).distanciaTexto, '2,4 km');
    });

    test('formatea la duración', () {
      expect(ruta(0, 20).duracionTexto, 'menos de 1 min');
      expect(ruta(0, 720).duracionTexto, '12 min');
      expect(ruta(0, 3900).duracionTexto, '1 h 5 min');
      expect(ruta(0, 7200).duracionTexto, '2 h');
    });
  });
}
