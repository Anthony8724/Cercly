import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/explorar/widgets/tarjeta_establecimiento_publico.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cercly/sky/sky_theme.dart';

const _categoria = CategoriaPublicaModel(
  id: 'categoria-cafe',
  nombre: 'Cafeterías y panaderías',
  slug: 'cafe',
  icono: 'restaurant',
);

EstablecimientoPublicoModel _establecimiento({
  String nombre = 'Café de la Plaza',
  String? foto,
  bool promocion = false,
  double? distancia = 850,
  CategoriaPublicaModel categoria = _categoria,
}) => EstablecimientoPublicoModel(
  id: 'cafe-plaza',
  nombre: nombre,
  descripcion: '',
  direccion: 'Centro',
  latitud: -0.2,
  longitud: -78.5,
  telefonoPublico: '',
  zonaHoraria: 'America/Guayaquil',
  categoria: categoria,
  promociones: const [],
  urlFotoPortada: foto,
  distanciaMetros: distancia,
  tienePromocionesRpc: promocion,
);

Widget _host(EstablecimientoPublicoModel establecimiento) => MaterialApp(
  theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.noche)),
  home: Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TarjetaEstablecimientoPublico(
          establecimiento: establecimiento,
          onTap: () {},
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('da protagonismo a la fotografía y limita su decodificación', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_establecimiento(foto: 'https://images.example/cafe.webp')),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 240);
    expect(
      (resized.imageProvider as NetworkImage).url,
      'https://images.example/cafe.webp',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin fotografía muestra icono ilustrativo de su categoría', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_establecimiento()));

    expect(find.byIcon(Icons.restaurant_rounded), findsNWidgets(2));
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra promoción solo cuando el dato real está activo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_establecimiento(promocion: true, distancia: null)),
    );
    expect(find.text('Promoción'), findsOneWidget);
    expect(find.byKey(const Key('distancia-establecimiento')), findsNothing);

    await tester.pumpWidget(_host(_establecimiento(promocion: false)));
    expect(find.text('Promoción'), findsNothing);
    expect(find.byKey(const Key('indicador-promocion')), findsNothing);
  });

  testWidgets('textos largos caben en una pantalla pequeña y accesible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: _host(
          _establecimiento(
            nombre: 'Café artesanal de especialidad con repostería tradicional y sabores de temporada',
            categoria: const CategoriaPublicaModel(
              id: 'cat-larga',
              nombre:
                  'Cafeterías, panaderías artesanales y reposterías locales',
              slug: 'cafe-panaderia',
              icono: 'restaurant',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('establecimiento-cafe-plaza')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adapta la superficie y mantiene interacción en los cuatro temas',
    (tester) async {
      var taps = 0;
      for (final environment in SkyEnvironment.values) {
        final palette = SkyPalette.forEnvironment(environment);
        await tester.pumpWidget(
          MaterialApp(
            theme: skyTheme(palette),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: TarjetaEstablecimientoPublico(
                    establecimiento: _establecimiento(promocion: true),
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = tester.widget<Material>(
          find.byKey(const Key('establecimiento-cafe-plaza')),
        );
        expect(card.color, palette.surface);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('establecimiento-cafe-plaza')));
      }
      expect(taps, SkyEnvironment.values.length);
    },
  );

  for (final environment in [SkyEnvironment.dia, SkyEnvironment.noche]) {
    testWidgets('captura tarjeta compacta $environment', (tester) async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 190);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final palette = SkyPalette.forEnvironment(environment);
      await tester.pumpWidget(
        MaterialApp(
          theme: skyTheme(palette),
          home: Scaffold(
            backgroundColor: palette.background,
            body: Center(
              child: SizedBox(
                width: 388,
                child: TarjetaEstablecimientoPublico(
                  establecimiento: _establecimiento(promocion: true),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const Key('establecimiento-cafe-plaza')),
        matchesGoldenFile('goldens/sky_tarjeta_${environment.name}.png'),
      );
    });
  }
}
