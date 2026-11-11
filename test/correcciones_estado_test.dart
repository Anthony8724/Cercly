import 'package:cercly/features/solicitudes_establecimientos/models/propuesta_correccion.dart';
import 'package:cercly/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SolicitudEstablecimientoDetalle detalle({
    String estado = 'aprobada',
    bool estructurada = true,
    Map<String, dynamic>? aplicacion,
  }) => SolicitudEstablecimientoDetalle.fromSupabase({
    'id': 's',
    'solicitante_id': 'u',
    'establecimiento_id': 'e',
    'tipo': 'correccion',
    'estado': estado,
    'datos_propuestos': estructurada
        ? {
            'cambios': {
              'nombre': {'anterior': 'Antes', 'nuevo': 'Después'},
            },
          }
        : {'descripcion_solicitud': 'Texto anterior'},
    'aplicacion': aplicacion,
  });
  test('aprobada sin auditoría jamás se muestra como aplicada', () {
    expect(detalle().aplicada, isFalse);
    expect(detalle().etiquetaEstado, 'Sin aplicación acreditada');
    expect(detalle(estructurada: false).etiquetaEstado, 'Revisada manualmente');
    expect(detalle(estado: 'pendiente').etiquetaEstado, 'Pendiente');
    expect(detalle(estado: 'rechazada').etiquetaEstado, 'Rechazada');
  });
  test(
    'auditoría exige identidad coincidente, aprobación y un cambio real',
    () {
      final audit = {
        'solicitud_id': 's',
        'antes': {'nombre': 'Antes'},
        'despues': {'nombre': 'Después'},
      };
      expect(detalle(aplicacion: audit).etiquetaEstado, 'Corrección aplicada');
      expect(
        detalle(aplicacion: {...audit, 'solicitud_id': 'otra'}).aplicada,
        isFalse,
      );
      expect(detalle(estado: 'rechazada', aplicacion: audit).aplicada, isFalse);
      expect(
        detalle(
          aplicacion: {
            ...audit,
            'despues': {'nombre': 'Antes'},
          },
        ).aplicada,
        isFalse,
      );
    },
  );
  test('valida campos, valores, rangos y estructura antes de enviar', () {
    expect(
      PropuestaCorreccion.validar({
        'nombre': {'anterior': 'Antes', 'nuevo': 'Después'},
      }),
      isNotNull,
    );
    for (final value in [
      null,
      [],
      {},
      {
        'estado': {'anterior': 'pendiente', 'nuevo': 'aprobado'},
      },
      {
        'nombre': {'nuevo': 'Después'},
      },
      {
        'nombre': {'anterior': 'Antes', 'nuevo': 'Antes'},
      },
      {
        'latitud': {'anterior': 0, 'nuevo': double.nan},
      },
      {
        'longitud': {'anterior': 0, 'nuevo': 181},
      },
      {
        'categoria_id': {'anterior': 'old', 'nuevo': 'no-uuid'},
      },
      {
        'direccion': {'anterior': 'Antes', 'nuevo': ' '},
      },
    ]) {
      expect(
        PropuestaCorreccion.validar(value),
        isNull,
        reason: 'Propuesta no autorizada o inválida',
      );
    }
  });
}
