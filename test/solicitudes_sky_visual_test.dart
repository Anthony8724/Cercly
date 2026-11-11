import 'dart:io';
import 'dart:ui' as ui;

import 'package:cercly/features/solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'selector_establecimiento_test.dart'
    show BusquedaFalsa, negocioA;

void main() {
  for (final entorno in SkyEnvironment.values) {
    testWidgets('solicitud y búsqueda accesibles en ${entorno.name}', (
      tester,
    ) async {
      final capturas = Platform.environment['CERCLY_UI_CAPTURES'];
      if (capturas != null) {
        final font = Platform.environment['CERCLY_UI_FONT'];
        if (font == null) {
          throw StateError('Se requiere una fuente Roboto real para capturar.');
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
      final repo = BusquedaFalsa()..asociados = [negocioA];
      final theme = skyTheme(SkyPalette.forEnvironment(entorno));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('captura'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: NuevaSolicitudScreen(
              service: repo,
              tipoInicial: 'correccion',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(negocioA.direccion), findsOneWidget);
      expect(tester.takeException(), isNull);
      Future<void> guardar(String pantalla) async {
        if (capturas == null) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('captura')),
        );
        await tester.runAsync(() async {
          final imagen = await boundary.toImage(pixelRatio: 1);
          final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
          await Directory(capturas).create(recursive: true);
          await File('$capturas/${pantalla}_${entorno.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          imagen.dispose();
        });
      }

      await guardar('solicitud');
      await tester.tap(find.byKey(const Key('elegir-establecimiento')));
      await tester.pumpAndSettle();
      expect(find.text(negocioA.direccion), findsWidgets);
      await guardar('busqueda');
      // Pantalla estrecha, texto ampliado y teclado presente.
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
