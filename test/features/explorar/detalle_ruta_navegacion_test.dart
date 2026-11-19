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
  testWidgets('Cómo llegar abre la pantalla de rutas con consentimiento', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cercly_uso_ubicacion_cercania_aceptado': true,
    });
    final ubicacion = _UbicacionFalsa(EstadoUbicacion.disponible);
    final ruta = _RutaFalsa();
    final mapas = MapasExternosService(abrirUri: (_) async => true);
    await _montar(tester, ubicacion: ubicacion, ruta: ruta, mapas: mapas);

    await tester.tap(find.byKey(const Key('boton-como-llegar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-privacidad-ruta')), findsOneWidget);
    expect(ubicacion.llamadas, 0);
    expect(ruta.llamadas, 0);

    await tester.tap(find.byKey(const Key('ruta-privacidad-confirmar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-privacidad-ruta')), findsNothing);
    expect(find.byKey(const Key('pantalla-ruta')), findsOneWidget);
    expect(find.text('620 m'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
    expect(ubicacion.llamadas, 1);
    expect(ubicacion.solicitoPermiso, isFalse);
    expect(ruta.llamadas, 1);
  });

  testWidgets('Cancelar aviso no consulta GPS ni solicita ruta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cercly_uso_ubicacion_cercania_aceptado': true,
    });
    final ubicacion = _UbicacionFalsa(EstadoUbicacion.disponible);
    final ruta = _RutaFalsa();
    var externas = 0;
    final mapas = MapasExternosService(
      abrirUri: (_) async {
        externas++;
        return true;
      },
    );
    await _montar(tester, ubicacion: ubicacion, ruta: ruta, mapas: mapas);

    await tester.tap(find.byKey(const Key('boton-como-llegar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-privacidad-ruta')), findsOneWidget);
    expect(ubicacion.llamadas, 0);
    expect(ruta.llamadas, 0);

    await tester.tap(find.byKey(const Key('ruta-privacidad-cancelar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aviso-privacidad-ruta')), findsNothing);
    expect(find.byKey(const Key('pantalla-ruta')), findsNothing);
    expect(ubicacion.llamadas, 0);
    expect(ruta.llamadas, 0);
    expect(externas, 0);
  });

  testWidgets('Sin consentimiento abre Google Maps y no consulta GPS', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ubicacion = _UbicacionFalsa(EstadoUbicacion.disponible);
    final ruta = _RutaFalsa();
    Uri? enlace;
    final mapas = MapasExternosService(
      abrirUri: (uri) async {
        enlace = uri;
        return true;
      },
    );
    await _montar(tester, ubicacion: ubicacion, ruta: ruta, mapas: mapas);

    await tester.tap(find.byKey(const Key('boton-como-llegar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pantalla-ruta')), findsNothing);
    expect(ubicacion.llamadas, 0);
    expect(ruta.llamadas, 0);
    expect(enlace?.queryParameters['destination'], '0.815,-77.72');
  });

  testWidgets('Con permiso denegado no solicita GPS y ofrece mapa externo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cercly_uso_ubicacion_cercania_aceptado': true,
    });
    final ubicacion = _UbicacionFalsa(EstadoUbicacion.permisoDenegado);
    final ruta = _RutaFalsa();
    Uri? enlace;
    final mapas = MapasExternosService(
      abrirUri: (uri) async {
        enlace = uri;
        return true;
      },
    );
    await _montar(tester, ubicacion: ubicacion, ruta: ruta, mapas: mapas);

    await tester.tap(find.byKey(const Key('boton-como-llegar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-privacidad-ruta')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ruta-privacidad-confirmar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pantalla-ruta')), findsNothing);
    expect(ubicacion.solicitoPermiso, isFalse);
    expect(ruta.llamadas, 0);
    expect(enlace, isNotNull);
  });
}
