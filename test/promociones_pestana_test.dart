import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/screens/promociones_screen.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra promociones vigentes y permite buscarlas', (
    tester,
  ) async {
    final ahora = DateTime.now();
    final promocion = PromocionDestacadaModel(
      id: 'promocion-prueba',
      establecimientoId: 'comercio-prueba',
      establecimientoNombre: 'Panadería de prueba',
      categoriaNombre: 'Alimentos',
      titulo: 'Oferta especial',
      descripcion: 'Descuento de prueba',
      fechaInicio: ahora.subtract(const Duration(days: 1)),
      fechaFin: ahora.add(const Duration(days: 1)),
      radioAlertaMetros: 100,
      latitud: 0,
      longitud: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: skyTheme(
          SkyPalette.forEnvironment(SkyEnvironment.dia)
              .copyWith(decorationsEnabled: false),
        ),
        home: Scaffold(
          body: PromocionesScreen(cargarPromociones: () async => [promocion]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Oferta especial'), findsOneWidget);
    expect(find.text('Panadería de prueba'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('buscar-promociones')),
      'sin resultados',
    );
    await tester.pumpAndSettle();
    expect(find.text('Oferta especial'), findsNothing);
    expect(
      find.text('No encontramos promociones con esa búsqueda.'),
      findsOneWidget,
    );
  });
}
