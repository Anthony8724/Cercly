import 'package:cercly/features/solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import 'package:cercly/features/solicitudes_establecimientos/screens/nueva_solicitud_screen.dart';
import 'package:cercly/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SolicitudRepositoryFalso implements SolicitudEstablecimientoRepository {
  final List<String> tiposConsultados = [];

  @override
  Future<List<EstablecimientoSolicitudOpcion>> listarEstablecimientosParaTipo(
    String tipo,
  ) async {
    tiposConsultados.add(tipo);
    return const [
      EstablecimientoSolicitudOpcion(
        id: 'osm-1',
        nombre: 'Negocio OSM',
        direccion: 'Tulcán',
      ),
    ];
  }

  @override
  Future<String> crear({
    required String establecimientoId,
    required String tipo,
    required String mensaje,
  }) async => 'solicitud-1';
}

void main() {
  testWidgets(
    'reclamo preseleccionado consulta solamente opciones reclamables',
    (tester) async {
      final repository = SolicitudRepositoryFalso();

      await tester.pumpWidget(
        MaterialApp(
          home: NuevaSolicitudScreen(
            service: repository,
            tipoInicial: SolicitudEstablecimientoModel.tipoReclamar,
            establecimientoIdInicial: 'osm-1',
            bloquearTipo: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.tiposConsultados, ['reclamar']);
      expect(find.text('Negocio OSM'), findsOneWidget);
      expect(find.text('Reclamar establecimiento'), findsOneWidget);
    },
  );

  testWidgets(
    'cambiar a acceso recarga opciones con la lógica correspondiente',
    (tester) async {
      final repository = SolicitudRepositoryFalso();

      await tester.pumpWidget(
        MaterialApp(home: NuevaSolicitudScreen(service: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reclamar establecimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solicitar acceso').last);
      await tester.pumpAndSettle();

      expect(repository.tiposConsultados, ['reclamar', 'acceso']);
    },
  );
}
