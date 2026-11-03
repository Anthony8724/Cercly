import 'package:cercly/features/notificaciones/widgets/staging_proximity_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el panel solo aparece al compilar CERCLY_STAGING', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: StagingProximityDiagnostics()),
        ),
      ),
    );

    if (const bool.fromEnvironment('CERCLY_STAGING')) {
      expect(
        find.byKey(const Key('diagnostico-proximidad-staging')),
        findsOneWidget,
      );
      expect(find.text('Evaluar ahora'), findsOneWidget);
    } else {
      expect(
        find.byKey(const Key('diagnostico-proximidad-staging')),
        findsNothing,
      );
    }
  });

  testWidgets('explica la consulta de ubicación y espera consentimiento', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CERCLY_STAGING')) return;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: StagingProximityDiagnostics()),
        ),
      ),
    );

    await tester.tap(find.text('Consultar ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('Consultar ubicación para la prueba'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Consultar ubicación para la prueba'), findsNothing);
  });

  testWidgets('muestra las pruebas de pantalla bloqueada solo en Staging', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: StagingProximityDiagnostics()),
        ),
      ),
    );
    if (const bool.fromEnvironment('CERCLY_STAGING')) {
      expect(
        find.text('Programar prueba con pantalla bloqueada'),
        findsOneWidget,
      );
      expect(find.text('Cancelar prueba programada'), findsOneWidget);
      expect(
        find.textContaining('no acredita una entrada geográfica'),
        findsOneWidget,
      );
    } else {
      expect(
        find.text('Programar prueba con pantalla bloqueada'),
        findsNothing,
      );
    }
  });
}
