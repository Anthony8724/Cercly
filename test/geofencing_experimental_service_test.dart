import 'package:cercly/features/notificaciones/services/geofencing_experimental_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/geofence');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'status' => <String, Object>{
              'available': true,
              'foregroundLocation': true,
              'preciseLocation': false,
              'backgroundLocation': true,
              'notifications': true,
              'notificationChannel': true,
              'googlePlayServices': true,
              'locationEnabled': true,
              'foregroundAlerts': true,
              'consent': true,
              'registered': true,
              'expiresAt': 1790000000000,
              'registrationState': 'confirmed_by_play_services',
              'promotionCooldownRemainingMs': 7200000,
              'globalCooldownRemainingMs': 900000,
              'dailyNotificationCount': 2,
              'dailyRemaining': 1,
              'lastAndroidEventAt': 1770000000000,
              'lastAndroidEventResult': 'android_enter_received',
              'lastAndroidEnterAt': 1770000000100,
              'lastAndroidExitAt': 1770000000200,
              'lastNativeError': '',
              'lastRealEntryNotificationAt': 1770000000300,
              'lastRealEntryNotificationResult':
                  'delivered_to_notification_manager',
              'screenLockQaScheduledAt': 1770000000400,
              'screenLockQaDueAt': 1770000030400,
              'screenLockQaDeliveredAt': 0,
              'screenLockQaResult': 'scheduled_inexact',
              'lastSimulationAt': 1770000001000,
              'lastSimulationResult': 'simulacion_notificacion_enviada',
              'lastQaReceiverSignalAt': 1770000002000,
            },
            'register' => 'registration_submitted',
            'resetQaCooldown' => true,
            'sendQaReceiverSignal' => true,
            'scheduleScreenLockQa' => 'scheduled_inexact',
            'cancelScreenLockQa' => true,
            'consumePendingNotification' =>
              'f14a1f14-14b0-4b14-8a14-140000000001',
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('build de Production no toca el canal experimental', () async {
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: false,
    );
    expect((await service.status()).available, isFalse);
    await service.setConsent(true);
    await service.remove();
    expect(calls, isEmpty);
  });

  test(
    'consulta y refleja los permisos reales reportados por Android',
    () async {
      final service = GeofencingExperimentalService(
        channel: channel,
        enabled: true,
      );
      final status = await service.status();
      expect(status.foregroundLocation, isTrue);
      expect(status.preciseLocation, isFalse);
      expect(status.backgroundLocation, isTrue);
      expect(status.notificationChannel, isTrue);
      expect(status.consent, isTrue);
      expect(status.registered, isTrue);
      expect(status.registrationState, 'confirmed_by_play_services');
      expect(status.promotionCooldownRemainingMs, 7200000);
      expect(status.globalCooldownRemainingMs, 900000);
      expect(status.dailyNotificationCount, 2);
      expect(status.dailyRemaining, 1);
      expect(status.lastAndroidEventResult, 'android_enter_received');
      expect(status.lastAndroidEnterAt, 1770000000100);
      expect(status.lastAndroidExitAt, 1770000000200);
      expect(status.lastRealEntryNotificationAt, 1770000000300);
      expect(status.screenLockQaResult, 'scheduled_inexact');
      expect(status.screenLockQaDueAt, 1770000030400);
      expect(status.lastSimulationResult, 'simulacion_notificacion_enviada');
      expect(calls.single.method, 'status');
    },
  );

  test('registro envía solo la zona verificada y su expiración', () async {
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: true,
    );
    final expiry = DateTime.now().toUtc().add(const Duration(days: 1));
    final result = await service.register(
      latitude: 0.80525,
      longitude: -77.73434,
      radiusMeters: 1000,
      expiresAt: expiry,
      establishmentName: 'Cercly Test UPEC',
      promotionTitle: 'Promoción de prueba Cercly',
    );
    expect(result, 'registration_submitted');
    expect(calls.single.method, 'register');
    expect(calls.single.arguments, containsPair('radiusMeters', 1000));
    expect(
      calls.single.arguments,
      containsPair('expiresAt', expiry.millisecondsSinceEpoch),
    );
  });

  test(
    'el toque de notificación devuelve la ficha pública pendiente',
    () async {
      final service = GeofencingExperimentalService(
        channel: channel,
        enabled: true,
      );
      expect(
        await service.consumePendingNotification(),
        GeofencingExperimentalService.establishmentId,
      );
      expect(calls.single.method, 'consumePendingNotification');
    },
  );

  test(
    'una geofence vencida se rechaza antes de cruzar el canal nativo',
    () async {
      final service = GeofencingExperimentalService(
        channel: channel,
        enabled: true,
      );
      final result = await service.register(
        latitude: 0.80525,
        longitude: -77.73434,
        radiusMeters: 1000,
        expiresAt: DateTime.utc(2020),
        establishmentName: 'Cercly Test UPEC',
        promotionTitle: 'Promoción de prueba Cercly',
      );
      expect(result, 'promotion_expired');
      expect(calls, isEmpty);
    },
  );

  test('reinicia cooldown QA por el canal Android', () async {
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: true,
    );
    expect(await service.resetQaCooldown(), isTrue);
    expect(calls.single.method, 'resetQaCooldown');
  });

  test('envía señal separada al receiver QA interno', () async {
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: true,
    );
    expect(await service.sendQaReceiverSignal(), isTrue);
    expect(calls.single.method, 'sendQaReceiverSignal');
  });

  test('programa la prueba nativa inexacta de pantalla bloqueada', () async {
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: true,
    );
    expect(await service.scheduleScreenLockQa(), 'scheduled_inexact');
    expect(calls.single.method, 'scheduleScreenLockQa');
  });

  test(
    'cancela la prueba programada sin reiniciar cooldown comercial',
    () async {
      final service = GeofencingExperimentalService(
        channel: channel,
        enabled: true,
      );
      expect(await service.cancelScreenLockQa(), isTrue);
      expect(calls.single.method, 'cancelScreenLockQa');
    },
  );

  test('reserva duplicada se comunica como estado y no se oculta', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'scheduleScreenLockQa'
              ? 'already_scheduled'
              : null;
        });
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: true,
    );
    expect(await service.scheduleScreenLockQa(), 'already_scheduled');
    expect(calls, hasLength(1));
  });

  test('preserva el rechazo nativo del permiso de notificaciones', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'scheduleScreenLockQa'
              ? 'notification_permission_denied'
              : null;
        });
    final service = GeofencingExperimentalService(
      channel: channel,
      enabled: true,
    );
    expect(
      await service.scheduleScreenLockQa(),
      'notification_permission_denied',
    );
  });

  test(
    'Production no puede reiniciar cooldown ni disparar QA nativo',
    () async {
      final service = GeofencingExperimentalService(
        channel: channel,
        enabled: false,
      );
      expect(await service.resetQaCooldown(), isFalse);
      expect(await service.sendQaReceiverSignal(), isFalse);
      expect(await service.scheduleScreenLockQa(), 'unavailable');
      expect(await service.cancelScreenLockQa(), isFalse);
      await service.recordSimulationResult('simulated');
      expect(calls, isEmpty);
    },
  );
}
