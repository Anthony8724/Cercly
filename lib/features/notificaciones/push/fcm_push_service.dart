import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/configuracion_alertas_proximidad.dart';
import '../services/preferencias_alertas_proximidad.dart';
import 'fcm_messaging_gateway.dart';
import 'fcm_promotion_message.dart';
import 'push_promotions_repository.dart';

enum FcmActivationResult {
  activated,
  consentRequired,
  signedOut,
  firebaseNotConfigured,
  permissionDenied,
}

class FcmPushService implements FreshLocationPushEvaluator {
  FcmPushService({
    SupabaseClient? client,
    FcmMessagingGateway? messaging,
    PushPromotionsRepository? repository,
    PreferenciasAlertasProximidadRepository? preferences,
    this._local,
    String? Function()? currentUserId,
    DateTime Function()? now,
  }) : _client = client,
       _messaging = messaging ?? FirebaseMessagingGateway(),
       _repository =
           repository ?? SupabasePushPromotionsRepository(client: client),
       _preferences = preferences ?? PreferenciasAlertasProximidadLocal(),
       _currentUserId =
           currentUserId ??
           (() => (client ?? Supabase.instance.client).auth.currentUser?.id),
       _now = now ?? DateTime.now;

  static final FcmPushService shared = FcmPushService();
  static const _installationIdKey = 'cercly.fcm.installation_id.v1';
  static const _pendingDisablePrefix = 'cercly.fcm.pending_disable.';

  final SupabaseClient? _client;
  final FcmMessagingGateway _messaging;
  final PushPromotionsRepository _repository;
  final PreferenciasAlertasProximidadRepository _preferences;
  final SharedPreferencesAsync? _local;
  SharedPreferencesAsync get _localPreferences =>
      _local ?? SharedPreferencesAsync();
  final String? Function() _currentUserId;
  final DateTime Function() _now;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<ConfiguracionAlertasProximidad>? _preferencesSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<FcmPromotionMessage>? _foregroundSubscription;
  StreamSubscription<FcmPromotionMessage>? _openedSubscription;
  String? _activeUserId;
  Future<void> Function(FcmPromotionMessage message)? _openPromotion;
  void Function(FcmPromotionMessage message)? _showForegroundMessage;
  final Set<String> _seenEvents = <String>{};

  Future<void> reconcileAfterResume() async {
    final userId = _currentUserId();
    if (userId == null) return;
    final config = await _preferences.cargar();
    if (_currentUserId() != userId || !config.pushPromocionesActivadas) return;
    final installationId = await _installationId();
    if (_currentUserId() != userId) return;

    if (!await _messaging.initialize()) {
      try {
        await _repository.revokeInstallation(installationId);
      } finally {
        await _stopListeners();
      }
      return;
    }
    if (!await _messaging.hasPermission()) {
      try {
        await _repository.revokeInstallation(installationId);
      } catch (_) {
        // The next foreground transition retries server-side revocation.
      } finally {
        await _stopListeners();
        try {
          await _messaging.disableRegistration();
        } catch (_) {
          // Local permission is already revoked by the operating system.
        }
      }
      _activeUserId = userId;
      return;
    }
    if (_activeUserId == userId && _tokenSubscription != null) return;

    try {
      if (_currentUserId() != userId) return;
      await _repository.savePreferences(config);
      await _messaging.setAutoInitEnabled(true);
      final fcmInstallationId = await _messaging.register();
      if (_currentUserId() != userId) return;
      final latest = await _preferences.cargar();
      if (_currentUserId() != userId ||
          !latest.pushPromocionesActivadas ||
          !await _messaging.hasPermission()) {
        await _repository.revokeInstallation(installationId);
        return;
      }
      await _repository.registerInstallation(
        installationId: installationId,
        fcmInstallationId: fcmInstallationId,
        platform: _platformName,
      );
      if (_currentUserId() == userId) await _startListeners(userId);
    } catch (_) {
      try {
        await _repository.revokeInstallation(installationId);
      } catch (_) {
        // A later foreground transition retries while no new fix is sent.
      }
    }
  }

  void observeAuthentication({
    required Future<void> Function(FcmPromotionMessage message) openPromotion,
    required void Function(FcmPromotionMessage message) showForegroundMessage,
  }) {
    _openPromotion = openPromotion;
    _showForegroundMessage = showForegroundMessage;
    if (_authSubscription != null) return;
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      unawaited(_handleAccount(state.session?.user.id));
    });
    _preferencesSubscription = _preferences.cambios.listen((config) {
      final userId = _currentUserId();
      if (userId != null && config.pushPromocionesActivadas) {
        unawaited(_syncPreferences(config, userId));
      }
    });
    unawaited(_handleAccount(_supabase.auth.currentUser?.id));
  }

  Future<FcmActivationResult> enablePromotionalPush({
    required bool explicitConsent,
  }) async {
    if (!explicitConsent) return FcmActivationResult.consentRequired;
    final userId = _currentUserId();
    if (userId == null) return FcmActivationResult.signedOut;
    if (!await _messaging.initialize()) {
      return FcmActivationResult.firebaseNotConfigured;
    }
    if (!await _messaging.requestPermission()) {
      return FcmActivationResult.permissionDenied;
    }
    if (_currentUserId() != userId) return FcmActivationResult.signedOut;

    final current = await _preferences.cargar();
    if (_currentUserId() != userId) return FcmActivationResult.signedOut;
    final enabled = current.copiarCon(pushPromocionesActivadas: true);
    await _preferences.guardar(enabled);
    try {
      if (_currentUserId() != userId) return FcmActivationResult.signedOut;
      await _repository.savePreferences(enabled);
      if (_currentUserId() != userId) return FcmActivationResult.signedOut;
      await _messaging.setAutoInitEnabled(true);
      final fcmInstallationId = await _messaging.register();
      if (_currentUserId() != userId) return FcmActivationResult.signedOut;
      if (fcmInstallationId.isEmpty) {
        throw StateError('Firebase no entregó un token para esta instalación.');
      }
      final installationId = await _installationId();
      if (_currentUserId() != userId) return FcmActivationResult.signedOut;
      await _repository.registerInstallation(
        installationId: installationId,
        fcmInstallationId: fcmInstallationId,
        platform: _platformName,
      );
      if (_currentUserId() != userId) {
        await _repository.revokeInstallation(installationId);
        return FcmActivationResult.signedOut;
      }
      await _startListeners(userId);
      return FcmActivationResult.activated;
    } catch (_) {
      if (_currentUserId() == userId) {
        await _preferences.guardar(
          enabled.copiarCon(pushPromocionesActivadas: false),
        );
        try {
          await _repository.savePreferences(
            enabled.copiarCon(pushPromocionesActivadas: false),
          );
        } catch (_) {
          await _markDisablePending(userId);
        }
      }
      try {
        await _messaging.disableRegistration();
      } catch (_) {
        // Local consent is off; remote token rows are revoked or scheduled.
      }
      rethrow;
    }
  }

  Future<void> disablePromotionalPush() async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('Inicia sesión para cambiar esta preferencia.');
    }
    final current = await _preferences.cargar();
    if (_currentUserId() != userId) {
      throw StateError('La sesión cambió antes de actualizar preferencias.');
    }
    final disabled = current.copiarCon(pushPromocionesActivadas: false);
    await _preferences.guardar(disabled);
    await _markDisablePending(userId);
    try {
      await _messaging.disableRegistration();
    } catch (_) {
      // Server-side revocation still runs even if Firebase unregister fails.
    }
    if (_currentUserId() != userId) {
      throw StateError('La sesión cambió antes de retirar la instalación.');
    }
    try {
      await _repository.savePreferences(disabled);
      if (_currentUserId() != userId) return;
      await _repository.revokeInstallation(await _installationId());
      await _clearDisablePending(userId);
      await _stopListeners();
    } catch (_) {
      // Local consent is already off. The durable marker retries server-side
      // revocation on the next authenticated launch.
      rethrow;
    }
  }

  Future<void> retireBeforeSignOut() async {
    final userId = _currentUserId();
    if (userId == null) return;
    final id = await _readInstallationId();
    if (id != null) await _repository.revokeInstallation(id);
    await _stopListeners();
    try {
      if (await _messaging.initialize()) {
        await _messaging.disableRegistration();
      }
    } catch (_) {
      // Supabase association was already retired; never block sign-out on SDK.
    }
    _activeUserId = null;
  }

  Future<void> retireAfterAccountDeletion() async {
    await _stopListeners();
    try {
      await _messaging.disableRegistration();
    } catch (_) {
      // The Auth cascade has already removed server-side installation rows.
      // Local cleanup must not turn a confirmed deletion into a failure.
    }
    _activeUserId = null;
  }

  @override
  Future<void> evaluateFreshLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
  }) async {
    final userId = _currentUserId();
    if (userId == null) return;
    final config = await _preferences.cargar();
    if (!config.pushPromocionesActivadas || _currentUserId() != userId) {
      return;
    }
    final now = _now();
    final age = now.difference(observedAt);
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !accuracyMeters.isFinite ||
        accuracyMeters <= 0 ||
        accuracyMeters > 100 ||
        age.isNegative ||
        age > const Duration(seconds: 120)) {
      return;
    }
    final installationId = await _installationId();
    if (_currentUserId() != userId) return;
    final latest = await _preferences.cargar();
    if (_currentUserId() != userId || !latest.pushPromocionesActivadas) return;
    await _repository.evaluateFreshLocation(
      installationId: installationId,
      eventId: _newUuid(),
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      observedAt: observedAt,
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _preferencesSubscription?.cancel();
    _preferencesSubscription = null;
    await _stopListeners();
  }

  Future<void> _handleAccount(String? userId) async {
    if (userId == _activeUserId) return;
    final previous = _activeUserId;
    await _stopListeners();
    _activeUserId = userId;
    if (previous != null && userId != null) {
      try {
        await _repository.revokeInstallation(await _installationId());
      } catch (_) {
        // The installation is not re-bound when cleanup cannot be confirmed.
        return;
      }
    }
    if (userId == null) return;
    final pending = await _isDisablePending(userId);
    if (pending) {
      try {
        final config = await _preferences.cargar();
        await _repository.savePreferences(
          config.copiarCon(pushPromocionesActivadas: false),
        );
        await _repository.revokeInstallation(await _installationId());
        await _clearDisablePending(userId);
      } catch (_) {
        return;
      }
    }
    final config = await _preferences.cargar();
    if (!config.pushPromocionesActivadas ||
        _currentUserId() != userId ||
        !await _messaging.initialize() ||
        _currentUserId() != userId ||
        !await _messaging.hasPermission() ||
        _currentUserId() != userId) {
      return;
    }
    try {
      await _repository.savePreferences(config);
      await _messaging.setAutoInitEnabled(true);
      final fcmInstallationId = await _messaging.register();
      if (_currentUserId() != userId) return;
      final installationId = await _installationId();
      if (_currentUserId() != userId) return;
      await _repository.registerInstallation(
        installationId: installationId,
        fcmInstallationId: fcmInstallationId,
        platform: _platformName,
      );
      await _startListeners(userId);
    } catch (_) {
      return;
    }
  }

  Future<void> _startListeners(String userId) async {
    await _stopListeners();
    _activeUserId = userId;
    _tokenSubscription = _messaging.tokenRefreshes.listen((token) {
      unawaited(_registerRefreshedToken(token, userId));
    });
    _foregroundSubscription = _messaging.foregroundMessages.listen((message) {
      unawaited(_handleForeground(message, userId));
    });
    _openedSubscription = _messaging.openedMessages.listen((message) {
      unawaited(_handleOpened(message, userId));
    });
    final initial = await _messaging.getInitialMessage();
    if (initial != null) await _handleOpened(initial, userId);
  }

  Future<void> _registerRefreshedToken(
    String fcmInstallationId,
    String userId,
  ) async {
    if (fcmInstallationId.isEmpty || _currentUserId() != userId) return;
    final config = await _preferences.cargar();
    if (!config.pushPromocionesActivadas || _currentUserId() != userId) {
      return;
    }
    final installationId = await _installationId();
    if (_currentUserId() != userId) return;
    await _repository.registerInstallation(
      installationId: installationId,
      fcmInstallationId: fcmInstallationId,
      platform: _platformName,
    );
  }

  Future<void> _syncPreferences(
    ConfiguracionAlertasProximidad config,
    String userId,
  ) async {
    if (_currentUserId() != userId) return;
    try {
      await _repository.savePreferences(config);
    } catch (_) {
      // The local choice remains in effect; the next authenticated launch
      // retries synchronization before registering the installation.
    }
  }

  Future<void> _handleForeground(
    FcmPromotionMessage message,
    String userId,
  ) async {
    if (!_markEventSeen(message.eventId) || _currentUserId() != userId) {
      return;
    }
    final config = await _preferences.cargar();
    if (config.pushPromocionesActivadas && _currentUserId() == userId) {
      _showForegroundMessage?.call(message);
    }
  }

  Future<void> _handleOpened(FcmPromotionMessage message, String userId) async {
    if (!_markEventSeen(message.eventId) || _currentUserId() != userId) {
      return;
    }
    final config = await _preferences.cargar();
    if (config.pushPromocionesActivadas && _currentUserId() == userId) {
      await _openPromotion?.call(message);
    }
  }

  bool _markEventSeen(String id) {
    if (!_seenEvents.add(id)) return false;
    if (_seenEvents.length > 128) _seenEvents.remove(_seenEvents.first);
    return true;
  }

  Future<void> _stopListeners() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _seenEvents.clear();
  }

  Future<String> _installationId() async {
    final existing = await _readInstallationId();
    if (existing != null) return existing;
    final generated = _newUuid();
    await _localPreferences.setString(_installationIdKey, generated);
    return generated;
  }

  Future<String?> _readInstallationId() async {
    final value = await _localPreferences.getString(_installationIdKey);
    return value != null && FcmPromotionMessage.isUuid(value)
        ? value.toLowerCase()
        : null;
  }

  Future<void> _markDisablePending(String userId) =>
      _localPreferences.setBool('$_pendingDisablePrefix$userId', true);

  Future<bool> _isDisablePending(String userId) async =>
      await _localPreferences.getBool('$_pendingDisablePrefix$userId') ?? false;

  Future<void> _clearDisablePending(String userId) =>
      _localPreferences.remove('$_pendingDisablePrefix$userId');

  String get _platformName => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };

  static String _newUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
