import 'package:cercly/features/explorar/models/ruta_model.dart';
import 'package:cercly/features/explorar/screens/ruta_establecimiento_screen.dart';
import 'package:cercly/features/explorar/services/ruta_service.dart';
import 'package:cercly/features/explorar/services/ruta_service_linea_recta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _origen = LatLng(0.8116, -77.7172);
const _destino = LatLng(0.8150, -77.7200);

const _rutaEjemplo = RutaModel(
  puntos: [_origen, _destino],
  distanciaMetros: 850,
  duracionSegundos: 720,
);

/// Servicio falso: devuelve en orden las respuestas indicadas (una ruta o un
/// error) y repite la última cuando se agotan.
class _ServicioFalso implements RutaService {
  _ServicioFalso(this.respuestas);

  final List<Object> respuestas;
  int llamadas = 0;
  PerfilRuta? ultimoPerfil;

  @override
  Future<RutaModel> calcularRuta({
    required LatLng origen,
    required LatLng destino,
    PerfilRuta perfil = PerfilRuta.aPie,
  }) async {
    ultimoPerfil = perfil;
    final indice = llamadas < respuestas.length
        ? llamadas
        : respuestas.length - 1;
    llamadas++;
    final respuesta = respuestas[indice];
    if (respuesta is RutaException) throw respuesta;
    return respuesta as RutaModel;
  }
}

Future<void> _montar(
  WidgetTester tester,
  RutaService servicio, {
  Future<bool> Function()? abrirExterno,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RutaEstablecimientoScreen(
        nombreDestino: 'Panadería Sol',
        origen: _origen,
        destino: _destino,
        rutaService: servicio,
        abrirExterno: abrirExterno,
        mostrarTiles: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RutaEstablecimientoScreen', () {
    testWidgets('muestra distancia y tiempo de la ruta', (tester) async {
      await _montar(tester, _ServicioFalso([_rutaEjemplo]));

      expect(find.byKey(const Key('pantalla-ruta')), findsOneWidget);
      expect(find.text('850 m'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
      expect(find.byKey(const Key('ruta-error')), findsNothing);
    });

    testWidgets('muestra el error y permite reintentar', (tester) async {
      final servicio = _ServicioFalso([
        const RutaException(
          TipoErrorRuta.sinConexion,
          'No hay conexión para calcular la ruta.',
        ),
        _rutaEjemplo,
      ]);
      await _montar(tester, servicio);

      expect(find.byKey(const Key('ruta-error')), findsOneWidget);
      expect(find.text('No hay conexión para calcular la ruta.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ruta-reintentar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ruta-error')), findsNothing);
      expect(find.text('850 m'), findsOneWidget);
      expect(servicio.llamadas, 2);
    });

    testWidgets('sin ruta posible no ofrece reintentar', (tester) async {
      await _montar(
        tester,
        _ServicioFalso([
          const RutaException(
            TipoErrorRuta.sinRuta,
            'No encontramos una ruta hasta este lugar.',
          ),
        ]),
      );

      expect(find.byKey(const Key('ruta-error')), findsOneWidget);
      expect(find.byKey(const Key('ruta-reintentar')), findsNothing);
    });

    testWidgets('ofrece abrir en otra app solo si se le da la opción', (
      tester,
    ) async {
      var abierto = 0;
      await _montar(
        tester,
        _ServicioFalso([
          const RutaException(
            TipoErrorRuta.servicioNoDisponible,
            'El servicio de rutas no está disponible por ahora.',
          ),
        ]),
        abrirExterno: () async {
          abierto++;
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('ruta-abrir-externo')));
      await tester.pump();

      expect(abierto, 1);
    });

    testWidgets('no ofrece abrir en otra app si no se le da la opción', (
      tester,
    ) async {
      await _montar(
        tester,
        _ServicioFalso([
          const RutaException(
            TipoErrorRuta.servicioNoDisponible,
            'El servicio de rutas no está disponible por ahora.',
          ),
        ]),
      );

      expect(find.byKey(const Key('ruta-abrir-externo')), findsNothing);
    });

    testWidgets('cambiar a auto vuelve a calcular con ese perfil', (
      tester,
    ) async {
      final servicio = _ServicioFalso([_rutaEjemplo]);
      await _montar(tester, servicio);

      await tester.tap(find.text('En auto'));
      await tester.pumpAndSettle();

      expect(servicio.ultimoPerfil, PerfilRuta.auto);
      expect(servicio.llamadas, 2);
    });

    testWidgets('avisa cuando la ruta es de prueba en línea recta', (
      tester,
    ) async {
      await _montar(tester, const RutaServiceLineaRecta(retardo: Duration.zero));

      expect(find.byKey(const Key('ruta-aviso-simulada')), findsOneWidget);
    });
  });

  group('RutaServiceLineaRecta', () {
    const servicio = RutaServiceLineaRecta(retardo: Duration.zero);

    test('une origen y destino con una distancia razonable', () async {
      final ruta = await servicio.calcularRuta(
        origen: _origen,
        destino: _destino,
      );

      expect(ruta.puntos.first, _origen);
      expect(ruta.puntos.last, _destino);
      expect(ruta.puntos.length, greaterThan(2));
      expect(ruta.distanciaMetros, inInclusiveRange(400, 600));
    });

    test('en auto tarda menos que a pie', () async {
      final aPie = await servicio.calcularRuta(
        origen: _origen,
        destino: _destino,
      );
      final auto = await servicio.calcularRuta(
        origen: _origen,
        destino: _destino,
        perfil: PerfilRuta.auto,
      );

      expect(auto.duracionSegundos, lessThan(aPie.duracionSegundos));
    });
  });
}
