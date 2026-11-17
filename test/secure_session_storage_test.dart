import 'package:cercly/features/auth/services/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'sb-example-auth-token';
  const url = 'https://example.supabase.co';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('migrates existing session and removes the plaintext copy', () async {
    SharedPreferences.setMockInitialValues({key: 'legacy-session'});
    final store = SecureSessionStorage(url: url);
    await store.initialize();
    expect(await store.accessToken(), 'legacy-session');
    expect((await SharedPreferences.getInstance()).containsKey(key), false);
    final reopened = SecureSessionStorage(url: url);
    await reopened.initialize();
    expect(await reopened.accessToken(), 'legacy-session');
  });

  test('encrypted session takes precedence over stale backup', () async {
    SharedPreferences.setMockInitialValues({key: 'old-session'});
    FlutterSecureStorage.setMockInitialValues({key: 'new-session'});
    final store = SecureSessionStorage(url: url);
    await store.initialize();
    expect(await store.accessToken(), 'new-session');
    expect((await SharedPreferences.getInstance()).containsKey(key), false);
  });

  test(
    'sign out leaves a tombstone that blocks restoring old preference',
    () async {
      final store = SecureSessionStorage(url: url);
      await store.initialize();
      await store.persistSession('session-a');
      await store.removePersistedSession();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, 'old-session');
      final reopened = SecureSessionStorage(url: url);
      await reopened.initialize();
      expect(await reopened.hasAccessToken(), false);
      expect(prefs.containsKey(key), false);
    },
  );

  test('key loss fails closed and keeps legacy data for recovery', () async {
    SharedPreferences.setMockInitialValues({key: 'legacy-session'});
    FlutterSecureStoragePlatform.instance = _FailingStorage();
    final store = SecureSessionStorage(url: url);
    await expectLater(store.initialize(), throwsA(isA<StateError>()));
    expect(
      (await SharedPreferences.getInstance()).getString(key),
      'legacy-session',
    );
  });

  test(
    'lost key never revives a legacy session after migration began',
    () async {
      SharedPreferences.setMockInitialValues({
        key: 'stale-session',
        'cercly.secure_session_migrated.$key': true,
      });
      final store = SecureSessionStorage(url: url);
      await store.initialize();
      expect(await store.accessToken(), isNull);
      expect((await SharedPreferences.getInstance()).containsKey(key), false);
    },
  );

  test('switching users replaces the stored session', () async {
    final store = SecureSessionStorage(url: url);
    await store.initialize();
    await store.persistSession('session-a');
    await store.persistSession('session-b');
    expect(await store.accessToken(), 'session-b');
  });
}

class _FailingStorage extends FlutterSecureStoragePlatform {
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('Key unavailable');
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw StateError('Key unavailable');
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => false;
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {}
  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => {};
}
