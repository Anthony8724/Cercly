import 'package:cercly/features/establecimientos/models/establecimiento_model.dart';
import 'package:cercly/features/establecimientos/screens/mis_negocios_screen.dart';
import 'package:cercly/features/solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'selector_establecimiento_test.dart' show BusquedaFalsa, negocioA;

void main() {
  testWidgets('Mis negocios abre corrección con ID y tipo bloqueado', (
    tester,
  ) async {
    final repo = BusquedaFalsa()..asociados = [negocioA];
    final negocio = EstablecimientoModel(
      id: 'a',
      propietarioId: 'usuario',
      nombre: negocioA.nombre,
      descripcion: 'Café',
      categoriaId: 'cat',
      direccion: negocioA.direccion,
      latitud: 0.8,
      longitud: -77.7,
      telefonoPublico: '',
      horario: {for (final dia in EstablecimientoModel.diasSemana) dia: []},
      zonaHoraria: 'America/Guayaquil',
      estado: 'aprobado',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MisNegociosScreen(
          cargarNegocios: () async => [negocio],
          solicitudService: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Solicitar corrección'));
    await tester.tap(find.text('Solicitar corrección'));
    await tester.pumpAndSettle();
    final pantalla = tester.widget<NuevaSolicitudScreen>(
      find.byType(NuevaSolicitudScreen),
    );
    expect(pantalla.establecimientoIdInicial, 'a');
    expect(pantalla.tipoInicial, 'correccion');
    expect(pantalla.bloquearTipo, isTrue);
    expect(find.text(negocioA.direccion), findsOneWidget);
  });
}
