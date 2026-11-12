import 'package:cercly/features/explorar/widgets/promociones_explorar.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PromocionDestacadaModel _promocion() {
  final ahora = DateTime.now();
  return PromocionDestacadaModel(
    id: 'destacada-1',
    establecimientoId: 'negocio-1',
    establecimientoNombre: 'Comercio de prueba',
    categoriaNombre: 'Tiendas',
    titulo: 'Oferta de prueba',
    descripcion: 'Solo para pruebas',
    fechaInicio: ahora.subtract(const Duration(hours: 1)),
    fechaFin: ahora.add(const Duration(days: 1)),
    radioAlertaMetros: 100,
    latitud: 0.8119,
    longitud: -77.7173,
  );
}

void main() {
  testWidgets('Explorar identifica las tarjetas destacadas', (tester) async {
    var verTodas = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PromocionesExplorar(
            establecimientos: const [],
            cargarPromociones: () async => [_promocion()],
            onEstablecimiento: (_) {},
            onVerTodas: () => verTodas = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Promociones destacadas'), findsOneWidget);
    expect(find.byKey(const Key('promocion-destacada-1')), findsOneWidget);
    expect(find.text('Patrocinado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ver-todas-promociones')));
    expect(verTodas, isTrue);
  });

  testWidgets('Explorar oculta el carrusel sin campanas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PromocionesExplorar(
            establecimientos: const [],
            cargarPromociones: () async => [],
            onEstablecimiento: (_) {},
            onVerTodas: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Promociones destacadas'), findsNothing);
    expect(find.text('Patrocinado'), findsNothing);
  });
}
