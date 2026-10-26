import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../usuarios/models/usuario_model.dart';
import 'account_capabilities.dart';

enum ProfileFailure { missing, inconsistent, expired }

class ProfileException implements Exception {
  const ProfileException(this.failure);
  final ProfileFailure failure;
}

/// Consulta bajo RLS. Solo un resultado vacío permite intentar la recuperación.
/// Nunca convierte un error de red/permisos en una escritura de perfil.
class ProfileService {
  ProfileService({SupabaseClient? supabase}) : _client = supabase;
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<String> loadRole(String userId) => _loadRole(
    userId,
    DateTime.now().add(const Duration(seconds: 15)),
  ).timeout(const Duration(seconds: 15));

  /// El RPC no recibe UUID: calcula las capacidades desde auth.uid() en el servidor.
  /// Antes de desplegarlo, se conserva el enrutamiento por rol existente.
  Future<AccountCapabilities> loadCapabilities(String userId) async {
    final role = await loadRole(userId);
    _checkIdentity(userId);
    try {
      final rows = await _supabase
          .rpc('mis_capacidades')
          .retry(enabled: false, requestTimeout: const Duration(seconds: 7));
      _checkIdentity(userId);
      if (rows is! List || rows.length != 1 || rows.single is! Map) {
        throw const ProfileException(ProfileFailure.inconsistent);
      }
      final capabilities = AccountCapabilities.fromServer(
        Map<String, dynamic>.from(rows.single as Map),
      );
      if (capabilities.role != role) {
        throw const ProfileException(ProfileFailure.inconsistent);
      }
      return capabilities;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') return AccountCapabilities.fromRole(role);
      rethrow;
    } on FormatException {
      throw const ProfileException(ProfileFailure.inconsistent);
    }
  }

  void _checkIdentity(String userId) {
    if (_supabase.auth.currentUser?.id != userId) {
      throw const ProfileException(ProfileFailure.expired);
    }
  }

  Future<String> _loadRole(String userId, DateTime deadline) async {
    _checkIdentity(userId);
    final profile = await _supabase
        .from('usuarios')
        .select('id,rol')
        .eq('id', userId)
        .maybeSingle()
        .retry(enabled: false, requestTimeout: const Duration(seconds: 7));
    _checkIdentity(userId);
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('profile');
    if (profile != null) return _role(profile, userId);

    // Sin argumentos: el servidor obtiene exclusivamente auth.uid().
    try {
      final recovered = await _supabase
          .rpc('recuperar_mi_perfil')
          .retry(enabled: false, requestTimeout: const Duration(seconds: 7));
      _checkIdentity(userId);
      if (recovered is! List || recovered.isEmpty) {
        throw const ProfileException(ProfileFailure.missing);
      }
      if (recovered.length != 1 || recovered.single is! Map<String, dynamic>) {
        throw const ProfileException(ProfileFailure.inconsistent);
      }
      return _role(recovered.single as Map<String, dynamic>, userId);
    } on PostgrestException catch (error) {
      // Permite publicar la app antes del backend sin ocultar el problema.
      if (error.code == 'PGRST202' || error.code == 'P0001') {
        throw const ProfileException(ProfileFailure.missing);
      }
      rethrow;
    }
  }

  String _role(Map<String, dynamic> profile, String userId) {
    final role = profile['rol'];
    if (profile['id'] != userId ||
        !UsuarioModel.rolesPermitidos.contains(role)) {
      throw const ProfileException(ProfileFailure.inconsistent);
    }
    return role as String;
  }
}
