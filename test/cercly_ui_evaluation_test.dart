import 'package:cercly/evaluation/cercly_ui_evaluation_app.dart';
import 'package:cercly/features/establecimientos/screens/registro_establecimiento_screen.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_service.dart';
import 'package:cercly/features/explorar/services/mapas_externos_service.dart';
import 'package:cercly/sky/sky_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences implements SkyPreferenceStore {
  @override
  Future<String?> getMode() async => null;

  @override
  Future<void> setMode(String value) async {}

  @override
  Future<bool?> getDecorationsEnabled() async => true;

  @override
  Future<void> setDecorationsEnabled(bool value) async {}
}

class _NoWriteRepository implements RegistroEstablecimientoRepository {
  int writes = 0;

  @override
  Future<List<Map<String, dynamic>>> listarCategoriasActivas() async => const [
    {'id': 'fake-category', 'nombre': 'Costurería'},
  ];

  @override
  Future<List<Map<String, dynamic>>> buscarCoincidenciasCercanas({
    required String nombre,
    required double latitud,
    required double longitud,
  }) async => const [];

  @override
  Future<String> crearSolicitudRegistro({
    required String nombre,
    required String categoriaId,
    required String descripcion,
    required String direccion,
    required String telefono,
    required double latitud,
    required double longitud,
    List<Map<String, dynamic>> horarios = const [],
  }) async {
    writes++;
    throw StateError('No se deben enviar escrituras durante la evaluación.');
  }
}

void main() {
  test(
    'Google Maps recibe el destino ficticio de la ficha seleccionada',
    () async {
      Uri? openedUri;
      final service = MapasExternosService(
        abrirUri: (uri) async {
          openedUri = uri;
          return true;
        },
      );

      final opened = await service.comoLlegar(
        latitud: 0.814,
        longitud: -77.716,
      );

      expect(opened, isTrue);
      expect(openedUri?.host, 'www.google.com');
      expect(openedUri?.path, '/maps/dir/');
      expect(openedUri?.queryParameters['destination'], '0.814,-77.716');
    },
  );

  testWidgets('la evaluación navega por Mi cuenta sin activar el envío', (
    tester,
  ) async {
    final sky = SkyController(store: _Preferences());
    await tester.pumpWidget(
      CerclyUiEvaluationApp(skyController: sky, mostrarTilesMapa: false),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SIN SUPABASE'), findsOneWidget);
    expect(find.text('Costurería Cercly Demo'), findsOneWidget);
    expect(find.text('Dobladillos de demostración'), findsOneWidget);
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mapa-establecimientos')), findsOneWidget);
    expect(
      find.byKey(const Key('atribucion-openstreetmap-explorar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('marcador-demo-costura-tulcan')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('tab-cuenta')).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('evaluation-reduced-motion')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('evaluation-reduced-motion')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('evaluation-reduced-motion')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('evaluation-open-account')));
    await tester.pumpAndSettle();
    expect(find.text('Mi cuenta'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('abrir-mis-negocios')));
    await tester.tap(find.byKey(const Key('abrir-mis-negocios')));
    await tester.pumpAndSettle();
    expect(find.text('Mis negocios'), findsOneWidget);

    await tester.tap(find.byKey(const Key('registrar-nuevo-establecimiento')));
    await tester.pumpAndSettle();
    expect(find.textContaining('se simula solo en la memoria'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('enviar-solicitud-establecimiento')),
    );
    expect(submit.onPressed, isNotNull);
    expect(find.text('Simular solicitud local'), findsOneWidget);
    sky.dispose();
  });

  testWidgets(
    'la evaluación permite seleccionar ubicación sin tiles ni guardar',
    (tester) async {
      final repository = _NoWriteRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RegistroEstablecimientoScreen(
            service: repository,
            soloEvaluacion: true,
            mostrarTiles: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Seleccionar en el mapa'));
      await tester.tap(find.text('Seleccionar en el mapa'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sin-punto-seleccionado')), findsOneWidget);
      expect(find.byKey(const Key('atribucion-openstreetmap')), findsOneWidget);
      await tester.drag(find.byType(FlutterMap), const Offset(28, 18));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coordenadas-seleccionadas')),
        findsOneWidget,
      );
      final beforeDrag = tester
          .widget<Text>(find.byKey(const Key('coordenadas-seleccionadas')))
          .data;
      await tester.drag(
        find.byKey(const Key('marcador-arrastrable')),
        const Offset(24, 12),
      );
      await tester.pumpAndSettle();
      final afterDrag = tester
          .widget<Text>(find.byKey(const Key('coordenadas-seleccionadas')))
          .data;
      expect(afterDrag, isNot(beforeDrag));
      await tester.tap(find.byKey(const Key('confirmar-ubicacion')));
      await tester.pumpAndSettle();

      expect(find.text('Ubicación seleccionada'), findsOneWidget);
      expect(repository.writes, 0);
    },
  );
}
