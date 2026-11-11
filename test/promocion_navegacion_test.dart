import 'dart:async';

import 'package:cercly/features/explorar/widgets/promociones_explorar.dart';
import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'explorar_establecimientos_test.dart' as fixtures;
import 'redisenio_explorar_test.dart' show promo;

void main() {
  testWidgets(
    'promoción fuera de primera página resuelve ID y abre ficha una sola vez',
    (tester) async {
      final pendiente = Completer<EstablecimientoPublicoModel?>();
      final consultados = <String>[];
      final abiertos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PromocionesExplorar(
              establecimientos: const [],
              cargarPromociones: () async => [promo('fuera')],
              resolverEstablecimiento: (id) {
                consultados.add(id);
                return pendiente.future;
              },
              onEstablecimiento: (e) => abiertos.add(e.id),
              onVerTodas: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('promocion-fuera')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('promocion-fuera')));
      expect(consultados, ['establecimiento-1']);
      expect(abiertos, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pendiente.complete(fixtures.establecimiento());
      await tester.pumpAndSettle();
      expect(abiertos, ['establecimiento-1']);
    },
  );

  testWidgets(
    'ficha retirada no se abre aunque estuviera en la lista; error permite reintento',
    (tester) async {
      var intentos = 0;
      var abiertos = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PromocionesExplorar(
              establecimientos: [fixtures.establecimiento(promocion: true)],
              cargarPromociones: () async => [promo('retirada')],
              resolverEstablecimiento: (_) async {
                intentos++;
                if (intentos == 1) throw StateError('red');
                return null;
              },
              onEstablecimiento: (_) => abiertos++,
              onVerTodas: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('promocion-retirada')));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudo abrir el establecimiento. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('promocion-retirada')));
      await tester.pumpAndSettle();
      expect(
        find.text('Este establecimiento ya no está disponible públicamente.'),
        findsOneWidget,
      );
      expect(intentos, 2);
      expect(abiertos, 0);
    },
  );
}
