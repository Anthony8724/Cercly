import 'package:cercly/features/ugc/ugc_service.dart';
import 'package:cercly/features/ugc/ugc_widgets.dart';
import 'package:cercly/features/ugc/ugc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cancelar normas no registra aceptación ni permite publicar', (
    tester,
  ) async {
    final llamadas = <String>[];
    bool? permitido;
    final api = UgcService(
      rpc: (nombre, params) async {
        llamadas.add(nombre);
        return {
          'aceptadas': false,
          'version': 'v1',
          'huella': 'hash',
          'texto': 'Normas completas de prueba',
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                permitido = await asegurarNormasPublicacion(
                  context,
                  service: api,
                );
              },
              child: const Text('Publicar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Normas completas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ugc-cancelar-normas')));
    await tester.pumpAndSettle();
    expect(permitido, false);
    expect(llamadas, ['ugc_normas_publicacion']);
  });
  testWidgets(
    'aceptación envía versión y hash del servidor tras acción explícita',
    (tester) async {
      final llamadas = <String>[];
      Map<String, dynamic>? aceptacion;
      bool? permitido;
      final api = UgcService(
        rpc: (n, p) async {
          llamadas.add(n);
          if (n == 'ugc_aceptar_normas') {
            aceptacion = p;
            return null;
          }
          return {
            'aceptadas': false,
            'version': 'v2',
            'huella': 'hash2',
            'texto': 'Normas de publicación',
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  permitido = await asegurarNormasPublicacion(
                    context,
                    service: api,
                  );
                },
                child: const Text('Publicar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(aceptacion, isNull);
      await tester.tap(find.byKey(const Key('ugc-aceptar-normas')));
      await tester.pumpAndSettle();
      expect(permitido, true);
      expect(aceptacion, {'p_version': 'v2', 'p_huella': 'hash2'});
      expect(llamadas.length, 2);
    },
  );
  testWidgets(
    'error de normas cierra publicación sin aceptar automáticamente',
    (tester) async {
      bool? permitido;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  permitido = await asegurarNormasPublicacion(
                    c,
                    service: UgcService(
                      rpc: (_, _) async => throw Exception('offline'),
                    ),
                  );
                },
                child: const Text('Publicar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(permitido, false);
      expect(find.textContaining('No se enviará contenido'), findsOneWidget);
    },
  );
  test(
    'bloqueo señala cambios solo después de persistencia confirmada',
    () async {
      final before = UgcService.cambios.value;
      var fallo = true;
      final api = UgcService(
        rpc: (n, p) async {
          expect(n, 'ugc_bloquear_responsable');
          expect(p, {'p_tipo': 'fotografia', 'p_objetivo_id': 'foto'});
          if (fallo) throw Exception();
          return null;
        },
      );
      await expectLater(api.bloquear('fotografia', 'foto'), throwsException);
      expect(UgcService.cambios.value, before);
      fallo = false;
      await api.bloquear('fotografia', 'foto');
      expect(UgcService.cambios.value, before + 1);
    },
  );
  test(
    'desbloquear usa solo objetivo y refresca catálogo tras respuesta',
    () async {
      final before = UgcService.cambios.value;
      await UgcService(
        rpc: (n, p) async {
          expect(n, 'ugc_desbloquear');
          expect(p, {'p_bloqueado_id': 'responsable'});
          return null;
        },
      ).desbloquear('responsable');
      expect(UgcService.cambios.value, before + 1);
    },
  );
  testWidgets('seguridad muestra bloqueos persistentes y permite revertirlos', (
    tester,
  ) async {
    var bloqueado = true;
    final api = UgcService(
      rpc: (n, p) async {
        if (n == 'ugc_mis_bloqueos') {
          return bloqueado
              ? [
                  {'id': 'p', 'referencia': 'Café QA', 'fecha': '2026-11-20'},
                ]
              : [];
        }
        if (n == 'ugc_desbloquear') {
          bloqueado = false;
          return null;
        }
        return [];
      },
    );
    await tester.pumpWidget(MaterialApp(home: UgcScreen(service: api)));
    await tester.pumpAndSettle();
    expect(find.text('Responsable de Café QA'), findsOneWidget);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(bloqueado, false);
    expect(find.text('Responsables bloqueados: 0'), findsOneWidget);
  });
  for (final tipo in [
    'establecimiento',
    'fotografia',
    'promocion',
    'propietario',
  ]) {
    testWidgets(
      'denuncia $tipo dentro de la app usa objetivo correcto y sin sujeto ajeno',
      (tester) async {
        Map<String, dynamic>? enviado;
        final api = UgcService(
          rpc: (n, p) async {
            expect(n, 'ugc_denunciar');
            enviado = p;
            return 'caso';
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: DenunciarScreen(tipo: tipo, id: 'objetivo', service: api),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Contenido de prueba');
        await tester.tap(find.text('Enviar denuncia'));
        await tester.pumpAndSettle();
        expect(enviado?['p_tipo'], tipo);
        expect(enviado?['p_objetivo_id'], 'objetivo');
        expect(enviado!.containsKey('denunciante_id'), false);
      },
    );
  }
  testWidgets('normas largas no desbordan pantalla pequeña con fuente grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = UgcService(
      rpc: (_, _) async => {
        'aceptadas': false,
        'version': 'v1',
        'huella': 'h',
        'texto': List.filled(
          50,
          'Normas sin contenido ofensivo ni ilegal.',
        ).join('\n'),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(1.7)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => asegurarNormasPublicacion(c, service: api),
              child: const Text('Normas'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Normas'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
