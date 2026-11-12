import 'package:supabase_flutter/supabase_flutter.dart';

/// Oferta pública elegible para ser propuesta como campaña destacada.
class PromocionElegibleAdmin {
  const PromocionElegibleAdmin({
    required this.id,
    required this.titulo,
    required this.establecimiento,
    required this.fechaInicio,
    required this.fechaFin,
  });

  final String id;
  final String titulo;
  final String establecimiento;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  factory PromocionElegibleAdmin.fromSupabase(Map<String, dynamic> fila) {
    final negocio = Map<String, dynamic>.from(fila['establecimientos'] as Map);
    return PromocionElegibleAdmin(
      id: fila['id'] as String,
      titulo: fila['titulo'] as String,
      establecimiento: negocio['nombre'] as String? ?? 'Sin nombre',
      fechaInicio: DateTime.parse(fila['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(fila['fecha_fin'] as String).toLocal(),
    );
  }
}

class CampanaDestacadaAdmin {
  const CampanaDestacadaAdmin({
    required this.id,
    required this.promocionId,
    required this.titulo,
    required this.establecimiento,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
  });

  final String id;
  final String promocionId;
  final String titulo;
  final String establecimiento;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado;

  factory CampanaDestacadaAdmin.fromSupabase(Map<String, dynamic> fila) {
    final promocion = Map<String, dynamic>.from(fila['promociones'] as Map);
    final negocio = Map<String, dynamic>.from(
      promocion['establecimientos'] as Map,
    );
    return CampanaDestacadaAdmin(
      id: fila['id'] as String,
      promocionId: fila['promocion_id'] as String,
      titulo: promocion['titulo'] as String? ?? 'Promoción',
      establecimiento: negocio['nombre'] as String? ?? 'Sin nombre',
      fechaInicio: DateTime.parse(fila['fecha_inicio'] as String).toLocal(),
      fechaFin: DateTime.parse(fila['fecha_fin'] as String).toLocal(),
      estado: fila['estado'] as String,
    );
  }
}

class AdministracionDestacadasService {
  AdministracionDestacadasService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> _exigirAdministrador() async {
    if (_supabase.auth.currentUser == null) {
      throw StateError('Debes iniciar sesión como administrador.');
    }
    final autorizado = await _supabase.rpc('es_administrador');
    if (autorizado != true) {
      throw StateError('Solo los administradores gestionan patrocinios.');
    }
  }

  static void validarPeriodo({
    required DateTime inicio,
    required DateTime fin,
    required DateTime inicioPromocion,
    required DateTime finPromocion,
  }) {
    if (!fin.isAfter(inicio)) {
      throw ArgumentError('El fin debe ser posterior al inicio.');
    }
    if (inicio.isBefore(inicioPromocion) || fin.isAfter(finPromocion)) {
      throw ArgumentError('La campaña debe estar dentro de la promoción.');
    }
  }

  /// Ofertas de Tulcán disponibles públicamente, sin aplicar radio GPS.
  Future<List<PromocionElegibleAdmin>> listarElegibles() async {
    await _exigirAdministrador();
    final ahora = DateTime.now().toUtc().toIso8601String();
    final filas = await _supabase
        .from('promociones')
        .select('''
          id, titulo, fecha_inicio, fecha_fin, activa,
          establecimientos!inner(
            id, nombre, ciudad, provincia, estado, publicable
          )
        ''')
        .eq('activa', true)
        .lte('fecha_inicio', ahora)
        .gte('fecha_fin', ahora)
        .eq('establecimientos.estado', 'aprobado')
        .eq('establecimientos.publicable', true)
        .ilike('establecimientos.ciudad', 'Tulcán')
        .ilike('establecimientos.provincia', 'Carchi')
        .order('fecha_fin', ascending: true)
        .limit(100);
    return filas
        .map<PromocionElegibleAdmin>(PromocionElegibleAdmin.fromSupabase)
        .toList(growable: false);
  }

  Future<List<CampanaDestacadaAdmin>> listarCampanas() async {
    await _exigirAdministrador();
    final filas = await _supabase
        .from('promociones_destacadas')
        .select('''
          id, promocion_id, estado, fecha_inicio, fecha_fin,
          promociones!inner(
            id, titulo,
            establecimientos!inner(nombre)
          )
        ''')
        .order('creado_en', ascending: false)
        .limit(100);
    return filas
        .map<CampanaDestacadaAdmin>(CampanaDestacadaAdmin.fromSupabase)
        .toList(growable: false);
  }

  Future<void> crearPendiente({
    required PromocionElegibleAdmin promocion,
    required DateTime inicio,
    required DateTime fin,
  }) async {
    await _exigirAdministrador();
    final ahora = DateTime.now();
    if (inicio.isBefore(ahora.subtract(const Duration(minutes: 1)))) {
      throw ArgumentError('La campaña no puede empezar en el pasado.');
    }
    validarPeriodo(
      inicio: inicio,
      fin: fin,
      inicioPromocion: promocion.fechaInicio,
      finPromocion: promocion.fechaFin,
    );

    final inicialUtc = inicio.toUtc().toIso8601String();
    final finalUtc = fin.toUtc().toIso8601String();
    final previas = await _supabase
        .from('promociones_destacadas')
        .select('id')
        .eq('promocion_id', promocion.id)
        .inFilter('estado', ['pendiente', 'aprobada'])
        .lt('fecha_inicio', finalUtc)
        .gt('fecha_fin', inicialUtc)
        .limit(1);
    if (previas.isNotEmpty) {
      throw StateError('Esta promoción ya tiene una campaña solapada.');
    }
    await _supabase.from('promociones_destacadas').insert({
      'promocion_id': promocion.id,
      'fecha_inicio': inicialUtc,
      'fecha_fin': finalUtc,
      'estado': 'pendiente',
    });
  }

  /// Solo cambia estados permitidos; la RLS exige además ser administrador.
  Future<void> cambiarEstado({
    required CampanaDestacadaAdmin campana,
    required String nuevoEstado,
  }) async {
    await _exigirAdministrador();
    final estadoAnterior = campana.estado;
    final permitido =
        (estadoAnterior == 'pendiente' &&
            (nuevoEstado == 'aprobada' || nuevoEstado == 'rechazada')) ||
        (estadoAnterior == 'aprobada' && nuevoEstado == 'cancelada');
    if (!permitido) throw StateError('Cambio de estado no permitido.');

    if (nuevoEstado == 'aprobada') {
      final ahora = DateTime.now();
      if (!campana.fechaFin.isAfter(ahora)) {
        throw StateError('La campaña ya venció.');
      }
      final candidata = await _supabase
          .from('promociones')
          .select('''
            id, activa, fecha_inicio, fecha_fin,
            establecimientos!inner(estado, publicable, ciudad, provincia)
          ''')
          .eq('id', campana.promocionId)
          .eq('activa', true)
          .lte('fecha_inicio', ahora.toUtc().toIso8601String())
          .gte('fecha_fin', campana.fechaFin.toUtc().toIso8601String())
          .eq('establecimientos.estado', 'aprobado')
          .eq('establecimientos.publicable', true)
          .ilike('establecimientos.ciudad', 'Tulcán')
          .ilike('establecimientos.provincia', 'Carchi')
          .maybeSingle();
      if (candidata == null) {
        throw StateError('La promoción ya no es válida para destacarse.');
      }
      final otras = await _supabase
          .from('promociones_destacadas')
          .select('id')
          .eq('promocion_id', campana.promocionId)
          .eq('estado', 'aprobada')
          .neq('id', campana.id)
          .lt('fecha_inicio', campana.fechaFin.toUtc().toIso8601String())
          .gt('fecha_fin', campana.fechaInicio.toUtc().toIso8601String())
          .limit(1);
      if (otras.isNotEmpty) {
        throw StateError('Ya existe otra campaña aprobada en ese periodo.');
      }
    }

    final respuesta = await _supabase
        .from('promociones_destacadas')
        .update({'estado': nuevoEstado})
        .eq('id', campana.id)
        .eq('estado', estadoAnterior)
        .select('id');
    if (respuesta.isEmpty) {
      throw StateError('La campaña cambió. Actualiza e inténtalo de nuevo.');
    }
  }
}
