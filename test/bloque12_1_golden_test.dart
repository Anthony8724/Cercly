import 'package:cercly/features/auth/screens/mi_cuenta_screen.dart';
import 'package:cercly/features/categorias/models/categoria_model.dart';
import 'package:cercly/features/categorias/models/subcategoria_model.dart';
import 'package:cercly/features/categorias/services/categoria_publica_service.dart';
import 'package:cercly/features/preferencias/models/preferencias_usuario.dart';
import 'package:cercly/features/preferencias/screens/mis_preferencias_screen.dart';
import 'package:cercly/features/preferencias/services/preferencias_usuario_service.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Remote implements PreferenciasRemotas {
  PreferenciasUsuario? value = const PreferenciasUsuario(
    categoriasIds: {'cat-cafe'},
    radioMetros: 3000,
    priorizarPromociones: true,
  );

  @override
  Future<PreferenciasUsuario?> cargar(String usuarioId) async => value;

  @override
  Future<int> guardar(
    String usuarioId,
    PreferenciasUsuario preferencias,
  ) async {
    value = preferencias;
    return preferencias.revision + 1;
  }
}

class _Categories implements CategoriaPublicaRepository {
  @override
  Future<List<CategoriaModel>> listarCategorias() async => [
    CategoriaModel(
      id: 'cat-cafe',
      nombre: 'Cafeterías',
      slug: 'cafeterias',
      icono: 'local_cafe',
      activa: true,
      orden: 1,
    ),
    CategoriaModel(
      id: 'cat-parques',
      nombre: 'Parques y espacios al aire libre',
      slug: 'parques',
      icono: 'park',
      activa: true,
      orden: 2,
    ),
    CategoriaModel(
      id: 'cat-tiendas',
      nombre: 'Tiendas',
      slug: 'tiendas',
      icono: 'storefront',
      activa: true,
      orden: 3,
    ),
  ];

  @override
  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async => const [];
}

Future<void> _loadFonts() async {
  await (FontLoader('Comfortaa')..addFont(
        rootBundle.load('assets/branding/sky/fonts/Comfortaa-Bold.otf'),
      ))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

ThemeData _goldenTheme() {
  final theme = skyTheme(SkyPalette.forEnvironment(SkyEnvironment.noche));
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Comfortaa'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Comfortaa'),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: theme.chipTheme.labelStyle?.copyWith(fontFamily: 'Comfortaa'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('golden de Mis preferencias', (tester) async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1180);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _goldenTheme(),
        home: MisPreferenciasScreen(
          service: PreferenciasUsuarioService(
            remote: _Remote(),
            usuarioIdProvider: () => 'golden-user',
          ),
          categorias: _Categories(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MisPreferenciasScreen),
      matchesGoldenFile('goldens/bloque12_1_mis_preferencias.png'),
    );
  });

  testWidgets('golden de Mi cuenta para usuario sin negocios', (tester) async {
    await _loadFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _goldenTheme(),
        home: MiCuentaScreen(
          correo: 'ana@cercly.app',
          cerrarSesion: () async {},
          tieneNegocios: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MiCuentaScreen),
      matchesGoldenFile('goldens/bloque12_1_mi_cuenta.png'),
    );
  });
}
