import 'package:cercly/features/notificaciones/push/fcm_environment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la política del build coincide con la configuración esperada', () {
    const expected = bool.fromEnvironment('EXPECT_FCM_AVAILABLE');
    expect(const FcmEnvironmentPolicy.build().enabled, expected);
  });
}
