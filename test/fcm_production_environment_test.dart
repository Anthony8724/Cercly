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

  test('Produccion permanece deshabilitada con activacion explicita', () {
    const policy = FcmEnvironmentPolicy(
      staging: false,
      optIn: false,
      productionOptIn: true,
      url: productionUrl,
    );

    expect(policy.enabled, isFalse);
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

  test('Staging permanece deshabilitado pendiente de revision', () {
    const policy = FcmEnvironmentPolicy(
      staging: true,
      optIn: true,
      url: stagingUrl,
    );

    expect(policy.enabled, isFalse);
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
