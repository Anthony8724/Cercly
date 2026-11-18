import 'package:cercly/features/notificaciones/push/fcm_environment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stagingUrl = FcmEnvironmentPolicy.stagingUrl;
  const productionUrl = FcmEnvironmentPolicy.productionUrl;

  test('Produccion permanece deshabilitada por defecto', () {
    const policy = FcmEnvironmentPolicy(
      staging: false,
      optIn: false,
      url: productionUrl,
    );

    expect(policy.enabled, isFalse);
  });

  test('Produccion requiere activacion explicita', () {
    const policy = FcmEnvironmentPolicy(
      staging: false,
      optIn: false,
      productionOptIn: true,
      url: productionUrl,
    );

    expect(policy.enabled, isTrue);
  });

  test('Produccion rechaza URL de Staging', () {
    const policy = FcmEnvironmentPolicy(
      staging: false,
      optIn: false,
      productionOptIn: true,
      url: stagingUrl,
    );

    expect(policy.enabled, isFalse);
  });

  test('Staging requiere su propia bandera', () {
    const policy = FcmEnvironmentPolicy(
      staging: true,
      optIn: true,
      url: stagingUrl,
    );

    expect(policy.enabled, isTrue);
  });

  test('Bandera de Produccion no habilita Staging', () {
    const policy = FcmEnvironmentPolicy(
      staging: true,
      optIn: false,
      productionOptIn: true,
      url: stagingUrl,
    );

    expect(policy.enabled, isFalse);
  });
}
