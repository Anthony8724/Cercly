import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../models/propuesta_correccion.dart';
import '../../establecimientos/services/establecimiento_service.dart';

class EstablecimientoSolicitudOpcion {
  const EstablecimientoSolicitudOpcion({
    required this.id,
    required this.nombre,
    required this.direccion,
  });

  final String id;
  final String nombre;
  final String direccion;

  factory EstablecimientoSolicitudOpcion.fromSupabase(
    Map<String, dynamic> datos,
  ) {
    return EstablecimientoSolicitudOpcion(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String? ?? 'Establecimiento desconocido',
      direccion: datos['direccion'] as String? ?? 'Sin dirección',
    );
  }
}

class SolicitudEstablecimientoDetalle {
  const SolicitudEstablecimientoDetalle({
    required this.solicitud,
    required this.nombreSolicitante,
    required this.nombreEstablecimiento,
    required this.direccionEstablecimiento,
    this.datosPropuestos = const {},
    this.aplicacion,
  });

  final SolicitudEstablecimientoModel solicitud;
  final String nombreSolicitante;
  final String nombreEstablecimiento;
  final String direccionEstablecimiento;
  final Map<String, dynamic> datosPropuestos;
  final Map<String, dynamic>? aplicacion;
  bool get esCorreccion =>
      solicitud.tipo == SolicitudEstablecimientoModel.tipoCorreccion;
  bool get esEstructurada =>
      esCorreccion && datosPropuestos.containsKey('cambios');
  Map<String, dynamic>? get cambiosValidos =>
      PropuestaCorreccion.validar(datosPropuestos['cambios']);
  bool get aplicada {
    if (solicitud.datosSuprimidos) return false;
    final a = aplicacion;
    if (!esCorreccion ||
        !solicitud.fueAprobada ||
        a == null ||
        a['solicitud_id'] != solicitud.id) {
      return false;
    }
    final antes = a['antes'], despues = a['despues'];
    return antes is Map &&
        despues is Map &&
        antes.isNotEmpty &&
        antes.length == despues.length &&
        antes.keys.every(
          (k) =>
              PropuestaCorreccion.etiquetas.containsKey(k) &&
              despues.containsKey(k),
        ) &&
        antes.keys.any((k) => antes[k] != despues[k]);
  }

  String get etiquetaEstado {
    if (solicitud.datosSuprimidos) return 'Historial con datos suprimidos';
    if (solicitud.estaPendiente) return 'Pendiente';
    if (solicitud.fueRechazada) return 'Rechazada';
    if (!esCorreccion) return 'Aprobada';
    if (aplicada) return 'Corrección aplicada';
    return esEstructurada
        ? 'Sin aplicación acreditada'
        : 'Revisada manualmente';
  }

  factory SolicitudEstablecimientoDetalle.fromSupabase(
    Map<String, dynamic> datos,
  ) {
    final rawAplicacion = datos['aplicacion'];
    final aplicacion = rawAplicacion is List && rawAplicacion.length == 1
        ? rawAplicacion.single
        : rawAplicacion;
    final solicitante = datos['solicitante'] as Map<String, dynamic>?;

    final establecimiento = datos['establecimiento'] as Map<String, dynamic>?;

    return SolicitudEstablecimientoDetalle(
      solicitud: SolicitudEstablecimientoModel.fromSupabase(datos),
      aplicacion: aplicacion is Map
          ? Map<String, dynamic>.from(aplicacion)
          : null,
      nombreSolicitante:
          solicitante?['nombre'] as String? ??
          (datos['datos_suprimidos'] == true
              ? 'Cuenta eliminada'
              : 'Usuario desconocido'),
      nombreEstablecimiento:
          establecimiento?['nombre'] as String? ??
          (datos['datos_propuestos'] as Map<String, dynamic>?)?['nombre']
              as String? ??
          'Establecimiento nuevo',
      direccionEstablecimiento:
          establecimiento?['direccion'] as String? ??
          (datos['datos_propuestos'] as Map<String, dynamic>?)?['direccion']
              as String? ??
          'Sin dirección',
      datosPropuestos: Map<String, dynamic>.from(
        datos['datos_propuestos'] as Map? ?? const {},
      ),
    );
  }
}

abstract interface class SolicitudEstablecimientoRepository {
  Future<List<EstablecimientoSolicitudOpcion>> listarEstablecimientosParaTipo(
    String tipo, {
    String busqueda = '',
    int offset = 0,
    String? id,
  });

  Future<List<EstablecimientoSolicitudOpcion>> listarAsociadosParaTipo(
    String tipo,
  );

  Future<Map<String, dynamic>> datosParaCorreccion(String establecimientoId);
  Future<List<Map<String, dynamic>>> categoriasParaCorreccion();
  Future<String> crear({
    required String establecimientoId,
    required String tipo,
    required String mensaje,
    Map<String, dynamic>? cambios,
  });
}

class SolicitudEstablecimientoService
    implements SolicitudEstablecimientoRepository {
  SolicitudEstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _consultaConDetalles = '''
    *,
    solicitante:usuarios!solicitudes_establecimientos_solicitante_id_fkey(
      nombre
    ),
    establecimiento:establecimientos!solicitudes_establecimientos_establecimiento_id_fkey(
      nombre,
      direccion
    ),
    aplicacion:correcciones_aplicadas!correcciones_aplicadas_solicitud_id_fkey(
      solicitud_id, antes, despues, cerrado_en
    )
  ''';

  Future<List<EstablecimientoSolicitudOpcion>>
  listarEstablecimientosAprobados() async {
    return listarEstablecimientosParaTipo(
      SolicitudEstablecimientoModel.tipoCorreccion,
    );
  }

  @override
  Future<List<EstablecimientoSolicitudOpcion>> listarEstablecimientosParaTipo(
    String tipo, {
    String busqueda = '',
    int offset = 0,
    String? id,
  }) async {
    if (!SolicitudEstablecimientoModel.tiposPermitidos.contains(tipo)) {
      throw ArgumentError('El tipo de solicitud no es válido.');
    }

    var consulta = _supabase
        .from('establecimientos')
        .select('id, nombre, direccion')
        .eq('estado', 'aprobado')
        .eq('publicable', true);

    if (tipo == SolicitudEstablecimientoModel.tipoReclamar) {
      consulta = consulta
          .eq('fuente', 'osm')
          .eq('estado_reclamo', 'no_reclamado')
          .isFilter('propietario_id', null);
    } else if (tipo == SolicitudEstablecimientoModel.tipoAcceso) {
      consulta = consulta.not('propietario_id', 'is', null);
    }

    if (offset < 0) throw ArgumentError('Página no válida.');
    if (id != null) consulta = consulta.eq('id', id);
    final texto = busqueda.trim();
    if (texto.isNotEmpty) {
      // Los comodines introducidos por el usuario se buscan literalmente.
      final literal = texto
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      consulta = consulta.ilike('nombre', '%$literal%');
    }
    final respuesta = await consulta
        .order('nombre', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + 19);

    return respuesta
        .map<EstablecimientoSolicitudOpcion>(
          EstablecimientoSolicitudOpcion.fromSupabase,
        )
        .toList();
  }

  @override
  Future<List<EstablecimientoSolicitudOpcion>> listarAsociadosParaTipo(
    String tipo,
  ) async {
    // Reclamar y solicitar acceso nunca reutilizan una asociación como permiso.
    if (tipo != SolicitudEstablecimientoModel.tipoCorreccion) return [];
    final negocios = await EstablecimientoService(supabase: _supabase)
        .listarEstablecimientosDelUsuario();
    if (negocios.isEmpty) return [];
    final respuesta = await _supabase
        .from('establecimientos')
        .select('id, nombre, direccion')
        .inFilter('id', negocios.map((e) => e.id).toList())
        .eq('estado', 'aprobado')
        .eq('publicable', true)
        .order('nombre', ascending: true)
        .order('id', ascending: true);
    return respuesta.map(EstablecimientoSolicitudOpcion.fromSupabase).toList();
  }

  Future<SolicitudEstablecimientoDetalle> obtenerDetalle(String id) async {
    final fila = await _supabase
        .from('solicitudes_establecimientos')
        .select(_consultaConDetalles)
        .eq('id', id)
        .single();
    return SolicitudEstablecimientoDetalle.fromSupabase(fila);
  }

  Future<List<SolicitudEstablecimientoDetalle>> listarTodas() async {
    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .select(_consultaConDetalles)
        .order('creado_en', ascending: false);

    return respuesta
        .map<SolicitudEstablecimientoDetalle>(
          SolicitudEstablecimientoDetalle.fromSupabase,
        )
        .toList();
  }

  Future<List<SolicitudEstablecimientoDetalle>> listarDelUsuarioActual() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .select(_consultaConDetalles)
        .eq('solicitante_id', usuario.id)
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
        .select(_consultaConDetalles)
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

  @override
  Future<List<Map<String, dynamic>>> categoriasParaCorreccion() async {
    final filas = await _supabase
        .from('categorias')
        .select('id,nombre')
        .eq('activa', true)
        .order('nombre', ascending: true);
    return filas.map((f) => Map<String, dynamic>.from(f)).toList();
  }

  @override
  Future<Map<String, dynamic>> datosParaCorreccion(
    String establecimientoId,
  ) async {
    return await _supabase
        .from('establecimientos')
        .select(
          'nombre, direccion, categoria_id, descripcion, telefono_publico, latitud, longitud',
        )
        .eq('id', establecimientoId)
        .eq('estado', 'aprobado')
        .eq('publicable', true)
        .single();
  }

  Future<void> aplicarCorreccion({
    required String solicitudId,
    required String motivo,
  }) async {
    // Sin fallback a la RPC antigua: aprobar sin aplicar sería un falso éxito.
    await _supabase.rpc(
      'aplicar_correccion_establecimiento',
      params: {'p_solicitud_id': solicitudId, 'p_motivo': motivo.trim()},
    );
  }

  @override
  Future<String> crear({
    required String establecimientoId,
    required String tipo,
    required String mensaje,
    Map<String, dynamic>? cambios,
  }) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión para crear una solicitud.');
    }

    if (!SolicitudEstablecimientoModel.tiposPermitidos.contains(tipo)) {
      throw ArgumentError('El tipo de solicitud no es válido.');
    }

    final texto = mensaje.trim();

    if (texto.isEmpty && tipo != SolicitudEstablecimientoModel.tipoCorreccion) {
      throw ArgumentError('Debes explicar el motivo de la solicitud.');
    }

    if (texto.length > 1000) {
      throw ArgumentError('El mensaje no puede superar los 1000 caracteres.');
    }

    final solicitud = SolicitudEstablecimientoModel(
      id: '',
      solicitanteId: usuario.id,
      establecimientoId: establecimientoId,
      mensaje: texto,
      tipo: tipo,
    );

    final datosCrear = solicitud.toSupabaseParaCrear();
    if (tipo == SolicitudEstablecimientoModel.tipoCorreccion) {
      if (PropuestaCorreccion.validar(cambios) == null) {
        throw ArgumentError('Selecciona cambios concretos y válidos.');
      }
      datosCrear['datos_propuestos'] = {'cambios': cambios};
    }

    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .insert(datosCrear)
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
