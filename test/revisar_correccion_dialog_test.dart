import 'package:cercly/features/solicitudes_establecimientos/widgets/revisar_correccion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('administrador revisa diferencias sin editar valores', (
    tester,
  ) async {
    CorreccionRevisada? respuesta;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                respuesta = await showDialog<CorreccionRevisada>(
                  context: context,
                  builder: (_) => const RevisarCorreccionDialog(
                    cambios: {
                      'nombre': {'anterior': 'Antes', 'nuevo': 'Después'},
                    },
                    solicitud: 'Corregir nombre',
                    actuales: {'nombre': 'Antes'},
                  ),
                );
              },
              child: const Text('Revisar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Actual: Antes'), findsOneWidget);
    expect(find.text('Propuesto: Después'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.text('Aprobar y aplicar'));
    await tester.pumpAndSettle();
    expect(respuesta, isNull);
    await tester.enterText(find.byType(TextFormField), 'Revisado');
    await tester.tap(find.text('Aprobar y aplicar'));
    await tester.pumpAndSettle();
    expect(respuesta!.motivo, 'Revisado');
  });
  testWidgets('solicitud antigua sin cambios estructurados no se aprueba', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RevisarCorreccionDialog(
            cambios: {},
            solicitud: 'Texto anterior',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('no contiene campos estructurados'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
