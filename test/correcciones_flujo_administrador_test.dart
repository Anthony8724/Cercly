import 'dart:convert';

import 'package:cercly/features/solicitudes_establecimientos/screens/solicitudes_administrador_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var estado = 'pendiente', escenario = 'manual', nombre = 'Nombre anterior';
  Map<String, dynamic>? auditoria;
  Map<String, dynamic> fila() => {
    'id': 's',
    'solicitante_id': 'u',
    'establecimiento_id': 'e',
    'tipo': 'correccion',
    'estado': estado,
    'mensaje': '',
    'creado_en': '2026-11-07T12:00:00Z',
    'datos_propuestos': escenario == 'manual'
        ? {'descripcion_solicitud': 'Revisar nombre'}
        : {
            'cambios': {
              'nombre': {
                'anterior': 'Nombre anterior',
                'nuevo': 'Nombre propuesto',
              },
            },
          },
    'solicitante': {'nombre': 'Solicitante de prueba'},
    'establecimiento': {'nombre': nombre, 'direccion': 'Dirección de prueba'},
    'aplicacion': auditoria,
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        http.Response response(Object value) => http.Response(
          jsonEncode(value),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
        if (r.url.path == '/rest/v1/categorias') return response([]);
        if (r.method == 'GET' && r.url.path == '/rest/v1/establecimientos') {
          return response({
            'nombre': nombre,
            'direccion': 'Dirección de prueba',
            'categoria_id': 'cat',
            'descripcion': '',
            'telefono_publico': '',
            'latitud': 0.8,
            'longitud': -77.7,
          });
        }
        if (r.method == 'GET' &&
            r.url.path == '/rest/v1/solicitudes_establecimientos') {
          expect(
            r.url.queryParameters['select'],
            contains('correcciones_aplicadas'),
          );
          return response(
            r.url.queryParameters.containsKey('id') ? fila() : [fila()],
          );
        }
        if (r.method == 'POST' &&
            r.url.path == '/rest/v1/rpc/aplicar_correccion_establecimiento') {
          expect(jsonDecode(r.body), {
            'p_solicitud_id': 's',
            'p_motivo': 'Verificado',
          });
          estado = 'aprobada';
          if (escenario != 'sin_auditoria') {
            nombre = 'Nombre propuesto';
            auditoria = {
              'solicitud_id': 's',
              'antes': {'nombre': 'Nombre anterior'},
              'despues': {'nombre': nombre},
              'cerrado_en': '2026-11-07T13:00:00Z',
            };
          }
          return http.Response('', 204, request: r);
        }
        if (r.method == 'POST' &&
            r.url.path == '/rest/v1/rpc/responder_solicitud_establecimiento') {
          estado = jsonDecode(r.body)['p_estado'] as String;
          return http.Response('', 204, request: r);
        }
        throw StateError(
          'Petición inesperada en arnés: ${r.method} ${r.url.path}',
        );
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  for (final caso in [
    ('manual', 'aprobada'),
    ('manual', 'rechazada'),
    ('estructurada', 'aprobada'),
    ('estructurada', 'rechazada'),
    ('sin_auditoria', 'aprobada'),
    ('obsoleta', 'aprobada'),
  ]) {
    testWidgets('${caso.$1}: ${caso.$2} distingue revisión y aplicación real', (
      tester,
    ) async {
      requests.clear();
      estado = 'pendiente';
      escenario = caso.$1;
      auditoria = null;
      nombre = escenario == 'obsoleta' ? 'Otro nombre' : 'Nombre anterior';
      await tester.pumpWidget(
        const MaterialApp(home: SolicitudesAdministradorScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalles'));
      await tester.pumpAndSettle();
      if (escenario == 'manual') {
        expect(find.textContaining('Solicitud manual:'), findsOneWidget);
      } else {
        expect(find.text('Propuesto: Nombre propuesto'), findsOneWidget);
      }
      Navigator.of(tester.element(find.text('Detalles de la solicitud'))).pop();
      await tester.pumpAndSettle();
      final label = caso.$2 == 'rechazada'
          ? 'Rechazar'
          : escenario == 'manual'
          ? 'Registrar revisión manual'
          : 'Aprobar y aplicar';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final confirm = caso.$2 == 'rechazada'
          ? 'Rechazar'
          : escenario == 'manual'
          ? 'Aprobar'
          : 'Aprobar y aplicar';
      if (escenario == 'obsoleta') {
        expect(find.textContaining('La ficha cambió'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: find.byType(AlertDialog),
                  matching: find.widgetWithText(FilledButton, confirm),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        return;
      }
      await tester.enterText(find.byType(TextFormField), 'Verificado');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, confirm),
        ),
      );
      await tester.pumpAndSettle();
      final writes = requests.where((r) => r.method == 'POST').toList();
      expect(writes, hasLength(1));
      final lecturasLista = requests.where(
        (r) =>
            r.method == 'GET' &&
            r.url.path == '/rest/v1/solicitudes_establecimientos' &&
            !r.url.queryParameters.containsKey('id'),
      );
      expect(
        lecturasLista,
        hasLength(2),
        reason: 'Carga inicial y un único refresco después de decidir',
      );
      final aplica = escenario != 'manual' && caso.$2 == 'aprobada';
      expect(
        writes.single.url.path,
        aplica
            ? '/rest/v1/rpc/aplicar_correccion_establecimiento'
            : '/rest/v1/rpc/responder_solicitud_establecimiento',
      );
      if (escenario == 'sin_auditoria') {
        expect(find.text('Corrección aplicada y registrada.'), findsNothing);
        await tester.ensureVisible(find.text('Aprobadas'));
        await tester.tap(find.text('Aprobadas'));
        await tester.pumpAndSettle();
        expect(find.text('Sin aplicación acreditada'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      } else if (aplica) {
        expect(find.text('Corrección aplicada y registrada.'), findsOneWidget);
      } else if (escenario == 'manual' && caso.$2 == 'aprobada') {
        expect(
          find.textContaining('Revisión manual registrada.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
