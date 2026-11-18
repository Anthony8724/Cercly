import 'dart:async';
import 'dart:convert';

import 'package:cercly/features/notificaciones/models/configuracion_alertas_proximidad.dart';
import 'package:cercly/features/notificaciones/push/fcm_messaging_gateway.dart';
import 'package:cercly/features/notificaciones/push/fcm_promotion_message.dart';
import 'package:cercly/features/notificaciones/push/fcm_push_service.dart';
import 'package:cercly/features/notificaciones/push/fcm_environment_policy.dart';
import 'package:cercly/features/notificaciones/push/push_promotions_repository.dart';
import 'package:cercly/features/notificaciones/services/preferencias_alertas_proximidad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const userA = 'user-a';
  const userB = 'user-b';
  final now = DateTime.utc(2026, 11, 11, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('política deshabilita FCM incluso con opt-in de Staging', () {
    expect(const FcmEnvironmentPolicy.build().enabled, isFalse);
    expect(
      const FcmEnvironmentPolicy(
        staging: true,
        optIn: true,
        url: 'https://dlajxviqhkdcqnmczhvr.supabase.co',
      ).enabled,
      isFalse,
    );
    expect(
      const FcmEnvironmentPolicy(
        staging: true,
        optIn: false,
        url: 'https://dlajxviqhkdcqnmczhvr.supabase.co',
      ).enabled,
      isFalse,
    );
    expect(
      const FcmEnvironmentPolicy(
        staging: true,
        optIn: true,
        url: 'https://example.test',
      ).enabled,
      isFalse,
    );
  });

  test(
    'producción bloquea activación y evaluación y limpia preferencia previa',
    () async {
      final messaging = _FakeMessaging();
      final repository = _FakeRepository();
      final preferences = _FakePreferences(
        initial: const ConfiguracionAlertasProximidad(
          pushPromocionesActivadas: true,
        ),
      );
      final service = FcmPushService(
        currentUserId: () => userA,
        messaging: messaging,
        repository: repository,
        preferences: preferences,
        local: SharedPreferencesAsync(),
        policy: const FcmEnvironmentPolicy(
          staging: false,
          optIn: true,
          url: 'https://dlajxviqhkdcqnmczhvr.supabase.co',
        ),
      );
      expect(
        await service.enablePromotionalPush(explicitConsent: true),
        FcmActivationResult.unavailable,
      );
      await service.evaluateFreshLocation(
        latitude: 0,
        longitude: 0,
        accuracyMeters: 10,
        observedAt: now,
      );
      await service.reconcileAfterResume();
      expect(preferences.value.pushPromocionesActivadas, isFalse);
      expect(messaging.initializeCalls, 1); // Limpieza de un registro previo.
      expect(repository.registrations, isEmpty);
      expect(repository.evaluations, isEmpty);
      expect(
        repository.preferenceSaves.single.pushPromocionesActivadas,
        isFalse,
      );
      await service.dispose();
    },
  );

  test('exige consentimiento explícito antes de inicializar FCM', () async {
    final messaging = _FakeMessaging();
    final repository = _FakeRepository();
    final service = _service(
      userId: () => userA,
      messaging: messaging,
      repository: repository,
    );

    expect(
      await service.enablePromotionalPush(explicitConsent: false),
      FcmActivationResult.consentRequired,
    );
    expect(messaging.initializeCalls, 0);
    expect(repository.preferenceSaves, isEmpty);
    await service.dispose();
  });

  test(
    'registra instalación solo después del consentimiento y permiso',
    () async {
      final messaging = _FakeMessaging();
      final repository = _FakeRepository();
      final preferences = _FakePreferences();
      final service = _service(
        userId: () => userA,
        messaging: messaging,
        repository: repository,
        preferences: preferences,
        now: () => now,
      );

      expect(
        await service.enablePromotionalPush(explicitConsent: true),
        FcmActivationResult.activated,
      );
      expect(preferences.value.pushPromocionesActivadas, isTrue);
      expect(repository.preferenceSaves.single.frecuencia.maximoPorDia, 6);
      expect(repository.registrations, hasLength(1));
      expect(
        repository.registrations.single.fcmInstallationId,
        'firebase-installation-id-123456',
      );
      await service.dispose();
    },
  );

  test('actualiza la asociación cuando Firebase renueva el FID', () async {
    final messaging = _FakeMessaging();
    final repository = _FakeRepository();
    final service = _service(
      userId: () => userA,
      messaging: messaging,
      repository: repository,
    );
    await service.enablePromotionalPush(explicitConsent: true);

    final refreshed = Completer<void>();
    repository.registrationCompleter = refreshed;
    messaging.tokenController.add('firebase-installation-id-rotated');
    await refreshed.future;

    expect(repository.registrations, hasLength(2));
    expect(
      repository.registrations.last.fcmInstallationId,
      'firebase-installation-id-rotated',
    );
    await service.dispose();
  });

  test('cierra la asociación FCM al cerrar sesión', () async {
    final messaging = _FakeMessaging();
    final repository = _FakeRepository();
    final service = _service(
      userId: () => userA,
      messaging: messaging,
      repository: repository,
    );
    await service.enablePromotionalPush(explicitConsent: true);
    final registrationCount = repository.registrations.length;

    await service.retireBeforeSignOut();
    messaging.tokenController.add('fid-after-sign-out');
    await Future<void>.delayed(Duration.zero);

    expect(repository.revocations, hasLength(1));
    expect(messaging.disableCalls, 1);
    expect(repository.registrations, hasLength(registrationCount));
    await service.dispose();
  });

  test(
    'logout sin red detiene FCM y bloquea el registro de otra cuenta',
    () async {
      var user = userA;
      final messaging = _FakeMessaging();
      final repository = _FakeRepository();
      final preferences = _FakePreferences();
      final service = _service(
        userId: () => user,
        messaging: messaging,
        repository: repository,
        preferences: preferences,
      );
      await service.enablePromotionalPush(explicitConsent: true);
      final count = repository.registrations.length;
      repository.failRevoke = true;
      await expectLater(service.retireBeforeSignOut(), throwsStateError);
      messaging.tokenController.add('fid-after-logout');
      await Future<void>.delayed(Duration.zero);
      expect(repository.registrations.length, count);
      expect(preferences.value.pushPromocionesActivadas, false);
      expect(messaging.disableCalls, 1);
      user = userB;
      final another = _service(
        userId: () => user,
        messaging: messaging,
        repository: repository,
      );
      expect(
        await another.enablePromotionalPush(explicitConsent: true),
        FcmActivationResult.unavailable,
      );
      expect(repository.registrations.length, count);
      await service.dispose();
      await another.dispose();
    },
  );

  test('logout invalida un registro FCM que sigue en vuelo', () async {
    var user = userA;
    final messaging = _FakeMessaging();
    final repository = _FakeRepository();
    final block = Completer<void>();
    repository.registrationBlock = block;
    final service = _service(
      userId: () => user,
      messaging: messaging,
      repository: repository,
    );
    final activation = service.enablePromotionalPush(explicitConsent: true);
    await _until(() => repository.registrations.isNotEmpty);
    await service.retireBeforeSignOut();
    user = userB;
    block.complete();
    expect(await activation, FcmActivationResult.signedOut);
    messaging.tokenController.add('late-token');
    await Future<void>.delayed(Duration.zero);
    expect(repository.registrations.length, 1);
    final another = _service(
      userId: () => user,
      messaging: messaging,
      repository: repository,
    );
    expect(
      await another.enablePromotionalPush(explicitConsent: true),
      FcmActivationResult.unavailable,
    );
    await service.dispose();
    await another.dispose();
  });

  test('cambio de cuenta durante registro entra en cuarentena', () async {
    var user = userA;
    final messaging = _FakeMessaging();
    final repository = _FakeRepository();
    final block = Completer<void>();
    repository.registrationBlock = block;
    final service = _service(
      userId: () => user,
      messaging: messaging,
      repository: repository,
    );
    final activation = service.enablePromotionalPush(explicitConsent: true);
    await _until(() => repository.registrations.isNotEmpty);
    user = userB;
    await service.synchronizeAccount();
    block.complete();
    expect(await activation, FcmActivationResult.signedOut);
    expect(repository.revocations, isEmpty);
    final next = _service(
      userId: () => user,
      messaging: messaging,
      repository: repository,
    );
    expect(
      await next.enablePromotionalPush(explicitConsent: true),
      FcmActivationResult.unavailable,
    );
    await service.dispose();
    await next.dispose();
  });

  test('revoca el registro al detectar permiso de sistema retirado', () async {
    final messaging = _FakeMessaging();
    final repository = _FakeRepository();
    final service = _service(
      userId: () => userA,
      messaging: messaging,
      repository: repository,
    );
    await service.enablePromotionalPush(explicitConsent: true);
    messaging.permitted = false;

    await service.reconcileAfterResume();

    expect(repository.revocations, hasLength(1));
    expect(messaging.disableCalls, 1);
    await service.dispose();
  });

  test('la apertura desde push navega una vez por evento', () async {
    const userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final client = SupabaseClient(
      'https://example.test',
      'public-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        )
        .replaceAll('=', '');
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'e30.$payload.synthetic',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'created_at': '2026-01-01',
          'app_metadata': {},
          'user_metadata': {},
        },
      }),
    );
    final repository = _FakeRepository();
    final registered = Completer<void>();
    repository.registrationCompleter = registered;
    final messaging = _FakeMessaging();
    final preferences = _FakePreferences(
      initial: const ConfiguracionAlertasProximidad(
        pushPromocionesActivadas: true,
      ),
    );
    final service = FcmPushService(
      client: client,
      messaging: messaging,
      repository: repository,
      preferences: preferences,
      local: SharedPreferencesAsync(),
      policy: stagingPolicy,
    );
    final opened = <FcmPromotionMessage>[];
    service.observeAuthentication(
      openPromotion: (message) async {
        opened.add(message);
      },
      showForegroundMessage: (_) {},
    );
    await registered.future;
    await _until(() => messaging.openedController.hasListener);
    final message = FcmPromotionMessage.parse({
      'type': 'promotion',
      'event_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'promotion_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'establishment_id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    })!;
    messaging.openedController.add(message);
    await _until(() => opened.isNotEmpty);
    messaging.openedController.add(message);
    await Future<void>.delayed(Duration.zero);

    expect(opened, hasLength(1));
    expect(opened.single.promotionId, message.promotionId);
    await service.dispose();
  });

  test(
    'rechaza ubicación caducada y ubicación con precisión insuficiente',
    () async {
      var config = const ConfiguracionAlertasProximidad(
        pushPromocionesActivadas: true,
      );
      final preferences = _FakePreferences(initial: config);
      final repository = _FakeRepository();
      final service = _service(
        userId: () => userA,
        preferences: preferences,
        repository: repository,
        now: () => now,
      );

      await service.evaluateFreshLocation(
        latitude: -0.2,
        longitude: -78.5,
        accuracyMeters: 20,
        observedAt: now.subtract(const Duration(seconds: 121)),
      );
      await service.evaluateFreshLocation(
        latitude: -0.2,
        longitude: -78.5,
        accuracyMeters: 100.1,
        observedAt: now,
      );
      expect(repository.evaluations, isEmpty);

      config = config.copiarCon(pushPromocionesActivadas: false);
      preferences.value = config;
      await service.evaluateFreshLocation(
        latitude: -0.2,
        longitude: -78.5,
        accuracyMeters: 20,
        observedAt: now,
      );
      expect(repository.evaluations, isEmpty);
      await service.dispose();
    },
  );

  test('no envía una posición si cambia la cuenta durante la carga de preferencias', () async {
    var userId = userA;
    final preferences = _FakePreferences(
      initial: const ConfiguracionAlertasProximidad(
        pushPromocionesActivadas: true,
      ),
    );
    final pending = Completer<ConfiguracionAlertasProximidad>();
    preferences.nextLoad = pending;
    final repository = _FakeRepository();
    final service = _service(
      userId: () => userId,
      preferences: preferences,
      repository: repository,
      now: () => now,
    );

    final evaluation = service.evaluateFreshLocation(
      latitude: -0.2,
      longitude: -78.5,
      accuracyMeters: 20,
      observedAt: now,
    );
    userId = userB;
    pending.complete(
      const ConfiguracionAlertasProximidad(pushPromocionesActivadas: true),
    );
    await evaluation;
    expect(repository.evaluations, isEmpty);
    await service.dispose();
  });

  test(
    'rechaza mensajes ajenos al tipo promoción o con identificadores inválidos',
    () {
      expect(
        FcmPromotionMessage.parse({
          'type': 'promotion',
          'event_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'promotion_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          'establishment_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        })?.promotionId,
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
      expect(
        FcmPromotionMessage.parse({'type': 'other', 'promotion_id': 'x'}),
        isNull,
      );
    },
  );
}

// Service logic is exercised with a test-only policy; the real policy is off.
class _EnabledTestPolicy extends FcmEnvironmentPolicy {
  const _EnabledTestPolicy() : super(staging: true, optIn: true, url: 'test');
  @override
  bool get enabled => true;
}

const stagingPolicy = _EnabledTestPolicy();

FcmPushService _service({
  required String? Function() userId,
  _FakeMessaging? messaging,
  _FakeRepository? repository,
  _FakePreferences? preferences,
  DateTime Function()? now,
}) => FcmPushService(
  currentUserId: userId,
  messaging: messaging ?? _FakeMessaging(),
  repository: repository ?? _FakeRepository(),
  preferences: preferences ?? _FakePreferences(),
  local: SharedPreferencesAsync(),
  now: now,
  policy: stagingPolicy,
);

class _FakeMessaging implements FcmMessagingGateway {
  int initializeCalls = 0;
  int disableCalls = 0;
  bool permitted = true;
  final tokenController = StreamController<String>.broadcast();
  final foregroundController =
      StreamController<FcmPromotionMessage>.broadcast();
  final openedController = StreamController<FcmPromotionMessage>.broadcast();

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return true;
  }

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}

  @override
  Future<String> register() async => 'firebase-installation-id-123456';

  @override
  Future<void> disableRegistration() async {
    disableCalls++;
  }

  @override
  Stream<String> get tokenRefreshes => tokenController.stream;

  @override
  Stream<FcmPromotionMessage> get foregroundMessages =>
      foregroundController.stream;

  @override
  Stream<FcmPromotionMessage> get openedMessages => openedController.stream;

  @override
  Future<FcmPromotionMessage?> getInitialMessage() async => null;
}

class _FakeRepository implements PushPromotionsRepository {
  bool failRevoke = false;
  final preferenceSaves = <ConfiguracionAlertasProximidad>[];
  final registrations =
      <({String installationId, String fcmInstallationId, String platform})>[];
  final evaluations = <({String installationId, String eventId})>[];
  final revocations = <String>[];
  Completer<void>? registrationCompleter;
  Completer<void>? registrationBlock;

  @override
  Future<void> savePreferences(ConfiguracionAlertasProximidad config) async {
    preferenceSaves.add(config);
  }

  @override
  Future<void> registerInstallation({
    required String installationId,
    required String fcmInstallationId,
    required String platform,
  }) async {
    registrations.add((
      installationId: installationId,
      fcmInstallationId: fcmInstallationId,
      platform: platform,
    ));
    if (registrationCompleter case final completer?) {
      registrationCompleter = null;
      completer.complete();
    }
    if (registrationBlock case final block?) {
      await block.future;
    }
  }

  @override
  Future<void> revokeInstallation(String installationId) async {
    if (failRevoke) throw StateError('offline');
    revocations.add(installationId);
  }

  @override
  Future<void> evaluateFreshLocation({
    required String installationId,
    required String eventId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
    required int utcOffsetMinutes,
  }) async {
    evaluations.add((installationId: installationId, eventId: eventId));
  }
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'expected asynchronous callback');
}

class _FakePreferences implements PreferenciasAlertasProximidadRepository {
  _FakePreferences({
    ConfiguracionAlertasProximidad initial =
        const ConfiguracionAlertasProximidad(),
  }) : value = initial;

  ConfiguracionAlertasProximidad value;
  Completer<ConfiguracionAlertasProximidad>? nextLoad;
  final changes = StreamController<ConfiguracionAlertasProximidad>.broadcast();

  @override
  Stream<ConfiguracionAlertasProximidad> get cambios => changes.stream;

  @override
  Future<ConfiguracionAlertasProximidad> cargar() {
    final pending = nextLoad;
    nextLoad = null;
    return pending?.future ?? Future.value(value);
  }

  @override
  Future<void> guardar(ConfiguracionAlertasProximidad config) async {
    value = config;
    changes.add(config);
  }
}
