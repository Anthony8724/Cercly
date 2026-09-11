import 'package:cercly/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cercly muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(const CerclyApp());

    expect(find.text('Cercly conectado con Firebase'), findsOneWidget);
  });
}
