import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/preferencias_usuario.dart';

abstract interface class PreferenciasRemotas {
  Future<PreferenciasUsuario?> cargar(String usuarioId);
  Future<int> guardar(String usuarioId, PreferenciasUsuario preferencias);
}

class PreferenciasConflictException implements Exception {
  const PreferenciasConflictException();
}

class SupabasePreferenciasRemotas implements PreferenciasRemotas {
  SupabasePreferenciasRemotas(this.client);
  final SupabaseClient client;

  @override
  Future<PreferenciasUsuario?> cargar(String usuarioId) async {
    final row = await client
        .from('preferencias_usuario')
        .select('radio_metros, priorizar_promociones, revision')
        .eq('usuario_id', usuarioId)
        .maybeSingle();
    if (row == null) return null;
    final links = await client
        .from('preferencias_usuario_categorias')
        .select('categoria_id')
        .eq('usuario_id', usuarioId);
    return PreferenciasUsuario(
      categoriasIds: List<Map<String, dynamic>>.from(links)
          .map((item) => item['categoria_id'] as String)
          .toSet(),
      radioMetros: (row['radio_metros'] as num?)?.toInt(),
      priorizarPromociones: row['priorizar_promociones'] as bool? ?? false,
      revision: (row['revision'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<int> guardar(
    String usuarioId,
    PreferenciasUsuario preferencias,
  ) async {
    final current = client.auth.currentUser;
    if (current == null || current.id != usuarioId) {
      throw StateError('La sesión cambió. Vuelve a iniciar sesión.');
    }
    try {
      final response = await client.rpc(
        'guardar_preferencias_usuario',
        params: {
          'p_categorias_ids': preferencias.categoriasIds.toList(),
          'p_radio_metros': preferencias.radioMetros,
          'p_priorizar_promociones': preferencias.priorizarPromociones,
          'p_revision_esperada': preferencias.revision,
        },
      );
      if (response is num) return response.toInt();
      if (response is List && response.isNotEmpty && response.first is num) {
        return (response.first as num).toInt();
      }
      throw const FormatException(
        'Respuesta inválida al guardar preferencias.',
      );
    } on PostgrestException catch (error) {
      if (error.code == '40001') throw const PreferenciasConflictException();
      rethrow;
    }
  }
}

class PreferenciasUsuarioService {
  PreferenciasUsuarioService({
    this.client,
    PreferenciasRemotas? remote,
    this.usuarioIdProvider,
  }) : _remoteOverride = remote;

  final SupabaseClient? client;
  final String? Function()? usuarioIdProvider;
  final PreferenciasRemotas? _remoteOverride;
  SupabaseClient get _supabase => client ?? Supabase.instance.client;
  PreferenciasRemotas get _remote =>
      _remoteOverride ?? SupabasePreferenciasRemotas(_supabase);

  String _userId() {
    final id = usuarioIdProvider?.call() ?? _supabase.auth.currentUser?.id;
    if (id == null) throw StateError('Debes iniciar sesión.');
    return id;
  }

  String _key(String userId) => 'cercly_preferencias_v1_$userId';

  Future<PreferenciasUsuario?> _local(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key(userId));
    if (text == null) return null;
    return PreferenciasUsuario.fromJson(
      jsonDecode(text) as Map<String, dynamic>,
    );
  }

  Future<void> _saveLocal(String userId, PreferenciasUsuario value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(value.toJson()));
  }

  Future<PreferenciasUsuario> cargar() async {
    final userId = _userId();
    final local = await _local(userId);
    if (local?.pendienteSincronizar == true) return local!;
    try {
      final remote = await _remote.cargar(userId);
      final value = remote ?? const PreferenciasUsuario();
      await _saveLocal(userId, value);
      return value;
    } catch (_) {
      return local ?? const PreferenciasUsuario();
    }
  }

  Future<PreferenciasUsuario> guardar(PreferenciasUsuario draft) async {
    final userId = _userId();
    try {
      final revision = await _remote.guardar(userId, draft);
      final saved = draft.copyWith(
        revision: revision,
        pendienteSincronizar: false,
      );
      await _saveLocal(userId, saved);
      return saved;
    } on PreferenciasConflictException {
      await _saveLocal(userId, draft.copyWith(pendienteSincronizar: true));
      rethrow;
    } catch (_) {
      final pending = draft.copyWith(pendienteSincronizar: true);
      await _saveLocal(userId, pending);
      return pending;
    }
  }

  Future<PreferenciasUsuario?> sincronizarPendientes() async {
    final userId = _userId();
    final local = await _local(userId);
    if (local?.pendienteSincronizar != true) return local;
    try {
      return await guardar(local!);
    } on PreferenciasConflictException {
      rethrow;
    }
  }

  Future<void> descartarCambiosLocales() async {
    final userId = _userId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  static Future<void> borrarDatosLocales(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cercly_preferencias_v1_$userId');
  }
}
