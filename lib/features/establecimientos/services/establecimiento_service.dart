import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/establecimiento_model.dart';

class EstablecimientoService {
  EstablecimientoService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listarCategoriasActivas() async {
    final respuesta = await _supabase
        .from('categorias')
        .select('id, nombre, slug, icono, orden')
        .eq('activa', true)
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

  Future<bool> puedeGestionar(String establecimientoId) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      return false;
    }

    final respuesta = await _supabase.rpc(
      'puede_gestionar_establecimiento',
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

  Future<String> crear(EstablecimientoModel establecimiento) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError(
        'Debes iniciar sesión para registrar un establecimiento.',
      );
    }

    if (usuario.id != establecimiento.propietarioId) {
      throw StateError(
        'No puedes registrar un establecimiento para otro usuario.',
      );
    }

    final respuesta = await _supabase
        .from('establecimientos')
        .insert(establecimiento.toSupabaseParaCrear())
        .select('id')
        .single();

    final establecimientoId = respuesta['id'] as String;
    final horarios = establecimiento.horariosParaSupabase(establecimientoId);

    try {
      if (horarios.isNotEmpty) {
        await _supabase.from('horarios_establecimiento').insert(horarios);
      }

      return establecimientoId;
    } catch (_) {
      await _supabase
          .from('establecimientos')
          .delete()
          .eq('id', establecimientoId);

      rethrow;
    }
  }

  Future<void> actualizarInformacion(EstablecimientoModel establecimiento) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw StateError('Debes iniciar sesión.');
    }

    if (establecimiento.id.trim().isEmpty) {
      throw ArgumentError('El establecimiento no tiene un identificador válido.');
    }

    final tienePermiso = await puedeGestionar(establecimiento.id);

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
