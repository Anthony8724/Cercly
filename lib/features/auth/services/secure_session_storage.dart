import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Android session store. A verified encrypted write precedes deleting the
/// legacy preference; an encrypted tombstone prevents reviving an old session.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required String url, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _key = 'sb-${Uri.parse(url).host.split('.').first}-auth-token';

  static const _tombstone = '!cercly-signed-out!';
  final FlutterSecureStorage _storage;
  final String _key;
  late SharedPreferences _legacy;
  String get _migrationMarker => 'cercly.secure_session_migrated.$_key';
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> initialize() async {
    _legacy = await SharedPreferences.getInstance();
    final encrypted = await _storage.read(key: _key);
    final old = _legacy.getString(_key);
    final migrationStarted = _legacy.getBool(_migrationMarker) ?? false;
    if (encrypted == null && old != null && !migrationStarted) {
      // Record the attempt first: after key loss, an old plaintext backup must
      // never silently revive a previously migrated or signed-out session.
      if (!await _legacy.setBool(_migrationMarker, true)) {
        throw StateError('Session migration marker was not saved');
      }
      await _storage.write(key: _key, value: old);
      if (await _storage.read(key: _key) != old) {
        throw StateError('Session migration was not verified');
      }
    } else if (encrypted != null && !migrationStarted) {
      if (!await _legacy.setBool(_migrationMarker, true)) {
        throw StateError('Session migration marker was not saved');
      }
    }
    if (old != null && !await _legacy.remove(_key)) {
      throw StateError('Legacy session removal was not confirmed');
    }
  }

  @override
  Future<String?> accessToken() => _serial(() async {
    final value = await _storage.read(key: _key);
    return value == _tombstone ? null : value;
  });

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _serial(() => _storage.write(key: _key, value: persistSessionString));

  @override
  Future<void> removePersistedSession() => _serial(() async {
    await _storage.write(key: _key, value: _tombstone);
    if (await _storage.read(key: _key) != _tombstone) {
      throw StateError('Session removal was not confirmed');
    }
    if (_legacy.containsKey(_key) && !await _legacy.remove(_key)) {
      throw StateError('Legacy session removal was not confirmed');
    }
  });
}
