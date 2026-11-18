import 'package:cercly/features/notificaciones/services/geofence_authorization_gate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('block persists even when the geofence MethodChannel fails', () async {
    const channel = MethodChannel('test/failing-geofence');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'offline'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(
      await GeofenceAuthorizationGate.arm(
        userId: 'a',
        sessionId: 's',
        stillAuthorized: () => true,
      ),
      true,
    );
    expect(await GeofenceAuthorizationGate.block(), true);
    await expectLater(
      channel.invokeMethod<void>('accountChanged'),
      throwsA(isA<PlatformException>()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString(GeofenceAuthorizationGate.key), '');
  });

  test('queued arm cannot outlive a subsequent logout block', () async {
    final arm = GeofenceAuthorizationGate.arm(
      userId: 'a',
      sessionId: 's',
      stillAuthorized: () => true,
    );
    final logout = GeofenceAuthorizationGate.block();
    expect(await arm, false);
    expect(await logout, true);
    expect(
      (await SharedPreferences.getInstance()).getString(
        GeofenceAuthorizationGate.key,
      ),
      '',
    );
  });

  test('a changed session cannot arm the native receiver', () async {
    expect(
      await GeofenceAuthorizationGate.arm(
        userId: 'a',
        sessionId: 'old',
        stillAuthorized: () => false,
      ),
      false,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        GeofenceAuthorizationGate.key,
      ),
      isNull,
    );
  });
}
