import 'package:cercly/features/solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SolicitudEstablecimientoModel', () {
    test('reconoce una solicitud pendiente', () {
      const solicitud = SolicitudEstablecimientoModel(
        id: 'solicitud-1',
        solicitanteId: 'anthony',
        establecimientoId: 'negocio-1',
        mensaje: 'Solicito la revision del establecimiento.',
        estado: SolicitudEstablecimientoModel.estadoPendiente,
      );

      expect(solicitud.estaPendiente, isTrue);
      expect(solicitud.fueAprobada, isFalse);
      expect(solicitud.fueRechazada, isFalse);
    });

    test('reconoce una solicitud aprobada', () {
      const solicitud = SolicitudEstablecimientoModel(
        id: 'solicitud-2',
        solicitanteId: 'anthony',
        establecimientoId: 'negocio-1',
        mensaje: 'Solicitud revisada.',
        estado: SolicitudEstablecimientoModel.estadoAprobada,
      );

      expect(solicitud.estaPendiente, isFalse);
      expect(solicitud.fueAprobada, isTrue);
      expect(solicitud.fueRechazada, isFalse);
    });

    test('elimina espacios del mensaje al convertirlo', () {
      const solicitud = SolicitudEstablecimientoModel(
        id: 'solicitud-3',
        solicitanteId: 'anthony',
        establecimientoId: 'negocio-1',
        mensaje: '  Revisar establecimiento  ',
        estado: SolicitudEstablecimientoModel.estadoPendiente,
      );

      final datos = solicitud.toFirestore();

      expect(datos['mensaje'], 'Revisar establecimiento');
      expect(datos['estado'], 'pendiente');
      expect(datos['motivoRespuesta'], '');
    });
  });
}
