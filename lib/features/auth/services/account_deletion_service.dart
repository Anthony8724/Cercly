import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notificaciones/services/historial_notificaciones_promocion.dart';
import '../../notificaciones/services/notificacion_local_service.dart';

enum AccountDeletionOutcome { deleted, review }

enum AccountDeletionFailure { session, recentAuth, network, pending, unknown }

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.failure);
  final AccountDeletionFailure failure;
}

class AccountDeletionService {
  AccountDeletionService({this.supabase});

  final SupabaseClient? supabase;
  SupabaseClient get _client => supabase ?? Supabase.instance.client;

  bool get hasSession => _client.auth.currentSession != null;

  Future<AccountDeletionOutcome> requestDeletion() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw const AccountDeletionException(AccountDeletionFailure.session);
    }
    try {
      final response = await _client.functions
          .invoke(
            'eliminar-cuenta',
            body: <String, Object>{},
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      final status = data is Map ? data['estado'] : null;
      if (status == 'eliminada') {
        // Esta preferencia identifica el modo de cuenta asociado al usuario.
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.remove('cercly_modo_cuenta_${session.user.id}');
        } catch (_) {
          // Un fallo local no revierte una eliminación ya confirmada en Auth.
        }
        // La identidad ya fue eliminada en Auth. Limpiar el JWT local aunque la
        // llamada de logout remoto no pueda completarse.
        try {
          await HistorialNotificacionesPromocionLocal().borrarDatosLocales();
        } catch (_) {
          // El borrado remoto no se revierte por un error de almacenamiento local.
        }
        try {
          await NotificacionLocalService().cancelarTodas();
        } catch (_) {
          // La identidad ya no existe; el cierre de sesión tiene prioridad.
        }
        try {
          await _client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {
          // GoTrue retira la sesión local antes de llamar al endpoint remoto.
        }
        return AccountDeletionOutcome.deleted;
      }
      if (status == 'revision') return AccountDeletionOutcome.review;
      throw const AccountDeletionException(AccountDeletionFailure.unknown);
    } on FunctionException catch (error) {
      final detail = error.details;
      final status = detail is Map ? detail['estado'] : null;
      if (error.status == 401) {
        throw const AccountDeletionException(AccountDeletionFailure.session);
      }
      if (status == 'autenticacion_reciente_requerida') {
        throw const AccountDeletionException(AccountDeletionFailure.recentAuth);
      }
      if (status == 'solicitud_pendiente') {
        throw const AccountDeletionException(AccountDeletionFailure.pending);
      }
      if (error.status == 0) {
        throw const AccountDeletionException(AccountDeletionFailure.network);
      }
      throw const AccountDeletionException(AccountDeletionFailure.unknown);
    } on TimeoutException {
      throw const AccountDeletionException(AccountDeletionFailure.network);
    }
  }

  Future<void> signOutForReauthentication() =>
      _client.auth.signOut(scope: SignOutScope.local);
}
