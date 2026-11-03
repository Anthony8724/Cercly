import 'package:cercly/shared/widgets/bienvenida_permisos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('primera ejecución explica permisos sin solicitar ninguno', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BienvenidaPermisos(child: Scaffold(body: Text('Contenido base'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a Cercly'), findsOneWidget);
    expect(find.textContaining('Ubicación: encuentra'), findsOneWidget);
    expect(find.textContaining('Notificaciones: recibe'), findsOneWidget);
    expect(find.textContaining('Segundo plano:'), findsOneWidget);
    expect(find.text('Contenido base'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('rechazar la bienvenida permite continuar y no se repite', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BienvenidaPermisos(child: Scaffold(body: Text('Contenido base'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(find.text('Contenido base'), findsOneWidget);
    expect(find.text('Bienvenido a Cercly'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('cercly.bienvenida_permisos.v1'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: BienvenidaPermisos(child: Scaffold(body: Text('Contenido base'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a Cercly'), findsNothing);
  });
}
