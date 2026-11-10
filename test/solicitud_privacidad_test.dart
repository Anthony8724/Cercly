import 'package:cercly/features/solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import 'package:cercly/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> redacted() => {
    'id': 'synthetic-history',
    'solicitante_id': null,
    'datos_suprimidos': true,
    'tipo': 'correccion',
    'estado': 'aprobada',
    'datos_propuestos': <String, dynamic>{},
    'aplicacion': {
      'solicitud_id': 'synthetic-history',
      'antes': <String, dynamic>{},
      'despues': <String, dynamic>{},
    },
  };
  test(
    'historial desvinculado se puede leer sin identidad inventada en la API',
    () {
      final detail = SolicitudEstablecimientoDetalle.fromSupabase(redacted());
      expect(detail.nombreSolicitante, 'Cuenta eliminada');
      expect(detail.etiquetaEstado, 'Historial con datos suprimidos');
      expect(detail.aplicada, isFalse);
      expect(detail.esEstructurada, isFalse);
      expect(detail.solicitud.datosSuprimidos, isTrue);
      expect(detail.solicitud.toSupabaseParaCrear, throwsStateError);
    },
  );
  test('NULL sin marca de privacidad continúa siendo un error de datos', () {
    final value = redacted()..remove('datos_suprimidos');
    expect(
      () => SolicitudEstablecimientoModel.fromSupabase(value),
      throwsArgumentError,
    );
  });
  test('un historial rechazado no se confunde con una aplicación', () {
    final value = redacted()..['estado'] = 'rechazada';
    final detail = SolicitudEstablecimientoDetalle.fromSupabase(value);
    expect(detail.etiquetaEstado, 'Historial con datos suprimidos');
    expect(detail.solicitud.estaPendiente, isFalse);
    expect(detail.aplicada, isFalse);
  });
}
