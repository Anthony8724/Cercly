import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cercly/sky/sky_ambient_painter.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reconstrucción de la capa nocturna anterior para comparar sus formas.
class _PreviousStaticDots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42159);
    final count = (size.width * size.height / 4600).round().clamp(24, 96);
    for (var index = 0; index < count; index++) {
      final center = Offset(
        8 + random.nextDouble() * (size.width - 16),
        8 + random.nextDouble() * (size.height - 16),
      );
      canvas.drawCircle(
        center,
        .6 + random.nextDouble() * .85,
        Paint()
          ..color = const Color(0xFFDCE4FF)
              .withValues(alpha: .20 + random.nextDouble() * .27),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  setUpAll(() async {
    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ??
        '/home/Anthony/development/flutter';
    final bytes = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  testWidgets('comparación nocturna: puntos previos y estrellas nuevas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final palette = SkyPalette.forEnvironment(SkyEnvironment.noche);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skyTheme(palette),
          home: Scaffold(
            backgroundColor: palette.background,
            body: SafeArea(
              child: Row(
                children: [
                  for (final previous in [true, false])
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              previous
                                  ? 'Antes · puntos estáticos'
                                  : 'Ahora · estrellas',
                              style: TextStyle(color: palette.text),
                            ),
                          ),
                          Expanded(
                            child: ColoredBox(
                              color: palette.background,
                              child: CustomPaint(
                                painter: previous
                                    ? _PreviousStaticDots()
                                    : SkyAmbientPainter(
                                        palette: palette,
                                        motion: const AlwaysStoppedAnimation(0),
                                        header: false,
                                        intensity: 1,
                                      ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('design/cercly-sky/capturas/comparativa-noche-antes-despues.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
