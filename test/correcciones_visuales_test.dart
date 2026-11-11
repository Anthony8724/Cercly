import 'dart:io';
import 'dart:ui' as ui;

import 'package:cercly/features/solicitudes_establecimientos/widgets/revisar_correccion_dialog.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entorno in SkyEnvironment.values) {
    testWidgets('revisión sin editor y adaptable en ${entorno.name}', (
      tester,
    ) async {
      final captures = Platform.environment['CERCLY_UI_CAPTURES'];
      if (captures != null) {
        final font = Platform.environment['CERCLY_UI_FONT'];
        if (font == null) {
          throw StateError('Falta fuente para renderizar evidencia');
        }
        await (FontLoader('Roboto')..addFont(
              Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('captura'),
          child: MaterialApp(
            theme: skyTheme(SkyPalette.forEnvironment(entorno)),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: RevisarCorreccionDialog(
                establecimiento: 'Negocio de prueba Cercly Sky',
                solicitante: 'Propietario de prueba',
                fecha: DateTime(2026, 11, 7, 12),
                solicitud: 'Actualizar la dirección pública',
                cambios: const {
                  'direccion': {
                    'anterior': 'Dirección anterior',
                    'nuevo': 'Dirección propuesta',
                  },
                  'nombre': {
                    'anterior': 'Nombre anterior',
                    'nuevo': 'Nombre propuesto',
                  },
                },
                actuales: const {
                  'direccion': 'Dirección anterior',
                  'nombre': 'Nombre anterior',
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Actual: Dirección anterior'), findsOneWidget);
      if (captures != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('captura')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(captures).create(recursive: true);
          await File('$captures/revision_${entorno.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.physicalSize = const Size(320, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
