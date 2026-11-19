import 'package:cercly/shared/widgets/patrocinio_riiote_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra patrocinador y abre su sitio oficial', (tester) async {
    Uri? destino;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatrocinioRiioteFooter(
            abrirEnlace: (uri) async {
              destino = uri;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('Con el patrocinio de '), findsOneWidget);
    expect(find.text('RIIOTE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('patrocinador-riiote')));
    await tester.pump();
    expect(destino.toString(), 'https://riiote.org/');
  });

  testWidgets('se adapta a pantallas estrechas', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: PatrocinioRiioteFooter(abrirEnlace: (_) async => true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RIIOTE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avisa si el enlace no puede abrirse', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatrocinioRiioteFooter(abrirEnlace: (_) async => false),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('patrocinador-riiote')));
    await tester.pump();
    expect(find.text('No se pudo abrir el sitio de RIIOTE.'), findsOneWidget);
  });
}
