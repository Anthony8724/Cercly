import 'package:cercly/features/notificaciones/push/fcm_environment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la política del build coincide con la configuración esperada', () {
    expect(const FcmEnvironmentPolicy.build().enabled, isFalse);
  });
}
