import 'package:cercly/features/solicitudes_establecimientos/models/solicitud_establecimiento_model.dart';
import 'package:flutter_test/flutter_test.dart';

SolicitudEstablecimientoModel crearSolicitud({
  String tipo = SolicitudEstablecimientoModel.tipoReclamar,
  String estado = SolicitudEstablecimientoModel.estadoPendiente,
  String motivoRespuesta = '',
}) {
  return SolicitudEstablecimientoModel(
    id: '',
    solicitanteId: '00000000-0000-0000-0000-000000000001',
    establecimientoId: '00000000-0000-0000-0000-000000000002',
    mensaje: 'Deseo reclamar este establecimiento',
    tipo: tipo,
    estado: estado,
    motivoRespuesta: motivoRespuesta,
  );
}

void main() {
  test('crea una solicitud pendiente para Supabase', () {
    final solicitud = crearSolicitud();
    final datos = solicitud.toSupabaseParaCrear();

    expect(datos['solicitante_id'], '00000000-0000-0000-0000-000000000001');
    expect(datos['establecimiento_id'], '00000000-0000-0000-0000-000000000002');
    expect(datos['tipo'], 'reclamar');
    expect(datos.containsKey('estado'), isFalse);
    expect(datos.containsKey('creado_en'), isFalse);
  });

  test('identifica una solicitud pendiente', () {
    final solicitud = crearSolicitud();

    expect(solicitud.estaPendiente, true);
    expect(solicitud.fueAprobada, false);
    expect(solicitud.fueRechazada, false);
  });

  test('identifica una solicitud aprobada', () {
    final solicitud = crearSolicitud(
      estado: SolicitudEstablecimientoModel.estadoAprobada,
    );

    expect(solicitud.estaPendiente, false);
    expect(solicitud.fueAprobada, true);
  });

  test('prepara la respuesta del administrador', () {
    final solicitud = crearSolicitud(
      estado: SolicitudEstablecimientoModel.estadoRechazada,
      motivoRespuesta: 'No se pudo verificar la información.',
    );

    expect(solicitud.toSupabaseParaResponder(), {
      'estado': 'rechazada',
      'motivo_respuesta': 'No se pudo verificar la información.',
    });
  });

  test('rechaza un tipo de solicitud inválido', () {
    expect(() => crearSolicitud(tipo: 'tipo-invalido'), throwsArgumentError);
  });

  test('rechaza un estado inválido', () {
    expect(
      () => crearSolicitud(estado: 'estado-invalido'),
      throwsArgumentError,
    );
  });
}
