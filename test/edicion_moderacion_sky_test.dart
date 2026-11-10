import 'dart:io';
import 'dart:ui' as ui;

import 'package:cercly/features/administracion/widgets/moderacion_establecimiento_dialog.dart';
import 'package:cercly/features/establecimientos/models/establecimiento_model.dart';
import 'package:cercly/features/establecimientos/screens/editar_informacion_establecimiento_screen.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'selector_establecimiento_test.dart' show BusquedaFalsa, negocioA;
import 'establecimiento_edicion_moderacion_service_test.dart' show ficha;

void main() {
  testWidgets(
    'editor aprobado envía propuesta y conserva estado fuera del payload',
    (tester) async {
      final repo = BusquedaFalsa()..asociados = [negocioA];
      final model = EstablecimientoModel.fromSupabase({
        ...ficha(estado: 'aprobado', publicable: true),
        'id': negocioA.id,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: EditarInformacionEstablecimientoScreen(
            establecimiento: model,
            solicitudesService: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('seleccionar-nombre')),
      );
      await tester.tap(find.byKey(const ValueKey('seleccionar-nombre')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nuevo-nombre')),
        'Nuevo nombre propuesto',
      );
      await tester.ensureVisible(find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      expect(repo.enviado, negocioA.id);
      expect(repo.mensajeEnviado, '');
      expect(repo.cambiosEnviados, {
        'nombre': {
          'anterior': 'Café Central',
          'nuevo': 'Nuevo nombre propuesto',
        },
      });
    },
  );
  testWidgets(
    'aprobada sin publicar explica bloqueo y no permite edición directa',
    (tester) async {
      final model = EstablecimientoModel.fromSupabase(
        ficha(estado: 'aprobado'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EditarInformacionEstablecimientoScreen(establecimiento: model),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ficha aprobada sin publicar'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        find.byKey(const Key('guardar-informacion-establecimiento')),
        findsNothing,
      );
    },
  );
  for (final entorno in SkyEnvironment.values) {
    testWidgets(
      'editor aprobado y moderación en ${entorno.name}, sin desbordar',
      (tester) async {
        final capturas = Platform.environment['CERCLY_UI_CAPTURES'];
        if (capturas != null) {
          final font = Platform.environment['CERCLY_UI_FONT'];
          if (font == null) throw StateError('Falta CERCLY_UI_FONT');
          await (FontLoader('Roboto')..addFont(
                Future.value(
                  ByteData.sublistView(File(font).readAsBytesSync()),
                ),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = BusquedaFalsa()..asociados = [negocioA];
        final model = EstablecimientoModel.fromSupabase({
          ...ficha(estado: 'aprobado', publicable: true),
          'id': negocioA.id,
        });
        final theme = skyTheme(SkyPalette.forEnvironment(entorno));
        Future<void> guardar(String pantalla) async {
          if (capturas == null) return;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('captura')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(capturas).create(recursive: true);
            await File('$capturas/${pantalla}_${entorno.name}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('captura'),
            child: MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              home: EditarInformacionEstablecimientoScreen(
                establecimiento: model,
                solicitudesService: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('guardar-informacion-establecimiento')),
          findsNothing,
        );
        expect(find.text('Enviar solicitud'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('seleccionar-nombre')),
          findsOneWidget,
        );
        expect(repo.enviado, isNull);
        await guardar('edicion_aprobada');
        DecisionModeracion? decision;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('captura'),
            child: MaterialApp(
              theme: theme,
              debugShowCheckedModeBanner: false,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        decision = await showDialog<DecisionModeracion>(
                          context: context,
                          builder: (_) => const ModeracionEstablecimientoDialog(
                            nombre: 'Café Central — Nombre largo del establecimiento',
                            aprobar: true,
                          ),
                        );
                      },
                      child: const Text('Moderar'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Moderar'));
        await tester.pumpAndSettle();
        await guardar('moderacion');
        tester.view.physicalSize = const Size(320, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('moderacion-publicar')),
        );
        await tester.tap(find.byKey(const Key('moderacion-publicar')));
        await tester.pumpAndSettle();
        expect(find.text('Aprobar sin publicar'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirmar-moderacion')));
        await tester.pumpAndSettle();
        expect(decision?.publicar, isFalse);
      },
    );
  }

  testWidgets(
    'cancelar moderación no devuelve decisión; rechazo no permite publicación',
    (tester) async {
      DecisionModeracion? decision;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  decision = await showDialog<DecisionModeracion>(
                    context: context,
                    builder: (_) => const ModeracionEstablecimientoDialog(
                      nombre: 'Negocio',
                      aprobar: false,
                    ),
                  );
                },
                child: const Text('Revisar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('moderacion-publicar')), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(decision, isNull);
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-moderacion')));
      await tester.pumpAndSettle();
      expect(decision?.publicar, isFalse);
    },
  );
}
