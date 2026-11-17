import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Synchronously closes the local alert gate before asynchronous logout work.
class SessionNotificationBarrier {
  static bool _blocked = false;
  static String? _retiredSessionId;
  static bool get blocked => _blocked;

  static String? sessionId(Session? session) {
    if (session == null) return null;
    try {
      final parts = session.accessToken.split('.');
      if (parts.length != 3) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final value = claims is Map ? claims['session_id'] : null;
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }

  static void beginLogout(Session? session) {
    _blocked = true;
    _retiredSessionId = sessionId(session);
  }

  static void signedIn(Session? session) {
    final next = sessionId(session);
    if (next != null && next != _retiredSessionId) {
      _blocked = false;
      _retiredSessionId = null;
    }
  }

  static bool sameSession(Session? before, Session? after) {
    if (before == null || after == null) return before == null && after == null;
    if (before.user.id != after.user.id) return false;
    final first = sessionId(before);
    final second = sessionId(after);
    return first != null && second != null
        ? first == second
        : before.accessToken == after.accessToken;
  }
}
