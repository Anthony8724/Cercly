import 'dart:io';
import 'dart:ui' as ui;

import 'package:cercly/features/auth/screens/acceso_publico_screen.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final folder = Directory('design/cercly-sky/capturas/animacion');
  folder.createSync(recursive: true);

  Future<void> loadFont(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
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

  for (final environment in SkyEnvironment.values) {
    testWidgets('fotogramas-${environment.name}', (tester) async {
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
            home: const AccesoPublicoScreen(),
          ),
        ),
      );

      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(Duration(seconds: frame == 0 ? 0 : 2));
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${folder.path}/${environment.name}-${frame * 2}s.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
