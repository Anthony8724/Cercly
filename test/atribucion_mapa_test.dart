import 'package:cercly/features/explorar/widgets/atribucion_mapa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('créditos y enlaces caben a 260 px con texto ampliado', (
    tester,
  ) async {
    final destinos = <Uri>[];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AtribucionMapa(
              rutas: true,
              abrirEnlace: (uri) async {
                destinos.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('© OpenStreetMap contributors'));
    await tester.tap(find.text('© openrouteservice by HeiGIT'));
    await tester.pump();
    expect(destinos.map((uri) => uri.host), [
      'www.openstreetmap.org',
      'account.heigit.org',
    ]);
    expect(tester.takeException(), isNull);
  });
}
