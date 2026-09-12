import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/solicitud_establecimiento_model.dart';

class SolicitudEstablecimientoDetalle {
  const SolicitudEstablecimientoDetalle({
    required this.solicitud,
    required this.nombreSolicitante,
    required this.nombreEstablecimiento,
    required this.direccionEstablecimiento,
  });

  final SolicitudEstablecimientoModel solicitud;
  final String nombreSolicitante;
  final String nombreEstablecimiento;
  final String direccionEstablecimiento;

  factory SolicitudEstablecimientoDetalle.fromSupabase(
    Map<String, dynamic> datos,
  ) {
    final solicitante = datos['solicitante'] as Map<String, dynamic>?;

    final establecimiento = datos['establecimiento'] as Map<String, dynamic>?;

    return SolicitudEstablecimientoDetalle(
      solicitud: SolicitudEstablecimientoModel.fromSupabase(datos),
      nombreSolicitante:
          solicitante?['nombre'] as String? ?? 'Usuario desconocido',
      nombreEstablecimiento:
          establecimiento?['nombre'] as String? ??
          'Establecimiento desconocido',
      direccionEstablecimiento:
          establecimiento?['direccion'] as String? ?? 'Sin dirección',
    );
  }
}

class SolicitudEstablecimientoService {
  SolicitudEstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<SolicitudEstablecimientoDetalle>> listarTodas() async {
    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .select('''
          *,
          solicitante:usuarios!solicitudes_establecimientos_solicitante_id_fkey(
            nombre
          ),
          establecimiento:establecimientos!solicitudes_establecimientos_establecimiento_id_fkey(
            nombre,
            direccion
          )
          ''')
        .order('creado_en', ascending: false);

    return respuesta
        .map<SolicitudEstablecimientoDetalle>(
          SolicitudEstablecimientoDetalle.fromSupabase,
        )
        .toList();
  }

  Future<List<SolicitudEstablecimientoDetalle>> listarPorEstado(
    String estado,
  ) async {
    if (!SolicitudEstablecimientoModel.estadosPermitidos.contains(estado)) {
      throw ArgumentError('El estado de solicitud no es válido.');
    }

    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .select('''
          *,
          solicitante:usuarios!solicitudes_establecimientos_solicitante_id_fkey(
            nombre
          ),
          establecimiento:establecimientos!solicitudes_establecimientos_establecimiento_id_fkey(
            nombre,
            direccion
          )
          ''')
        .eq('estado', estado)
        .order('creado_en', ascending: false);

    return respuesta
        .map<SolicitudEstablecimientoDetalle>(
          SolicitudEstablecimientoDetalle.fromSupabase,
        )
        .toList();
  }

  Future<void> responder({
    required String solicitudId,
    required String estado,
    String motivoRespuesta = '',
  }) async {
    const estadosRespuesta = {
      SolicitudEstablecimientoModel.estadoAprobada,
      SolicitudEstablecimientoModel.estadoRechazada,
    };

    if (!estadosRespuesta.contains(estado)) {
      throw ArgumentError('La respuesta debe ser aprobada o rechazada.');
    }

    final motivo = motivoRespuesta.trim();

    if (estado == SolicitudEstablecimientoModel.estadoRechazada &&
        motivo.isEmpty) {
      throw ArgumentError('Debes indicar el motivo del rechazo.');
    }

    if (motivo.length > 1000) {
      throw ArgumentError('El motivo no puede superar los 1000 caracteres.');
    }

    await _supabase.rpc(
      'responder_solicitud_establecimiento',
      params: {
        'p_solicitud_id': solicitudId,
        'p_estado': estado,
        'p_motivo_respuesta': motivo,
      },
    );
  }

  Future<String> crear(SolicitudEstablecimientoModel solicitud) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión para crear una solicitud.');
    }

    if (usuario.id != solicitud.solicitanteId) {
      throw StateError('No puedes crear una solicitud para otro usuario.');
    }

    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .insert(solicitud.toSupabaseParaCrear())
        .select('id')
        .single();

    return respuesta['id'] as String;
  }

  Future<void> eliminarPendiente(String solicitudId) async {
    await _supabase
        .from('solicitudes_establecimientos')
        .delete()
        .eq('id', solicitudId)
        .eq('estado', SolicitudEstablecimientoModel.estadoPendiente);
  }
}
