import 'package:cercly/shared/ui/environment_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('marca visiblemente el entorno de staging', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EnvironmentBanner(staging: true, child: Scaffold()),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Banner && widget.message == 'STAGING',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no añade la marca en el entorno normal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EnvironmentBanner(staging: false, child: Scaffold()),
      ),
    );

    expect(find.text('STAGING'), findsNothing);
  });
}
