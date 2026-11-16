import 'dart:async';

import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/screens/promociones_screen.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PromocionDestacadaModel promocionPrueba(String titulo) {
  final ahora = DateTime.now();
  return PromocionDestacadaModel(
    id: titulo,
    establecimientoId: 'negocio-prueba',
    establecimientoNombre: 'Negocio de prueba',
    categoriaNombre: 'Alimentos',
    titulo: titulo,
    descripcion: 'Prueba de actualizacion GPS',
    fechaInicio: ahora.subtract(const Duration(days: 1)),
    fechaFin: ahora.add(const Duration(days: 1)),
    radioAlertaMetros: 100,
    latitud: 0,
    longitud: 0,
  );
}

Widget pantallaPrueba({
  required double latitud,
  required Future<List<PromocionDestacadaModel>> Function() cargar,
  double? radio,
}) => MaterialApp(
  theme: skyTheme(
    SkyPalette.forEnvironment(SkyEnvironment.dia)
        .copyWith(decorationsEnabled: false),
  ),
  home: Scaffold(
    body: PromocionesScreen(
      cargarPromociones: cargar,
      latitudUsuario: latitud,
      longitudUsuario: 0,
      radioMaximoMetros: radio,
    ),
  ),
);

void main() {
  testWidgets('agrupa varios cambios rapidos de GPS en una consulta', (
    tester,
  ) async {
    var consultas = 0;
    Future<List<PromocionDestacadaModel>> cargar() async {
      consultas++;
      return [promocionPrueba('Oferta vigente')];
    }

    await tester.pumpWidget(pantallaPrueba(latitud: 0, cargar: cargar));
    await tester.pumpAndSettle();
    expect(consultas, 1);

    await tester.pumpWidget(pantallaPrueba(latitud: 0.001, cargar: cargar));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(pantallaPrueba(latitud: 0.002, cargar: cargar));
    await tester.pump(const Duration(milliseconds: 300));
    expect(consultas, 1);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(consultas, 2);
  });

  testWidgets('descarta respuestas de una posicion GPS anterior', (
    tester,
  ) async {
    final consultas = <Completer<List<PromocionDestacadaModel>>>[];
    Future<List<PromocionDestacadaModel>> cargar() {
      final consulta = Completer<List<PromocionDestacadaModel>>();
      consultas.add(consulta);
      return consulta.future;
    }

    await tester.pumpWidget(pantallaPrueba(latitud: 0, cargar: cargar));
    expect(consultas.length, 1);

    await tester.pumpWidget(pantallaPrueba(latitud: 0.01, cargar: cargar));
    // La respuesta antigua llega mientras la nueva recarga sigue diferida.
    consultas.first.complete([promocionPrueba('Resultado obsoleto')]);
    await tester.pump();
    expect(find.text('Resultado obsoleto'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(consultas.length, 2);
    consultas.last.complete([promocionPrueba('Resultado reciente')]);
    await tester.pumpAndSettle();
    expect(find.text('Resultado reciente'), findsOneWidget);
  });

  testWidgets('cambiar radio actualiza sin esperar el debounce', (
    tester,
  ) async {
    var consultas = 0;
    Future<List<PromocionDestacadaModel>> cargar() async {
      consultas++;
      return [promocionPrueba('Oferta de radio')];
    }

    await tester.pumpWidget(
      pantallaPrueba(latitud: 0, radio: 1000, cargar: cargar),
    );
    await tester.pumpAndSettle();
    expect(consultas, 1);

    await tester.pumpWidget(
      pantallaPrueba(latitud: 0, radio: 2000, cargar: cargar),
    );
    await tester.pump();
    expect(consultas, 2);
  });
}
