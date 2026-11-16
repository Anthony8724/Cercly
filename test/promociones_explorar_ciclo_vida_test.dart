import 'dart:async';

import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';
import 'package:cercly/features/categorias/models/categoria_model.dart';
import 'package:cercly/features/categorias/models/subcategoria_model.dart';
import 'package:cercly/features/categorias/services/categoria_publica_service.dart';
import 'package:cercly/features/explorar/controllers/explorar_controller.dart';
import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/screens/explorar_screen.dart';
import 'package:cercly/features/explorar/widgets/promociones_explorar.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PromocionDestacadaModel _promo(String titulo) {
  final ahora = DateTime.now();
  return PromocionDestacadaModel(
    id: titulo,
    establecimientoId: 'negocio-demo',
    establecimientoNombre: 'Negocio demostración',
    categoriaNombre: 'Comercios',
    titulo: titulo,
    descripcion: '',
    fechaInicio: ahora.subtract(const Duration(days: 1)),
    fechaFin: ahora.add(const Duration(days: 1)),
    radioAlertaMetros: 500,
    latitud: 0,
    longitud: 0,
  );
}

ThemeData get _tema => skyTheme(
  SkyPalette.forEnvironment(SkyEnvironment.dia)
      .copyWith(decorationsEnabled: false),
);

typedef _Cargar = Future<List<PromocionDestacadaModel>> Function();

Widget _widgetCarrusel({
  required _Cargar cargar,
  double? latitud,
  double? radio,
}) {
  return MaterialApp(
    theme: _tema,
    home: Scaffold(
      body: SingleChildScrollView(
        child: PromocionesExplorar(
          establecimientos: const [],
          onEstablecimiento: (_) {},
          onVerTodas: () {},
          cargarPromociones: cargar,
          latitudUsuario: latitud,
          longitudUsuario: latitud == null ? null : 0,
          radioMaximoMetros: radio,
        ),
      ),
    ),
  );
}

// No inicializar Supabase para una prueba de widgets. Inyectar repositorios
// deterministas para que el constructor de ExplorarController sea aislado.
class _EstablecimientosFalsos implements EstablecimientoCercanoRepository {
  const _EstablecimientosFalsos();

  @override
  Future<List<EstablecimientoPublicoModel>> listar({
    String? categoriaId,
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    String? busqueda,
    int limite = 20,
    int desplazamiento = 0,
  }) async => const [];

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
  }) async => const [];
}

class _CategoriasFalsas implements CategoriaPublicaRepository {
  const _CategoriasFalsas();

  @override
  Future<List<CategoriaModel>> listarCategorias() async => const [];

  @override
  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async => const [];
}

class _ControladorPrueba extends ExplorarController {
  _ControladorPrueba()
    : super(
        establecimientoService: const _EstablecimientosFalsos(),
        categoriaService: const _CategoriasFalsas(),
      );

  void establecerCarga(bool valor) {
    cargandoResultados = valor;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Explorar conserva carrusel durante búsqueda de establecimientos',
    (tester) async {
      final controlador = _ControladorPrueba();
      controlador.estadoUbicacion = EstadoUbicacion.disponible;
      controlador.ubicacion = const UbicacionUsuario(latitud: 0, longitud: 0);
      var consultas = 0;
      Future<List<PromocionDestacadaModel>> cargar() async {
        consultas++;
        return [_promo('Patrocinio estable')];
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: _tema,
          home: Scaffold(
            body: ExplorarScreen(
              controller: controlador,
              cargarPromociones: cargar,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(consultas, 1);
      expect(find.text('Patrocinio estable'), findsOneWidget);

      controlador.establecerCarga(true);
      await tester.pump();
      expect(consultas, 1);
      controlador.establecerCarga(false);
      await tester.pumpAndSettle();
      expect(consultas, 1);
      expect(find.text('Patrocinio estable'), findsOneWidget);

      // El gesto de refrescar sí debe volver a consultar destacadas.
      final indicador = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await indicador.onRefresh();
      await tester.pumpAndSettle();
      expect(consultas, 2);
      expect(find.text('Patrocinio estable'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      controlador.dispose();
    },
  );

  testWidgets('GPS rápido genera una sola consulta adicional', (tester) async {
    var consultas = 0;
    Future<List<PromocionDestacadaModel>> cargar() async {
      consultas++;
      return [_promo('Oferta')];
    }

    await tester.pumpWidget(
      _widgetCarrusel(cargar: cargar, latitud: 0, radio: 5000),
    );
    await tester.pumpAndSettle();
    expect(consultas, 1);

    await tester.pumpWidget(
      _widgetCarrusel(cargar: cargar, latitud: 0.01, radio: 5000),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(
      _widgetCarrusel(cargar: cargar, latitud: 0.02, radio: 5000),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(consultas, 1);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(consultas, 2);
  });

  testWidgets('descarta respuestas obsoletas y recarga al revocar GPS', (
    tester,
  ) async {
    final peticiones = <Completer<List<PromocionDestacadaModel>>>[];
    Future<List<PromocionDestacadaModel>> cargar() {
      final completer = Completer<List<PromocionDestacadaModel>>();
      peticiones.add(completer);
      return completer.future;
    }

    await tester.pumpWidget(
      _widgetCarrusel(cargar: cargar, latitud: 0, radio: 5000),
    );
    expect(peticiones, hasLength(1));
    await tester.pumpWidget(
      _widgetCarrusel(cargar: cargar, latitud: 0.01, radio: 5000),
    );
    peticiones[0].complete([_promo('Obsoleta')]);
    await tester.pump();
    expect(find.text('Obsoleta'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(peticiones, hasLength(2));
    peticiones[1].complete([_promo('Vigente')]);
    await tester.pumpAndSettle();
    expect(find.text('Vigente'), findsOneWidget);

    await tester.pumpWidget(_widgetCarrusel(cargar: cargar));
    await tester.pump();
    expect(peticiones, hasLength(3));
    peticiones[2].complete([_promo('Sin GPS')]);
    await tester.pumpAndSettle();
    expect(find.text('Sin GPS'), findsOneWidget);
  });
}
