import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/establecimientos/models/turno_horario.dart';
import 'package:cercly/features/explorar/models/ruta_model.dart';
import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/screens/detalle_establecimiento_screen.dart';
import 'package:cercly/features/explorar/services/mapas_externos_service.dart';
import 'package:cercly/features/explorar/services/ruta_service.dart';
import 'package:cercly/features/explorar/services/ubicacion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cafe = EstablecimientoPublicoModel(
  id: 'cafe-1',
  nombre: 'Café Carchi',
  descripcion: 'Cafetería',
  direccion: 'Tulcán',
  latitud: 0.815,
  longitud: -77.720,
  telefonoPublico: '',
  zonaHoraria: 'America/Guayaquil',
  categoria: CategoriaPublicaModel(
    id: 'cat',
    nombre: 'Cafetería',
    slug: 'cafe',
    icono: 'coffee',
  ),
  promociones: [],
);

class _UbicacionFalsa implements UbicacionService {
  _UbicacionFalsa(this.estado);
  final EstadoUbicacion estado;
  int llamadas = 0;
  bool? solicitoPermiso;

  @override
  Future<ResultadoUbicacion> obtenerUbicacion({
    bool solicitarPermiso = false,
  }) async {
    llamadas++;
    solicitoPermiso = solicitarPermiso;
    return ResultadoUbicacion(
      estado: estado,
      ubicacion: estado == EstadoUbicacion.disponible
          ? const UbicacionUsuario(latitud: 0.8116, longitud: -77.7172)
          : null,
    );
  }

  @override
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  }) async => estado;
  @override
  Future<bool> abrirAjustesUbicacion() async => true;
  @override
  Future<bool> abrirAjustesAplicacion() async => true;
}

class _RutaFalsa implements RutaService {
  int llamadas = 0;
  @override
  Future<RutaModel> calcularRuta({
    required LatLng origen,
    required LatLng destino,
    PerfilRuta perfil = PerfilRuta.aPie,
  }) async {
    llamadas++;
    return RutaModel(
      puntos: [origen, destino],
      distanciaMetros: 620,
      duracionSegundos: 480,
    );
  }
}

Future<void> _montar(
  WidgetTester tester, {
  required _UbicacionFalsa ubicacion,
  required _RutaFalsa ruta,
  required MapasExternosService mapas,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DetalleEstablecimientoScreen(
        establecimiento: _cafe,
        ubicacionService: ubicacion,
        rutaService: ruta,
        mapasService: mapas,
        mostrarTilesRuta: false,
        cargarHorario: (_) async => <String, List<TurnoHorario>>{},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final consentimiento in [false, true]) {
    for (final estado in [
      EstadoUbicacion.disponible,
      EstadoUbicacion.permisoDenegado,
    ]) {
      testWidgets(
        'Play comparte solo destino: consentimiento $consentimiento y $estado',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'cercly_uso_ubicacion_cercania_aceptado': consentimiento,
          });
          final ubicacion = _UbicacionFalsa(estado);
          final ruta = _RutaFalsa();
          final enlaces = <Uri>[];
          final mapas = MapasExternosService(
            abrirUri: (uri) async {
              enlaces.add(uri);
              return true;
            },
          );
          await _montar(tester, ubicacion: ubicacion, ruta: ruta, mapas: mapas);
          await tester.tap(find.byKey(const Key('boton-como-llegar')));
          await tester.pumpAndSettle();
          expect(enlaces, isEmpty);
          expect(ubicacion.llamadas, 0);
          expect(ruta.llamadas, 0);
          await tester.tap(find.byKey(const Key('mapas-externos-confirmar')));
          await tester.pumpAndSettle();
          expect(enlaces, hasLength(1));
          expect(enlaces.single.host, 'www.google.com');
          expect(enlaces.single.queryParameters, {
            'api': '1',
            'destination': '0.815,-77.72',
          });
          expect(enlaces.single.toString(), isNot(contains('0.8116')));
          expect(find.byKey(const Key('pantalla-ruta')), findsNothing);
          expect(ubicacion.llamadas, 0);
          expect(ruta.llamadas, 0);
        },
      );
    }
  }
  testWidgets('cancelar no abre mapas ni consulta ubicación o rutas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cercly_uso_ubicacion_cercania_aceptado': true,
    });
    final ubicacion = _UbicacionFalsa(EstadoUbicacion.disponible);
    final ruta = _RutaFalsa();
    var llamadas = 0;
    await _montar(
      tester,
      ubicacion: ubicacion,
      ruta: ruta,
      mapas: MapasExternosService(
        abrirUri: (_) async {
          llamadas++;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('boton-como-llegar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mapas-externos-cancelar')));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
    expect(ubicacion.llamadas, 0);
    expect(ruta.llamadas, 0);
  });
  testWidgets(
    'fallo de apertura no activa fallback interno y permite reintento',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ubicacion = _UbicacionFalsa(EstadoUbicacion.disponible);
      final ruta = _RutaFalsa();
      await _montar(
        tester,
        ubicacion: ubicacion,
        ruta: ruta,
        mapas: MapasExternosService(
          abrirUri: (_) async => throw StateError('sin handler'),
        ),
      );
      for (var intento = 0; intento < 2; intento++) {
        await tester.tap(find.byKey(const Key('boton-como-llegar')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mapas-externos-confirmar')));
        await tester.pumpAndSettle();
      }
      expect(
        find.text('No se pudo abrir Google Maps. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(ubicacion.llamadas, 0);
      expect(ruta.llamadas, 0);
    },
  );
}
