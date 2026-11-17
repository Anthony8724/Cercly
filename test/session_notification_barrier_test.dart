import 'dart:convert';

import 'package:cercly/features/notificaciones/services/session_notification_barrier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session session(String user, String id, String extra) => Session.fromJson({
  'access_token':
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'session_id': id, 'n': extra}))).replaceAll('=', '')}.sig',
  'token_type': 'bearer',
  'refresh_token': 'test-refresh',
  'expires_in': 3600,
  'user': {
    'id': user,
    'aud': 'authenticated',
    'created_at': '2026-01-01',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  },
})!;

void main() {
  test(
    'logout blocks alerts; refresh of the same session does not release it',
    () {
      final old = session('a', 'session-a', '1');
      final refreshed = session('a', 'session-a', '2');
      SessionNotificationBarrier.beginLogout(old);
      expect(SessionNotificationBarrier.blocked, true);
      expect(SessionNotificationBarrier.sameSession(old, refreshed), true);
      SessionNotificationBarrier.signedIn(refreshed);
      expect(SessionNotificationBarrier.blocked, true);
      SessionNotificationBarrier.signedIn(session('b', 'session-b', '1'));
      expect(SessionNotificationBarrier.blocked, false);
    },
  );
}
