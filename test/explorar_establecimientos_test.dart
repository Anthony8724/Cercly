import 'package:cercly/features/categorias/models/categoria_model.dart';
import 'package:cercly/features/categorias/models/subcategoria_model.dart';
import 'package:cercly/features/categorias/services/categoria_publica_service.dart';
import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';
import 'package:cercly/features/explorar/controllers/explorar_controller.dart';
import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/screens/detalle_establecimiento_screen.dart';
import 'package:cercly/features/explorar/screens/explorar_screen.dart';
import 'package:cercly/features/explorar/screens/mapa_establecimientos_screen.dart';
import 'package:cercly/features/explorar/services/mapas_externos_service.dart';
import 'package:cercly/features/explorar/services/ubicacion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const categoria = CategoriaPublicaModel(
  id: 'categoria-1',
  nombre: 'Comida y bebidas',
  slug: 'comida-bebidas',
  icono: 'restaurant',
);

EstablecimientoPublicoModel establecimiento({bool promocion = false}) {
  return EstablecimientoPublicoModel(
    id: 'establecimiento-1',
    nombre: 'Café Carchi',
    descripcion: 'Café local',
    direccion: 'Tulcán',
    latitud: 0.8117,
    longitud: -77.7171,
    telefonoPublico: '0999999999',
    zonaHoraria: 'America/Guayaquil',
    categoria: categoria,
    promociones: const [],
    distanciaMetros: 350,
    tienePromocionesRpc: promocion,
    ciudad: 'Tulcán',
    provincia: 'Carchi',
    paisCodigo: 'EC',
  );
}

class UbicacionFalsa implements UbicacionService {
  UbicacionFalsa(this.resultado);

  ResultadoUbicacion resultado;

  @override
  Future<bool> abrirAjustesAplicacion() async => true;

  @override
  Future<bool> abrirAjustesUbicacion() async => true;

  @override
  Future<ResultadoUbicacion> obtenerUbicacion() async => resultado;
}

class EstablecimientoServiceFalso implements EstablecimientoCercanoRepository {
  EstablecimientoServiceFalso({this.respuesta = const [], this.error});

  List<EstablecimientoPublicoModel> respuesta;
  Object? error;
  int? radioRecibido;
  String? categoriaRecibida;
  List<String>? subcategoriasRecibidas;
  bool? soloPromocionesRecibido;
  String? busquedaRecibida;

  @override
  Future<List<EstablecimientoPublicoModel>> buscarCercanos({
    required double latitud,
    required double longitud,
    int radioMetros = 5000,
    String? categoriaId,
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    String? busqueda,
    int limite = 20,
    int desplazamiento = 0,
  }) async {
    if (error != null) throw error!;
    radioRecibido = radioMetros;
    categoriaRecibida = categoriaId;
    subcategoriasRecibidas = subcategoriaIds;
    soloPromocionesRecibido = soloPromociones;
    busquedaRecibida = busqueda;
    return respuesta;
  }
}

class CategoriaServiceFalso implements CategoriaPublicaRepository {
  @override
  Future<List<CategoriaModel>> listarCategorias() async => [
    CategoriaModel(
      id: 'categoria-1',
      nombre: 'Comida y bebidas',
      slug: 'comida-bebidas',
      icono: 'restaurant',
      activa: true,
      orden: 1,
    ),
  ];

  @override
  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async {
    return const [
      SubcategoriaModel(
        id: 'subcategoria-1',
        categoriaId: 'categoria-1',
        nombre: 'Cafeterías',
        slug: 'cafeterias',
        icono: 'coffee',
        activa: true,
        orden: 1,
      ),
    ];
  }
}

ExplorarController crearController({
  EstablecimientoServiceFalso? establecimientos,
  ResultadoUbicacion resultadoUbicacion = const ResultadoUbicacion(
    estado: EstadoUbicacion.disponible,
    ubicacion: UbicacionUsuario(latitud: 0.8116, longitud: -77.7172),
  ),
}) {
  return ExplorarController(
    establecimientoService: establecimientos ?? EstablecimientoServiceFalso(),
    categoriaService: CategoriaServiceFalso(),
    ubicacionService: UbicacionFalsa(resultadoUbicacion),
  );
}

void main() {
  group('ExplorarController', () {
    test(
      'envía radio, categoría, subcategoría, promociones y búsqueda al servicio',
      () async {
        final servicio = EstablecimientoServiceFalso(
          respuesta: [establecimiento()],
        );
        final controller = crearController(establecimientos: servicio);

        await controller.solicitarUbicacion();
        await controller.cambiarRadio(2000);
        await controller.cambiarCategoria('categoria-1');
        await controller.cambiarSubcategoria('subcategoria-1');
        controller.busqueda = 'cafeteria';
        await controller.cambiarSoloPromociones(true);

        expect(servicio.radioRecibido, 2000);
        expect(servicio.categoriaRecibida, 'categoria-1');
        expect(servicio.subcategoriasRecibidas, ['subcategoria-1']);
        expect(servicio.soloPromocionesRecibido, isTrue);
        expect(servicio.busquedaRecibida, 'cafeteria');
        expect(controller.establecimientos, hasLength(1));
      },
    );

    test('aplica búsqueda después del debounce', () async {
      final servicio = EstablecimientoServiceFalso(
        respuesta: [establecimiento()],
      );
      final controller = crearController(establecimientos: servicio);
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );

      controller.cambiarBusqueda('Café');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(servicio.busquedaRecibida, 'Café');
    });

    test(
      'controla errores de consulta sin dejar la pantalla cargando',
      () async {
        final controller = crearController(
          establecimientos: EstablecimientoServiceFalso(
            error: Exception('sin conexión'),
          ),
        );

        await controller.solicitarUbicacion();

        expect(controller.cargandoResultados, isFalse);
        expect(controller.errorResultados, isNotNull);
      },
    );

    test('representa permiso denegado', () async {
      final controller = crearController(
        resultadoUbicacion: const ResultadoUbicacion(
          estado: EstadoUbicacion.permisoDenegado,
          mensaje: 'Permiso denegado',
        ),
      );

      await controller.solicitarUbicacion();

      expect(controller.estadoUbicacion, EstadoUbicacion.permisoDenegado);
      expect(controller.ubicacion, isNull);
    });

    test('representa servicio de ubicación desactivado', () async {
      final controller = crearController(
        resultadoUbicacion: const ResultadoUbicacion(
          estado: EstadoUbicacion.servicioDesactivado,
          mensaje: 'Ubicación desactivada',
        ),
      );

      await controller.solicitarUbicacion();

      expect(controller.estadoUbicacion, EstadoUbicacion.servicioDesactivado);
    });
  });

  group('Interfaz pública', () {
    testWidgets('muestra loading y sin resultados', (tester) async {
      final controller = crearController();
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );
      controller.cargandoResultados = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorarScreen(controller: controller)),
        ),
      );
      expect(find.byKey(const Key('estado-loading')), findsOneWidget);

      controller.cargandoResultados = false;
      controller.notifyListeners();
      await tester.pump();
      expect(find.byKey(const Key('estado-sin-resultados')), findsOneWidget);
    });

    testWidgets('muestra la barra de búsqueda y permite limpiarla', (
      tester,
    ) async {
      final controller = crearController();
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );
      controller.establecimientos = [establecimiento()];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorarScreen(controller: controller)),
        ),
      );

      final buscador = find.byKey(const Key('buscador-establecimientos'));
      expect(buscador, findsOneWidget);

      await tester.enterText(buscador, 'cafe');
      await tester.pump();
      expect(find.byKey(const Key('limpiar-busqueda')), findsOneWidget);

      await tester.tap(find.byKey(const Key('limpiar-busqueda')));
      await tester.pump();
      expect(controller.busqueda, isEmpty);
    });

    testWidgets('muestra error y permite reintentar', (tester) async {
      final controller = crearController();
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );
      controller.errorResultados = 'Error controlado';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorarScreen(controller: controller)),
        ),
      );

      expect(find.byKey(const Key('estado-error')), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('usa resultados del servicio y navega al detalle', (
      tester,
    ) async {
      final controller = crearController();
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );
      controller.establecimientos = [establecimiento()];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorarScreen(controller: controller)),
        ),
      );

      expect(find.text('Café Carchi'), findsOneWidget);
      expect(find.text('350 m'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('establecimiento-establecimiento-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detalle del establecimiento'), findsOneWidget);
    });

    testWidgets('muestra el indicador de promoción', (tester) async {
      final controller = crearController();
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );
      controller.establecimientos = [establecimiento(promocion: true)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorarScreen(controller: controller)),
        ),
      );

      expect(find.byKey(const Key('indicador-promocion')), findsOneWidget);
    });

    testWidgets('el mapa utiliza los establecimientos de la consulta', (
      tester,
    ) async {
      final controller = crearController();
      controller.estadoUbicacion = EstadoUbicacion.disponible;
      controller.ubicacion = const UbicacionUsuario(
        latitud: 0.8116,
        longitud: -77.7172,
      );
      controller.establecimientos = [establecimiento()];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapaEstablecimientosScreen(
              controller: controller,
              mostrarTiles: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('mapa-establecimientos')), findsOneWidget);
      expect(
        find.byKey(const Key('marcador-establecimiento-1')),
        findsOneWidget,
      );
    });

    testWidgets('Cómo llegar usa las coordenadas del establecimiento', (
      tester,
    ) async {
      Uri? uriAbierta;
      final mapas = MapasExternosService(
        abrirUri: (uri) async {
          uriAbierta = uri;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DetalleEstablecimientoScreen(
            establecimiento: establecimiento(),
            mapasService: mapas,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('boton-como-llegar')));
      await tester.pump();
      expect(uriAbierta.toString(), contains('0.8117'));
      expect(uriAbierta.toString(), contains('-77.7171'));
    });
  });
}
