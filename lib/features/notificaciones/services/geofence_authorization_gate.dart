import 'package:shared_preferences/shared_preferences.dart';

/// A persisted fail-closed gate read independently by the Android receiver.
/// Operations are serialized so an earlier in-flight arm cannot outlive logout.
class GeofenceAuthorizationGate {
  static const key = 'cercly.geofence.authorized_session.v1';
  static Future<void> _tail = Future<void>.value();
  static int _generation = 0;

  static Future<T> _serial<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static Future<bool> block() {
    _generation++;
    return _serial(() async {
      final preferences = await SharedPreferences.getInstance();
      return preferences.setString(key, '');
    });
  }

  static Future<bool> arm({
    required String userId,
    required String sessionId,
    required bool Function() stillAuthorized,
  }) {
    final generation = _generation;
    return _serial(() async {
      if (generation != _generation || !stillAuthorized()) return false;
      final preferences = await SharedPreferences.getInstance();
      if (generation != _generation || !stillAuthorized()) return false;
      final saved = await preferences.setString(key, '$userId|$sessionId');
      return saved && generation == _generation && stillAuthorized();
    });
  }
}
