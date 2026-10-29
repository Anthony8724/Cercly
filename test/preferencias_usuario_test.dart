import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/categorias/models/categoria_model.dart';
import 'package:cercly/features/categorias/models/subcategoria_model.dart';
import 'package:cercly/features/categorias/services/categoria_publica_service.dart';
import 'package:cercly/features/preferencias/models/preferencias_usuario.dart';
import 'package:cercly/features/preferencias/screens/mis_preferencias_screen.dart';
import 'package:cercly/features/preferencias/services/preferencias_usuario_service.dart';
import 'package:cercly/features/preferencias/services/recomendador_establecimientos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _category = CategoriaPublicaModel(
  id: 'cat-favorita',
  nombre: 'Cafeterías',
  slug: 'cafeterias',
  icono: 'coffee',
);
const _other = CategoriaPublicaModel(
  id: 'cat-otra',
  nombre: 'Parques',
  slug: 'parques',
  icono: 'park',
);

EstablecimientoPublicoModel _place(
  String id,
  CategoriaPublicaModel category,
  double distance, {
  bool promo = false,
}) => EstablecimientoPublicoModel(
  id: id,
  nombre: id,
  descripcion: '',
  direccion: '',
  latitud: 0,
  longitud: 0,
  telefonoPublico: '',
  zonaHoraria: 'America/Guayaquil',
  categoria: category,
  promociones: promo
      ? [
          PromocionPublicaModel(
            id: 'promo-$id',
            titulo: 'Promo',
            descripcion: '',
            fechaInicio: DateTime.now().subtract(const Duration(hours: 1)),
            fechaFin: DateTime.now().add(const Duration(hours: 1)),
            radioAlertaMetros: 100,
          ),
        ]
      : const [],
  distanciaMetros: distance,
);

class _Remote implements PreferenciasRemotas {
  PreferenciasUsuario? value;
  bool offline = false;
  bool conflict = false;

  @override
  Future<PreferenciasUsuario?> cargar(String usuarioId) async => value;

  @override
  Future<int> guardar(String usuarioId, PreferenciasUsuario preferences) async {
    if (conflict) throw const PreferenciasConflictException();
    if (offline) throw Exception('offline');
    final revision = preferences.revision + 1;
    value = preferences.copyWith(
      revision: revision,
      pendienteSincronizar: false,
    );
    return revision;
  }
}

class _Categories implements CategoriaPublicaRepository {
  @override
  Future<List<CategoriaModel>> listarCategorias() async => [
    CategoriaModel(
      id: 'cat-favorita',
      nombre: 'Cafeterías',
      slug: 'cafeterias',
      icono: 'coffee',
      activa: true,
      orden: 1,
    ),
  ];

  @override
  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recomienda categoría, cercanía y promoción sin duplicados', () {
    final places = [
      _place('cerca', _category, 100),
      _place('lejos', _category, 950),
      _place('promo', _other, 50, promo: true),
      _place('fuera', _category, 1500),
      _place('cerca', _category, 100),
    ];
    final result = const RecomendadorEstablecimientos().recomendar(
      establecimientos: places,
      preferencias: const PreferenciasUsuario(
        categoriasIds: {'cat-favorita'},
        radioMetros: 1000,
        priorizarPromociones: true,
      ),
      latitud: 0,
      longitud: 0,
    );
    expect(result.map((item) => item.id), ['cerca', 'lejos', 'promo']);
  });

  test('sin ubicación no bloquea recomendaciones por categoría', () {
    final result = const RecomendadorEstablecimientos().recomendar(
      establecimientos: [_place('local', _category, 30000)],
      preferencias: const PreferenciasUsuario(
        categoriasIds: {'cat-favorita'},
        radioMetros: 1000,
      ),
    );
    expect(result.map((item) => item.id), ['local']);
  });

  test(
    'lectura local y sincronización pendiente preservan los cambios',
    () async {
      SharedPreferences.setMockInitialValues({});
      final remote = _Remote()..offline = true;
      final service = PreferenciasUsuarioService(
        remote: remote,
        usuarioIdProvider: () => 'user-1',
      );
      final savedLocally = await service.guardar(
        const PreferenciasUsuario(
          categoriasIds: {'cat-favorita'},
          radioMetros: 3000,
        ),
      );
      expect(savedLocally.pendienteSincronizar, isTrue);
      expect((await service.cargar()).categoriasIds, {'cat-favorita'});

      remote.offline = false;
      final synced = await service.sincronizarPendientes();
      expect(synced?.pendienteSincronizar, isFalse);
      expect(remote.value?.categoriasIds, {'cat-favorita'});
      expect(remote.value?.radioMetros, 3000);
    },
  );

  test('conflicto remoto no se reemplaza automáticamente', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _Remote()..offline = true;
    final service = PreferenciasUsuarioService(
      remote: remote,
      usuarioIdProvider: () => 'user-2',
    );
    await service.guardar(
      const PreferenciasUsuario(categoriasIds: {'cat-local'}),
    );
    remote.offline = false;
    remote.conflict = true;
    await expectLater(
      service.sincronizarPendientes(),
      throwsA(isA<PreferenciasConflictException>()),
    );
    expect((await service.cargar()).categoriasIds, {'cat-local'});
  });

  testWidgets(
    'selecciona, guarda y restablece preferencias desde la pantalla',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final remote = _Remote();
      final service = PreferenciasUsuarioService(
        remote: remote,
        usuarioIdProvider: () => 'user-ui',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MisPreferenciasScreen(
            service: service,
            categorias: _Categories(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('preferencia-categoria-cat-favorita')),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const Key('preferencia-categoria-cat-favorita')),
            )
            .selected,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('preferencia-radio-3000')),
        100,
      );
      await tester.tap(find.byKey(const Key('preferencia-radio-3000')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('preferencia-radio-3000')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('preferir-promociones')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('guardar-preferencias')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guardar-preferencias')));
      await tester.pumpAndSettle();
      expect(remote.value?.categoriasIds, {'cat-favorita'});
      expect(remote.value?.radioMetros, 3000);
      expect(remote.value?.priorizarPromociones, isTrue);
      await tester.scrollUntilVisible(
        find.byKey(const Key('estado-preferencias')),
        -200,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('Tus preferencias están guardadas'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('restablecer-preferencias')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restablecer-preferencias')));
      await tester.pumpAndSettle();
      expect(remote.value?.categoriasIds, isEmpty);
      expect(remote.value?.radioMetros, 5000);
      expect(remote.value?.priorizarPromociones, isFalse);
    },
  );

  testWidgets(
    'muestra el estado de sincronización pendiente al guardar offline',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final remote = _Remote()..offline = true;
      final service = PreferenciasUsuarioService(
        remote: remote,
        usuarioIdProvider: () => 'user-offline-ui',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MisPreferenciasScreen(
            service: service,
            categorias: _Categories(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('preferencia-radio-10000')),
        100,
      );
      await tester.tap(find.byKey(const Key('preferencia-radio-10000')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('estado-preferencias')),
        -200,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('Tienes cambios sin guardar'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('guardar-preferencias')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guardar-preferencias')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('estado-preferencias')),
        -200,
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        find.text('Guardadas en este dispositivo · pendientes de sincronizar'),
        findsOneWidget,
      );
      expect((await service.cargar()).radioMetros, 10000);
    },
  );

  testWidgets('mantiene visible el conflicto y ofrece escoger el servidor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final remote = _Remote()..conflict = true;
    final service = PreferenciasUsuarioService(
      remote: remote,
      usuarioIdProvider: () => 'user-conflict-ui',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MisPreferenciasScreen(
          service: service,
          categorias: _Categories(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('preferencia-radio-1000')),
      100,
    );
    await tester.tap(find.byKey(const Key('preferencia-radio-1000')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('lista-mis-preferencias')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar-preferencias')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('lista-mis-preferencias')),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cambiaron en otro dispositivo'),
      findsOneWidget,
    );
    expect(find.text('Usar versión del servidor'), findsOneWidget);
  });
}
