import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/screens/promociones_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cercly/sky/sky_theme.dart';

void main() {
  testWidgets(
    'solo muestra promociones vigentes dentro del radio y por cercania',
    (tester) async {
      final ahora = DateTime.now();
      PromocionDestacadaModel promo(String nombre, double distancia) =>
          PromocionDestacadaModel(
            id: nombre,
            establecimientoId: 'establecimiento-$nombre',
            establecimientoNombre: 'Negocio $nombre',
            categoriaNombre: 'General',
            titulo: nombre,
            descripcion: 'Prueba',
            fechaInicio: ahora.subtract(const Duration(days: 1)),
            fechaFin: ahora.add(const Duration(days: 1)),
            radioAlertaMetros: 100,
            latitud: 0.814,
            longitud: -77.716,
            distanciaMetros: distancia,
          );
      final datos = [
        promo('Lejana', 4000),
        promo('Fuera', 6000),
        promo('Cercana', 200),
      ];
      Widget pantalla(double radio) => MaterialApp(
        theme: skyTheme(
          SkyPalette.forEnvironment(SkyEnvironment.dia)
              .copyWith(decorationsEnabled: false),
        ),
        home: Scaffold(
          body: PromocionesScreen(
            cargarPromociones: () async => datos,
            latitudUsuario: 0.814,
            longitudUsuario: -77.716,
            radioMaximoMetros: radio,
          ),
        ),
      );

      await tester.pumpWidget(pantalla(5000));
      await tester.pumpAndSettle();
      expect(find.text('Cercana'), findsOneWidget);
      expect(find.text('Lejana'), findsOneWidget);
      expect(find.text('Fuera'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Cercana')).dy,
        lessThan(tester.getTopLeft(find.text('Lejana')).dy),
      );

      await tester.pumpWidget(pantalla(1000));
      await tester.pumpAndSettle();
      expect(find.text('Cercana'), findsOneWidget);
      expect(find.text('Lejana'), findsNothing);
    },
  );
}
