import 'package:cercly/features/solicitudes_establecimientos/widgets/proponer_correccion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'propietario propone solo los campos elegidos con valor anterior y nuevo',
    (tester) async {
      Map<String, dynamic> cambios = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: ProponerCorreccion(
                  actuales: const {
                    'nombre': 'Nombre anterior',
                    'direccion': 'Bolívar 10',
                    'categoria_id': 'cat',
                    'descripcion': '',
                    'telefono_publico': '',
                    'latitud': 0.8,
                    'longitud': -77.7,
                  },
                  categorias: const [
                    {'id': 'cat', 'nombre': 'Café'},
                    {'id': 'otro', 'nombre': 'Otra'},
                  ],
                  onChanged: (v) => cambios = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('seleccionar-nombre')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nuevo-nombre')),
        'Nombre nuevo',
      );
      await tester.pumpAndSettle();
      expect(cambios, {
        'nombre': {'anterior': 'Nombre anterior', 'nuevo': 'Nombre nuevo'},
      });
      await tester.tap(find.byKey(const ValueKey('seleccionar-nombre')));
      await tester.pumpAndSettle();
      expect(cambios, isEmpty);
    },
  );
}
