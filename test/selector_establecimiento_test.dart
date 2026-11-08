import 'dart:async';

import 'package:cercly/features/solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import 'package:cercly/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';
import 'package:cercly/features/solicitudes_establecimientos/widgets/selector_establecimiento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const negocioA = EstablecimientoSolicitudOpcion(
  id: 'a',
  nombre: 'Café Central',
  direccion: 'Bolívar 10',
);
const negocioB = EstablecimientoSolicitudOpcion(
  id: 'b',
  nombre: 'Café Central',
  direccion: 'Sucre 20',
);

class BusquedaFalsa implements SolicitudEstablecimientoRepository {
  @override
  Future<Map<String, dynamic>> datosParaCorreccion(String id) async => {
    'nombre': 'Café Central',
    'direccion': 'Bolívar 10',
    'categoria_id': 'cat',
    'descripcion': 'Café',
    'telefono_publico': '',
    'latitud': 0.8,
    'longitud': -77.7,
  };
  @override
  Future<List<Map<String, dynamic>>> categoriasParaCorreccion() async => [
    {'id': 'cat', 'nombre': 'Cafeterías'},
    {'id': 'cat2', 'nombre': 'Restaurantes'},
  ];

  List<EstablecimientoSolicitudOpcion> asociados = [];
  List<EstablecimientoSolicitudOpcion> opciones = [negocioA, negocioB];
  final consultas = <(String, int, String?)>[];
  Future<List<EstablecimientoSolicitudOpcion>> Function(String, int)? buscar;
  String? enviado;
  String? mensajeEnviado;
  Map<String, dynamic>? cambiosEnviados;
  @override
  Future<List<EstablecimientoSolicitudOpcion>> listarAsociadosParaTipo(
    String tipo,
  ) async => asociados;
  @override
  Future<List<EstablecimientoSolicitudOpcion>> listarEstablecimientosParaTipo(
    String tipo, {
    String busqueda = '',
    int offset = 0,
    String? id,
  }) async {
    consultas.add((busqueda, offset, id));
    if (buscar != null && id == null) return buscar!(busqueda, offset);
    return opciones.where((e) => id == null || e.id == id).toList();
  }

  @override
  Future<String> crear({
    required String establecimientoId,
    required String tipo,
    required String mensaje,
    Map<String, dynamic>? cambios,
  }) async {
    enviado = establecimientoId;
    mensajeEnviado = mensaje;
    cambiosEnviados = cambios;
    return 'solicitud';
  }
}

void main() {
  testWidgets('propietario envía cambios válidos sin motivo opcional', (
    tester,
  ) async {
    final repo = BusquedaFalsa()..asociados = [negocioA];
    await tester.pumpWidget(
      MaterialApp(
        home: NuevaSolicitudScreen(service: repo, tipoInicial: 'correccion'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('seleccionar-nombre')),
    );
    await tester.tap(find.byKey(const ValueKey('seleccionar-nombre')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nuevo-nombre')),
      'Nombre propuesto válido',
    );
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    expect(repo.enviado, 'a');
    expect(repo.mensajeEnviado, '');
    expect(repo.cambiosEnviados, {
      'nombre': {
        'anterior': 'Café Central',
        'nuevo': 'Nombre propuesto válido',
      },
    });
  });

  testWidgets(
    'único negocio asociado se selecciona y la ficha inicial tiene prioridad',
    (tester) async {
      final repo = BusquedaFalsa()..asociados = [negocioA];
      await tester.pumpWidget(
        MaterialApp(
          home: NuevaSolicitudScreen(service: repo, tipoInicial: 'correccion'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bolívar 10'), findsOneWidget);
      repo.asociados = [negocioA, negocioB];
      await tester.pumpWidget(
        MaterialApp(
          home: NuevaSolicitudScreen(
            key: const Key('otra'),
            service: repo,
            tipoInicial: 'correccion',
            establecimientoIdInicial: 'b',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sucre 20'), findsOneWidget);
      expect(repo.consultas.last.$3, 'b');
    },
  );

  testWidgets(
    'sin negocios no se selecciona un tercero y se busca por nombre y dirección',
    (tester) async {
      final repo = BusquedaFalsa();
      await tester.pumpWidget(
        MaterialApp(
          home: NuevaSolicitudScreen(service: repo, tipoInicial: 'acceso'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buscar establecimiento'), findsOneWidget);
      await tester.tap(find.byKey(const Key('elegir-establecimiento')));
      await tester.pumpAndSettle();
      expect(find.text('Café Central'), findsNWidgets(2));
      expect(find.text('Bolívar 10'), findsOneWidget);
      expect(find.text('Sucre 20'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('buscar-establecimiento')),
        'Café',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.consultas.last.$1, 'Café');
      await tester.tap(find.byKey(const ValueKey('opcion-b')));
      await tester.pumpAndSettle();
      expect(find.text('Sucre 20'), findsOneWidget);
      expect(
        repo.enviado,
        isNull,
      ); // Elegir no crea solicitud ni concede acceso.
    },
  );

  testWidgets('ID inicial inaccesible no se sustituye por un negocio propio', (
    tester,
  ) async {
    final repo = BusquedaFalsa()..asociados = [negocioA];
    await tester.pumpWidget(
      MaterialApp(
        home: NuevaSolicitudScreen(
          service: repo,
          tipoInicial: 'correccion',
          establecimientoIdInicial: 'privado',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buscar establecimiento'), findsOneWidget);
    expect(repo.enviado, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paginación y prioridad de asociados sin duplicarlos', (
    tester,
  ) async {
    final repo = BusquedaFalsa()..asociados = [negocioA];
    repo.buscar = (_, offset) async => offset == 0
        ? [
            negocioA,
            ...List.generate(
              19,
              (i) => EstablecimientoSolicitudOpcion(
                id: 'n$i',
                nombre: 'Negocio $i',
                direccion: 'Dirección $i',
              ),
            ),
          ]
        : [negocioB];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectorEstablecimiento(
            service: repo,
            tipo: 'acceso',
            asociados: repo.asociados,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('opcion-a')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tus negocios asociados')).dy,
      lessThan(tester.getTopLeft(find.text('Establecimientos disponibles')).dy),
    );
    await tester.scrollUntilVisible(
      find.text('Cargar más'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(repo.consultas.last.$2, 20);
    expect(find.text('Cargar más'), findsNothing);
  });

  testWidgets(
    'búsqueda nueva descarta respuestas antiguas y muestra error recuperable',
    (tester) async {
      final vieja = Completer<List<EstablecimientoSolicitudOpcion>>();
      final repo = BusquedaFalsa()
        ..buscar = (texto, _) =>
            texto.isEmpty ? vieja.future : Future.error(StateError('red'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectorEstablecimiento(
              service: repo,
              tipo: 'acceso',
              asociados: const [],
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('buscar-establecimiento')),
        'nuevo',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      vieja.complete([negocioA]);
      await tester.pumpAndSettle();
      expect(find.text('Café Central'), findsNothing);
      expect(
        find.text('No se pudieron cargar los resultados.'),
        findsOneWidget,
      );
      repo.buscar = (_, _) async => [negocioB];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Sucre 20'), findsOneWidget);
    },
  );
}
