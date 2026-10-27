import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:math' as math;

import '../models/establecimiento_model.dart';

abstract interface class RegistroEstablecimientoRepository {
  Future<List<Map<String, dynamic>>> listarCategoriasActivas();

  Future<List<Map<String, dynamic>>> buscarCoincidenciasCercanas({
    required String nombre,
    required double latitud,
    required double longitud,
  });

  Future<String> crearSolicitudRegistro({
    required String nombre,
    required String categoriaId,
    required String descripcion,
    required String direccion,
    required String telefono,
    required double latitud,
    required double longitud,
    List<Map<String, dynamic>> horarios = const [],
  });
}

class EstablecimientoService implements RegistroEstablecimientoRepository {
  EstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<String> crearSolicitudRegistro({
    required String nombre,
    required String categoriaId,
    required String descripcion,
    required String direccion,
    required String telefono,
    required double latitud,
    required double longitud,
    List<Map<String, dynamic>> horarios = const [],
  }) async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null) throw StateError('Debes iniciar sesión.');
    if (nombre.trim().length < 2 || nombre.trim().length > 120) {
      throw ArgumentError('El nombre debe tener entre 2 y 120 caracteres.');
    }
    if (categoriaId.trim().isEmpty || direccion.trim().isEmpty) {
      throw ArgumentError('Completa la categoría y la dirección.');
    }
    if (!latitud.isFinite ||
        latitud < -90 ||
        latitud > 90 ||
        !longitud.isFinite ||
        longitud < -180 ||
        longitud > 180) {
      throw ArgumentError('La ubicación debe tener coordenadas válidas.');
    }
    final respuesta = await _supabase
        .from('solicitudes_establecimientos')
        .insert({
          'solicitante_id': usuario.id,
          'tipo': 'registro',
          'mensaje': 'Solicitud para registrar un nuevo establecimiento.',
          'datos_propuestos': {
            'nombre': nombre.trim(),
            'categoria_id': categoriaId,
            'descripcion': descripcion.trim(),
            'direccion': direccion.trim(),
            'telefono_publico': telefono.trim(),
            'latitud': latitud,
            'longitud': longitud,
            'horarios': horarios,
          },
        })
        .select('id')
        .single();
    return respuesta['id'] as String;
  }

  @override
  Future<List<Map<String, dynamic>>> buscarCoincidenciasCercanas({
    required String nombre,
    required double latitud,
    required double longitud,
  }) async {
    const radioMetros = 500.0;
    final latDelta = radioMetros / 111320;
    final lonDelta =
        radioMetros /
        (111320 * math.cos(latitud * math.pi / 180).abs().clamp(0.01, 1));
    final filas = await _supabase
        .from('establecimientos')
        .select(
          'id,nombre,direccion,latitud,longitud,fuente,estado_reclamo,propietario_id',
        )
        .gte('latitud', latitud - latDelta)
        .lte('latitud', latitud + latDelta)
        .gte('longitud', longitud - lonDelta)
        .lte('longitud', longitud + lonDelta)
        .eq('estado', 'aprobado')
        .eq('publicable', true)
        .limit(100);

    final nombreNormalizado = _normalizar(nombre);
    final coincidencias = <Map<String, dynamic>>[];
    for (final fila in filas) {
      final candidato = _normalizar(fila['nombre'] as String? ?? '');
      final tokens = nombreNormalizado
          .split(' ')
          .where((t) => t.length > 2)
          .toSet();
      final tokensCandidato = candidato
          .split(' ')
          .where((t) => t.length > 2)
          .toSet();
      final similar =
          candidato == nombreNormalizado ||
          candidato.contains(nombreNormalizado) ||
          nombreNormalizado.contains(candidato) ||
          (tokens.isNotEmpty &&
              tokens.intersection(tokensCandidato).length / tokens.length >=
                  .6);
      if (!similar) continue;
      final distancia = _distanciaMetros(
        latitud,
        longitud,
        (fila['latitud'] as num).toDouble(),
        (fila['longitud'] as num).toDouble(),
      );
      if (distancia <= radioMetros) {
        coincidencias.add({...fila, 'distancia_metros': distancia});
      }
    }
    coincidencias.sort(
      (a, b) => (a['distancia_metros'] as double).compareTo(
        b['distancia_metros'] as double,
      ),
    );
    return coincidencias;
  }

  String _normalizar(String valor) => valor
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  double _distanciaMetros(double lat1, double lon1, double lat2, double lon2) {
    const radio = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radio * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Future<List<Map<String, dynamic>>> listarCategoriasActivas() async {
    final respuesta = await _supabase
        .from('categorias')
        .select('id, nombre, slug, icono, orden')
        .eq('activa', true)
        .order('orden');

    return List<Map<String, dynamic>>.from(respuesta);
  }

  Future<List<Map<String, dynamic>>> listarCategoriasParaRevision() async {
    final respuesta = await _supabase
        .from('categorias')
        .select('id, nombre, activa')
        .order('orden');
    return List<Map<String, dynamic>>.from(respuesta);
  }

  Future<List<EstablecimientoModel>> listarEstablecimientosDelUsuario() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final respuestaPropios = await _supabase
        .from('establecimientos')
        .select()
        .eq('propietario_id', usuario.id)
        .order('creado_en', ascending: false);

    final respuestaAccesos = await _supabase
        .from('miembros_establecimiento')
        .select('establecimiento_id')
        .eq('usuario_id', usuario.id)
        .eq('activo', true);

    final idsCompartidos = respuestaAccesos
        .map<String>((fila) => fila['establecimiento_id'] as String)
        .toSet()
        .toList();

    final establecimientosPorId = <String, EstablecimientoModel>{};

    for (final datos in respuestaPropios) {
      final establecimiento = EstablecimientoModel.fromSupabase(datos);

      establecimientosPorId[establecimiento.id] = establecimiento;
    }

    if (idsCompartidos.isNotEmpty) {
      final respuestaCompartidos = await _supabase
          .from('establecimientos')
          .select()
          .inFilter('id', idsCompartidos)
          .order('creado_en', ascending: false);

      for (final datos in respuestaCompartidos) {
        final establecimiento = EstablecimientoModel.fromSupabase(datos);

        establecimientosPorId[establecimiento.id] = establecimiento;
      }
    }

    final establecimientos = establecimientosPorId.values.toList();

    establecimientos.sort(
      (primero, segundo) =>
          primero.nombre.toLowerCase().compareTo(segundo.nombre.toLowerCase()),
    );

    return establecimientos;
  }

  Future<List<String>> listarIdsDeEstablecimientosCompartidos() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final respuesta = await _supabase
        .from('miembros_establecimiento')
        .select('establecimiento_id')
        .eq('usuario_id', usuario.id)
        .eq('activo', true);

    return respuesta
        .map<String>((fila) => fila['establecimiento_id'] as String)
        .toList();
  }

  Future<bool> esColaborador(String establecimientoId) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      return false;
    }

    final respuesta = await _supabase
        .from('miembros_establecimiento')
        .select('establecimiento_id')
        .eq('establecimiento_id', establecimientoId)
        .eq('usuario_id', usuario.id)
        .eq('activo', true)
        .maybeSingle();

    return respuesta != null;
  }

  /// Comprobación de contexto del panel Propietario: ignora es_administrador().
  Future<bool> puedeGestionarComoPropietario(String establecimientoId) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      return false;
    }

    final respuesta = await _supabase.rpc(
      'puede_gestionar_como_propietario',
      params: {'p_establecimiento_id': establecimientoId},
    );

    return respuesta == true;
  }

  Future<List<EstablecimientoModel>> listarEstablecimientosPendientes() async {
    final respuesta = await _supabase
        .from('establecimientos')
        .select()
        .eq('estado', 'pendiente')
        .order('creado_en');

    return respuesta
        .map<EstablecimientoModel>(EstablecimientoModel.fromSupabase)
        .toList();
  }

  Future<List<EstablecimientoModel>> listarTodosLosEstablecimientos() async {
    final respuesta = await _supabase
        .from('establecimientos')
        .select()
        .order('creado_en', ascending: false);

    return respuesta
        .map<EstablecimientoModel>(EstablecimientoModel.fromSupabase)
        .toList();
  }

  Future<void> cambiarEstado({
    required String establecimientoId,
    required String nuevoEstado,
  }) async {
    const estadosPermitidos = {'pendiente', 'aprobado', 'rechazado'};

    if (!estadosPermitidos.contains(nuevoEstado)) {
      throw ArgumentError('El estado indicado no es válido.');
    }

    await _supabase
        .from('establecimientos')
        .update({'estado': nuevoEstado})
        .eq('id', establecimientoId);
  }

  Future<void> aprobar(String establecimientoId) async {
    await cambiarEstado(
      establecimientoId: establecimientoId,
      nuevoEstado: 'aprobado',
    );
  }

  Future<void> rechazar(String establecimientoId) async {
    await cambiarEstado(
      establecimientoId: establecimientoId,
      nuevoEstado: 'rechazado',
    );
  }

  Future<void> actualizarInformacion(
    EstablecimientoModel establecimiento,
  ) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    if (establecimiento.id.trim().isEmpty) {
      throw ArgumentError(
        'El establecimiento no tiene un identificador válido.',
      );
    }

    final tienePermiso = await puedeGestionarComoPropietario(
      establecimiento.id,
    );

    if (!tienePermiso) {
      throw StateError(
        'No tienes permiso para editar la información de este establecimiento.',
      );
    }

    await _supabase
        .from('establecimientos')
        .update(establecimiento.toSupabaseParaActualizarInformacion())
        .eq('id', establecimiento.id);
  }

  Future<EstablecimientoModel?> obtenerPorId(String id) async {
    final respuesta = await _supabase
        .from('establecimientos')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (respuesta == null) {
      return null;
    }

    return EstablecimientoModel.fromSupabase(respuesta);
  }

  Stream<Map<String, dynamic>?> observarPorId(String id) {
    return _supabase
        .from('establecimientos')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((filas) => filas.isEmpty ? null : filas.first);
  }
}
