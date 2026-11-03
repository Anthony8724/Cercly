import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class GeofencingExperimentalStatus {
  const GeofencingExperimentalStatus({
    this.available = false,
    this.foregroundLocation = false,
    this.preciseLocation = false,
    this.backgroundLocation = false,
    this.notifications = false,
    this.notificationChannel = false,
    this.googlePlayServices = false,
    this.locationEnabled = false,
    this.foregroundAlerts = false,
    this.consent = false,
    this.registered = false,
    this.expiresAt = 0,
    this.registrationState = 'not_registered',
    this.promotionCooldownRemainingMs = 0,
    this.globalCooldownRemainingMs = 0,
    this.dailyNotificationCount = 0,
    this.dailyRemaining = 3,
    this.lastAndroidEventAt = 0,
    this.lastAndroidEventResult = '',
    this.lastAndroidEnterAt = 0,
    this.lastAndroidExitAt = 0,
    this.lastNativeError = '',
    this.lastRealEntryNotificationAt = 0,
    this.lastRealEntryNotificationResult = '',
    this.screenLockQaScheduledAt = 0,
    this.screenLockQaDueAt = 0,
    this.screenLockQaDeliveredAt = 0,
    this.screenLockQaResult = '',
    this.lastSimulationAt = 0,
    this.lastSimulationResult = '',
    this.lastQaReceiverSignalAt = 0,
  });

  final bool available;
  final bool foregroundLocation;
  final bool preciseLocation;
  final bool backgroundLocation;
  final bool notifications;
  final bool notificationChannel;
  final bool googlePlayServices;
  final bool locationEnabled;
  final bool foregroundAlerts;
  final bool consent;
  final bool registered;
  final int expiresAt;
  final String registrationState;
  final int promotionCooldownRemainingMs;
  final int globalCooldownRemainingMs;
  final int dailyNotificationCount;
  final int dailyRemaining;
  final int lastAndroidEventAt;
  final String lastAndroidEventResult;
  final int lastAndroidEnterAt;
  final int lastAndroidExitAt;
  final String lastNativeError;
  final int lastRealEntryNotificationAt;
  final String lastRealEntryNotificationResult;
  final int screenLockQaScheduledAt;
  final int screenLockQaDueAt;
  final int screenLockQaDeliveredAt;
  final String screenLockQaResult;
  final int lastSimulationAt;
  final String lastSimulationResult;
  final int lastQaReceiverSignalAt;

  factory GeofencingExperimentalStatus.fromMap(
    Map<Object?, Object?>? map,
  ) => GeofencingExperimentalStatus(
    available: map?['available'] == true,
    foregroundLocation: map?['foregroundLocation'] == true,
    preciseLocation: map?['preciseLocation'] == true,
    backgroundLocation: map?['backgroundLocation'] == true,
    notifications: map?['notifications'] == true,
    notificationChannel: map?['notificationChannel'] == true,
    googlePlayServices: map?['googlePlayServices'] == true,
    locationEnabled: map?['locationEnabled'] == true,
    foregroundAlerts: map?['foregroundAlerts'] == true,
    consent: map?['consent'] == true,
    registered: map?['registered'] == true,
    expiresAt: map?['expiresAt'] is int ? map!['expiresAt']! as int : 0,
    registrationState: map?['registrationState'] as String? ?? 'unknown',
    promotionCooldownRemainingMs: _asInt(map?['promotionCooldownRemainingMs']),
    globalCooldownRemainingMs: _asInt(map?['globalCooldownRemainingMs']),
    dailyNotificationCount: _asInt(map?['dailyNotificationCount']),
    dailyRemaining: _asInt(map?['dailyRemaining'], fallback: 3),
    lastAndroidEventAt: _asInt(map?['lastAndroidEventAt']),
    lastAndroidEventResult: map?['lastAndroidEventResult'] as String? ?? '',
    lastAndroidEnterAt: _asInt(map?['lastAndroidEnterAt']),
    lastAndroidExitAt: _asInt(map?['lastAndroidExitAt']),
    lastNativeError: map?['lastNativeError'] as String? ?? '',
    lastRealEntryNotificationAt: _asInt(map?['lastRealEntryNotificationAt']),
    lastRealEntryNotificationResult:
        map?['lastRealEntryNotificationResult'] as String? ?? '',
    screenLockQaScheduledAt: _asInt(map?['screenLockQaScheduledAt']),
    screenLockQaDueAt: _asInt(map?['screenLockQaDueAt']),
    screenLockQaDeliveredAt: _asInt(map?['screenLockQaDeliveredAt']),
    screenLockQaResult: map?['screenLockQaResult'] as String? ?? '',
    lastSimulationAt: _asInt(map?['lastSimulationAt']),
    lastSimulationResult: map?['lastSimulationResult'] as String? ?? '',
    lastQaReceiverSignalAt: _asInt(map?['lastQaReceiverSignalAt']),
  );

  static int _asInt(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : fallback;
}

class GeofencingExperimentalService {
  GeofencingExperimentalService({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('cercly/geofence_experiment'),
      _enabled = enabled ?? staging;

  static const bool staging = bool.fromEnvironment('CERCLY_STAGING');
  static const establishmentId = 'f14a1f14-14b0-4b14-8a14-140000000001';
  static const promotionId = 'f14a1f14-14b0-4b14-8a14-140000000002';
  final MethodChannel _channel;
  final bool _enabled;

  Future<GeofencingExperimentalStatus> status() async {
    if (!_enabled) return const GeofencingExperimentalStatus();
    final result = await _channel.invokeMapMethod<Object?, Object?>('status');
    return GeofencingExperimentalStatus.fromMap(result);
  }

  Future<void> setConsent(bool enabled) async {
    if (_enabled) {
      await _channel.invokeMethod<void>('setConsent', {'enabled': enabled});
    }
  }

  Future<String> register({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required DateTime expiresAt,
    required String establishmentName,
    required String promotionTitle,
  }) async {
    if (!_enabled) return 'unavailable';
    if (!expiresAt.isAfter(DateTime.now())) return 'promotion_expired';
    if (radiusMeters < 100 || radiusMeters > 5000) return 'invalid_geofence';
    return await _channel.invokeMethod<String>('register', {
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'expiresAt': expiresAt.millisecondsSinceEpoch,
          'establishmentName': establishmentName,
          'promotionTitle': promotionTitle,
        }) ??
        'registration_error';
  }

  Future<void> remove() async {
    if (_enabled) await _channel.invokeMethod<void>('remove');
  }

  Future<bool> openAppSettings() async => _enabled
      ? await _channel.invokeMethod<bool>('openAppSettings') ?? false
      : false;

  Future<String?> consumePendingNotification() async => _enabled
      ? _channel.invokeMethod<String>('consumePendingNotification')
      : null;

  Future<bool> resetQaCooldown() async => _enabled
      ? await _channel.invokeMethod<bool>('resetQaCooldown') ?? false
      : false;

  Future<void> recordSimulationResult(String result) async {
    if (_enabled) {
      await _channel.invokeMethod<void>('recordSimulationResult', {
        'result': result,
      });
    }
  }

  Future<bool> sendQaReceiverSignal() async => _enabled
      ? await _channel.invokeMethod<bool>('sendQaReceiverSignal') ?? false
      : false;

  Future<String> scheduleScreenLockQa() async => _enabled
      ? await _channel.invokeMethod<String>('scheduleScreenLockQa') ??
            'scheduling_error'
      : 'unavailable';

  Future<bool> cancelScreenLockQa() async => _enabled
      ? await _channel.invokeMethod<bool>('cancelScreenLockQa') ?? false
      : false;
}
