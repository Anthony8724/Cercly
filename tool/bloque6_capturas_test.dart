import 'dart:io';
import 'dart:ui' as ui;

import 'package:cercly/features/establecimientos/screens/registro_establecimiento_screen.dart';
import 'package:cercly/features/establecimientos/screens/seleccionar_ubicacion_establecimiento_screen.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_service.dart';
import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServicioCaptura implements RegistroEstablecimientoRepository {
  @override
  Future<List<Map<String, dynamic>>> listarCategoriasActivas() async => [
    {
      'id': '10000000-0000-0000-0000-000000000001',
      'nombre': 'Servicios y oficios',
      'slug': 'servicios-oficios',
      'icono': 'handyman',
      'orden': 1,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> buscarCoincidenciasCercanas({
    required String nombre,
    required double latitud,
    required double longitud,
  }) async => [];

  @override
  Future<String> crearSolicitudRegistro({
    required String nombre,
    required String categoriaId,
    required String descripcion,
    required String direccion,
    required String telefono,
    required double latitud,
    required double longitud,
    List<Map<String, dynamic>> horarios = const [],
  }) async => 'solicitud-test';
}

Future<void> _guardarCaptura(WidgetTester tester, String nombre) async {
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byKey(const Key('captura-bloque6')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('artifacts/bloque6');
    folder.createSync(recursive: true);
    File('${folder.path}/$nombre.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  Future<void> cargarFuente(String familia, String ruta) async {
    final bytes = File(ruta).readAsBytesSync();
    await (FontLoader(
      familia,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  setUpAll(() async {
    const flutterRoot = '/home/Anthony/development/flutter';
    const fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
    await cargarFuente('Roboto', '$fonts/Roboto-Regular.ttf');
    await cargarFuente('Roboto', '$fonts/Roboto-Bold.ttf');
    await cargarFuente('MaterialIcons', '$fonts/MaterialIcons-Regular.otf');
    await cargarFuente(
      'Comfortaa',
      'assets/branding/sky/fonts/Comfortaa-Bold.otf',
    );
  });

  testWidgets('captura formulario de registro', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('captura-bloque6'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.dia)),
          home: RegistroEstablecimientoScreen(service: _ServicioCaptura()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _guardarCaptura(tester, 'formulario-registro');
  });

  testWidgets('formulario se adapta a pantalla pequeña y teclado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.dia)),
        home: RegistroEstablecimientoScreen(service: _ServicioCaptura()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();

    expect(find.text('Nombre comercial (obligatorio)'), findsOneWidget);
    expect(find.text('Dirección (obligatoria)'), findsOneWidget);
    expect(
      find.text('Referencia: Bolívar y Sucre, junto al parque'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('captura selector de ubicación', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('captura-bloque6'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.dia)),
          home: const SeleccionarUbicacionEstablecimientoScreen(
            latitudInicial: 0.8119,
            longitudInicial: -77.7173,
            mostrarTiles: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _guardarCaptura(tester, 'selector-ubicacion');
  });

  testWidgets('arrastrar el pin actualiza la ubicación confirmada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const latitudInicial = 0.8119;
    UbicacionUsuario? confirmada;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('abrir-selector'),
              onPressed: () async {
                confirmada = await Navigator.of(context).push<UbicacionUsuario>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SeleccionarUbicacionEstablecimientoScreen(
                          latitudInicial: latitudInicial,
                          longitudInicial: -77.7173,
                          mostrarTiles: false,
                        ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('abrir-selector')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('marcador-arrastrable')),
      const Offset(60, 30),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pump();

    expect(confirmada, isNotNull);
    expect(confirmada!.latitud, isNot(latitudInicial));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no permite confirmar sin punto y muestra coordenadas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    UbicacionUsuario? confirmada;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                confirmada = await Navigator.of(context).push<UbicacionUsuario>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SeleccionarUbicacionEstablecimientoScreen(
                          mostrarTiles: false,
                        ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final boton = tester.widget<FilledButton>(
      find.byKey(const Key('confirmar-ubicacion')),
    );
    expect(boton.onPressed, isNull);
    expect(find.byKey(const Key('sin-punto-seleccionado')), findsOneWidget);

    final mapa = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(Offset(mapa.left + 4, mapa.top + mapa.height * 0.48));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('coordenadas-seleccionadas')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirmar-ubicacion')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('confirmar-ubicacion')));
    await tester.pump();
    expect(confirmada, isNotNull);
    expect(confirmada!.latitud, inInclusiveRange(-90, 90));
    expect(confirmada!.longitud, inInclusiveRange(-180, 180));
    expect(tester.takeException(), isNull);
  });
}
