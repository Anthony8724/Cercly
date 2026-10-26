import 'dart:io';
import 'dart:ui' as ui;

import 'package:cercly/features/auth/screens/acceso_publico_screen.dart';
import 'package:cercly/features/auth/screens/login_screen.dart';
import 'package:cercly/features/auth/screens/mi_cuenta_screen.dart';
import 'package:cercly/features/auth/screens/seleccion_tipo_cuenta_screen.dart';
import 'package:cercly/features/explorar/widgets/cabecera_explorar.dart';
import 'package:cercly/features/explorar/screens/explorar_screen.dart';
import 'package:cercly/features/explorar/screens/mapa_establecimientos_screen.dart';
import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/explorar_establecimientos_test.dart' as fixtures;

void main() {
  final folder = Directory('design/cercly-sky/capturas');
  folder.createSync(recursive: true);

  Future<void> loadFont(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  setUpAll(() async {
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ??
        '/home/Anthony/development/flutter';
    final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
    await loadFont('Roboto', '$materialFonts/Roboto-Regular.ttf');
    await loadFont('Roboto', '$materialFonts/Roboto-Bold.ttf');
    await loadFont('MaterialIcons', '$materialFonts/MaterialIcons-Regular.otf');
    await loadFont('Comfortaa', 'assets/branding/sky/fonts/Comfortaa-Bold.otf');
  });

  final screens = <String, Widget>{
    'bienvenida': const AccesoPublicoScreen(),
    'login': const LoginScreen(),
    'registro': const SeleccionTipoCuentaScreen(),
    'mi-cuenta': MiCuentaScreen(
      correo: 'persona@ejemplo.invalid',
      cerrarSesion: () async {},
    ),
    'explorar-cabecera': const Scaffold(
      body: Column(
        children: [
          CabeceraExplorar(
            buscador: TextField(
              decoration: InputDecoration(
                hintText: 'Busca establecimientos',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ],
      ),
    ),
    'explorar': Scaffold(
      body: ExplorarScreen(
        controller: fixtures.crearController(
          resultadoUbicacion: const ResultadoUbicacion(
            estado: EstadoUbicacion.inicial,
          ),
        ),
      ),
    ),
    'mapa-sin-ubicacion': Scaffold(
      body: MapaEstablecimientosScreen(
        controller: fixtures.crearController(
          resultadoUbicacion: const ResultadoUbicacion(
            estado: EstadoUbicacion.inicial,
          ),
        ),
        mostrarTiles: false,
      ),
    ),
  };

  for (final environment in SkyEnvironment.values) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key}-${environment.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: skyTheme(SkyPalette.forEnvironment(environment)),
              themeAnimationDuration: Duration.zero,
              home: entry.value,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        if (entry.key != 'mapa-sin-ubicacion') {
          expect(find.byKey(Key('sky-mark-${environment.name}')), findsWidgets);
        }
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${folder.path}/${entry.key}-${environment.name}.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
