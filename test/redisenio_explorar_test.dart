import 'dart:async';

import 'package:cercly/features/explorar/widgets/cabecera_explorar.dart';
import 'package:cercly/features/explorar/widgets/promociones_explorar.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'explorar_establecimientos_test.dart' as fixtures;

PromocionDestacadaModel promo(String id, {bool activa = true, bool vencida = false}) {
  final ahora = DateTime.now();
  return PromocionDestacadaModel(
    id: id,
    establecimientoId: 'establecimiento-1',
    establecimientoNombre: 'Café Carchi',
    categoriaNombre: 'Comida y bebidas',
    titulo: 'Promoción $id',
    descripcion: 'Descripción de prueba',
    fechaInicio: ahora.subtract(const Duration(days: 2)),
    fechaFin: vencida ? ahora.subtract(const Duration(days: 1)) : ahora.add(const Duration(days: 1)),
    radioAlertaMetros: 100,
    latitud: .8116,
    longitud: -77.7172,
    activa: activa,
  );
}

void main() {
  testWidgets('cabecera accesible a 320 px y perfil funcional', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var perfil = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: CabeceraExplorar(
        onPerfil: () => perfil = true,
        buscador: const TextField(),
      )),
    )));
    expect(find.text('Tu mundo más cerca'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('perfil-explorar')));
    expect(perfil, isTrue);
  });

  testWidgets('carrusel solo muestra vigentes y usa distancia del RPC', (tester) async {
    var abierto = false;
    var todas = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: PromocionesExplorar(
        establecimientos: [fixtures.establecimiento(promocion: true)],
        cargarPromociones: () async => [promo('vigente'), promo('inactiva', activa: false), promo('vencida', vencida: true)],
        onEstablecimiento: (_) => abierto = true,
        onVerTodas: () => todas = true,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('promocion-vigente')), findsOneWidget);
    expect(find.byKey(const Key('promocion-inactiva')), findsNothing);
    expect(find.byKey(const Key('promocion-vencida')), findsNothing);
    expect(find.text('a 350 m'), findsOneWidget);
    await tester.tap(find.byKey(const Key('promocion-vigente')));
    expect(abierto, isTrue);
    await tester.tap(find.byKey(const Key('ver-todas-promociones')));
    expect(todas, isTrue);
  });

  testWidgets('sin candidatos no consulta ni reserva un carrusel vacío', (tester) async {
    var consultas = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PromocionesExplorar(
      establecimientos: [fixtures.establecimiento()],
      cargarPromociones: () async { consultas++; return []; },
      onEstablecimiento: (_) {},
      onVerTodas: () {},
    ))));
    expect(consultas, 0);
    expect(find.text('Promociones cerca de ti'), findsNothing);
  });

  testWidgets('loading, error y reintento sin cliente Supabase', (tester) async {
    final pendiente = Completer<List<PromocionDestacadaModel>>();
    var consultas = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PromocionesExplorar(
      establecimientos: [fixtures.establecimiento(promocion: true)],
      cargarPromociones: () {
        consultas++;
        return consultas == 1 ? pendiente.future : Future.value([promo('vigente')]);
      },
      onEstablecimiento: (_) {},
      onVerTodas: () {},
    ))));
    expect(find.byKey(const Key('promociones-loading')), findsOneWidget);
    pendiente.completeError(Exception('sin conexión'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('promociones-reintentar')));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.byKey(const Key('promocion-vigente')), findsOneWidget);
  });
}
