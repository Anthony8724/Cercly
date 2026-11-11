import 'dart:convert';

import 'package:cercly/features/administracion/screens/panel_administrador_screen.dart';
import 'package:cercly/sky/sky_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'establecimiento_edicion_moderacion_service_test.dart' show ficha;
import 'profile_service_test.dart' show sessionJson;

void main() {
  var estado = 'pendiente';
  var publicable = false;
  final requests = <http.Request>[];
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
        if (r.url.path == '/rest/v1/rpc/moderar_estado_establecimiento') {
          final params = jsonDecode(r.body) as Map;
          expect(
            params.keys,
            unorderedEquals(['p_id', 'p_estado', 'p_publicable']),
          );
          estado = params['p_estado'] as String;
          publicable = params['p_publicable'] as bool;
          return http.Response('', 204, request: r);
        }
        expect(r.method, 'GET');
        final value = ficha(estado: estado, publicable: publicable);
        return http.Response(
          jsonEncode(r.url.queryParameters.containsKey('id') ? value : [value]),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode(sessionJson()),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  for (final inicial in ['pendiente', 'rechazado', 'aprobado']) {
    testWidgets(
      'panel $inicial confirma republicación mediante RPC, sin UPDATE directo',
      (tester) async {
        estado = inicial;
        publicable = false;
        requests.clear();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: skyTheme(SkyPalette.forEnvironment(SkyEnvironment.noche)),
            home: const PanelAdministradorScreen(),
          ),
        );
        await tester.pumpAndSettle();
        if (inicial != 'pendiente') {
          final filter = find
              .text(inicial == 'rechazado' ? 'Rechazados' : 'Aprobados')
              .last;
          await tester.ensureVisible(filter);
          await tester.tap(filter);
          await tester.pumpAndSettle();
        }
        final action = find.text(switch (inicial) {
          'pendiente' => 'Aprobar',
          'rechazado' => 'Cambiar a aprobado',
          _ => 'Publicar ficha aprobada',
        });
        await tester.ensureVisible(action);
        await tester.tap(action);
        // El indicador de operación permanece animado detrás del diálogo.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('confirmar-moderacion')), findsOneWidget);
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
        await tester.tap(find.byKey(const Key('confirmar-moderacion')));
        await tester.pumpAndSettle();
        expect(find.text('Ficha aprobada y publicada.'), findsOneWidget);
        expect(estado, 'aprobado');
        expect(publicable, isTrue);
        expect(requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
