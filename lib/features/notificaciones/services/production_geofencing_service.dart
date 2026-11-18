import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../explorar/services/ubicacion_service.dart';
import '../../promociones/models/promocion_destacada_model.dart';
import '../../promociones/services/promocion_publica_service.dart';
import '../models/configuracion_alertas_proximidad.dart';
import 'historial_notificaciones_promocion.dart';
import 'geofence_authorization_gate.dart';
import 'session_notification_barrier.dart';
import 'preferencias_alertas_proximidad.dart';

/// Compile-time private candidate. No QA methods or fixed establishment IDs.
class ProductionGeofencingService {
  ProductionGeofencingService({
    MethodChannel? channel,
    bool? enabled,
    bool? staging,
    String? Function()? currentUserId,
    this.configuration,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _enabled = enabled ?? enabledBuild,
       _staging = staging ?? stagingBuild,
       _currentUserId = currentUserId ?? _authenticatedUserId;
  static const stagingBuild = bool.fromEnvironment('CERCLY_STAGING');
  // Production remains disabled until a separate native/device validation.
  static const enabledBuild = stagingBuild;
  static const channelName = stagingBuild
      ? 'cercly/staging_promotional_geofencing'
      : 'cercly/production_proximity';
  final MethodChannel _channel;
  final bool _enabled;
  final bool _staging;
  final String? Function() _currentUserId;
  final Future<ConfiguracionAlertasProximidad> Function()? configuration;
  static bool _syncing = false;
  static DateTime? _lastSync;

  Future<Map<Object?, Object?>> status() async => _enabled
      ? await _channel.invokeMapMethod<Object?, Object?>('status') ?? {}
      : {};
  Future<bool> setConsent(bool enabled) async {
    if (!_enabled) return false;
    if (_staging) {
      return await _channel.invokeMethod<bool>('setConsent', {
            'enabled': enabled,
          }) ==
          true;
    }
    // Disable locally before attempting network revocation.
    if (!enabled) {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (!await GeofenceAuthorizationGate.block()) return false;
      if (session == null ||
          client.auth.currentSession?.accessToken != session.accessToken) {
        return false;
      }
      final local =
          await _channel.invokeMethod<bool>('setConsent', {'enabled': false}) ==
          true;
      try {
        if (client.auth.currentSession?.accessToken != session.accessToken) {
          return false;
        }
        await client.rpc(
          'configurar_mis_alertas_geofencing',
          params: {'p_enabled': false, 'p_location_consent': false},
        );
        return local;
      } catch (_) {
        return false;
      }
    }
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return false;
    try {
      await client.rpc(
        'configurar_mis_alertas_geofencing',
        params: {'p_enabled': true, 'p_location_consent': true},
      );
      if (client.auth.currentSession?.accessToken != session.accessToken) {
        return false;
      }
      if (await _channel.invokeMethod<bool>('setConsent', {'enabled': true}) !=
          true) {
        return false;
      }
      if (!await updateSession(session)) {
        await _channel.invokeMethod<bool>('setConsent', {'enabled': false});
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSession(Session session) async {
    if (!_enabled || _staging) return false;
    final current = Supabase.instance.client.auth.currentSession;
    if (current == null || current.accessToken != session.accessToken) {
      return false;
    }
    final sessionId = SessionNotificationBarrier.sessionId(session);
    if (sessionId == null || SessionNotificationBarrier.blocked) return false;
    if (await _channel.invokeMethod<bool>('setAccessToken', {
          'userId': session.user.id,
          'accessToken': session.accessToken,
        }) !=
        true) {
      return false;
    }
    return GeofenceAuthorizationGate.arm(
      userId: session.user.id,
      sessionId: sessionId,
      stillAuthorized: () =>
          !SessionNotificationBarrier.blocked &&
          Supabase.instance.client.auth.currentSession?.accessToken ==
              session.accessToken,
    );
  }

  /// Acknowledgement is serialized with the native notification posting lock.
  /// A false result must never be interpreted as a confirmed native logout.
  Future<bool> retireLocalSession({
    required String? expectedUserId,
    required String? expectedSessionId,
  }) async {
    if (!_enabled || _staging) return false;
    return await _channel.invokeMethod<bool>('retireLocalSession', {
          'expectedUserId': expectedUserId,
          'expectedSessionId': expectedSessionId,
        }) ==
        true;
  }

  Future<bool> accountChanged(
    String? userId, {
    String? expectedUserId,
    String? expectedSessionId,
  }) async {
    if (!_enabled) return false;
    return await _channel.invokeMethod<bool>('accountChanged', {
          'userId': userId,
          'expectedUserId': ?expectedUserId,
          'expectedSessionId': ?expectedSessionId,
        }) ==
        true;
  }

  Future<bool> openSettings() async =>
      _enabled && await _channel.invokeMethod<bool>('openAppSettings') == true;
  Future<bool> requestForegroundPermissions() async =>
      _enabled &&
      await _channel.invokeMethod<bool>('requestForegroundPermissions') == true;
  Future<bool> requestBackgroundPermission() async =>
      _enabled &&
      await _channel.invokeMethod<bool>('requestBackgroundPermission') == true;
  Future<void> remove() async {
    if (_enabled) await _channel.invokeMethod<void>('remove');
  }

  Future<bool> prepareHistory({
    HistorialNotificacionesPromocion? history,
  }) async {
    if (!_enabled) return false;
    final userId = _currentUserId();
    if (_staging && userId == null) return false;
    final old =
        await (history ??
                HistorialNotificacionesPromocionLocal(
                  usuarioId: _staging ? () => userId : null,
                ))
            .cargar();
    if (!_staging) {
      return await _channel.invokeMethod<bool>('importHistory', {
            'last': old.ultimaPorPromocion.map(
              (id, time) => MapEntry(id, time.millisecondsSinceEpoch),
            ),
            'recent': old.recientes
                .map((time) => time.millisecondsSinceEpoch)
                .toList(),
          }) ==
          true;
    }
    final settings =
        await (configuration?.call() ??
            PreferenciasAlertasProximidadLocal().cargar());
    final quiet = settings.horarioDescanso;
    return await _channel.invokeMethod<bool>('importHistory', {
          'userId': userId,
          'last': old.ultimaPorPromocion.map(
            (id, time) => MapEntry(id, time.millisecondsSinceEpoch),
          ),
          'business': old.ultimaPorEstablecimiento.map(
            (id, time) => MapEntry(id, time.millisecondsSinceEpoch),
          ),
          'recent': old.recientes
              .map((time) => time.millisecondsSinceEpoch)
              .toList(),
          'dailyLimit': settings.frecuencia.maximoPorDia,
          'quietStart': quiet?.inicioMinutos,
          'quietEnd': quiet?.finMinutos,
        }) ==
        true;
  }

  static String? _authenticatedUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, Object>> selectZones(
    List<PromocionDestacadaModel> promotions,
    int userRadius,
    DateTime now,
    String userId,
  ) {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
    );
    final eligible =
        promotions
            .where(
              (p) =>
                  p.activa &&
                  p.estaVigenteEn(now) &&
                  p.fechaFin.isAfter(now) &&
                  uuid.hasMatch(p.id) &&
                  uuid.hasMatch(p.establecimientoId) &&
                  p.latitud.isFinite &&
                  p.longitud.isFinite &&
                  p.latitud.abs() <= 90 &&
                  p.longitud.abs() <= 180 &&
                  p.distanciaMetros != null &&
                  p.distanciaMetros!.isFinite &&
                  p.distanciaMetros! >= 0 &&
                  p.distanciaMetros! <= 25000 &&
                  math.min(p.radioAlertaMetros, userRadius) >= 100,
            )
            .toList()
          ..sort((a, b) => a.distanciaMetros!.compareTo(b.distanciaMetros!));
    final ids = <String>{};
    return eligible
        .where((p) => ids.add(p.id))
        .take(20)
        .map(
          (p) => <String, Object>{
            'id': p.id,
            'business': p.establecimientoId,
            'userId': userId,
            'lat': p.latitud,
            'lon': p.longitud,
            'radius': math.min(5000, math.min(p.radioAlertaMetros, userRadius)),
            'expires': math.min(
              p.fechaFin.millisecondsSinceEpoch,
              now.add(const Duration(days: 7)).millisecondsSinceEpoch,
            ),
          },
        )
        .toList();
  }

  Future<String> registerZones(List<Map<String, Object>> zones) async {
    if (!_enabled) return 'unavailable';
    return await _channel.invokeMethod<String>('register', {
          'zones': jsonEncode(zones),
        }) ??
        'registration_failed';
  }

  /// One location fix while visible. Saved geometry belongs to public businesses.
  Future<String> synchronize({bool automatic = false}) async {
    if (!_enabled) return 'unavailable';
    if (_syncing) return 'sync_busy';
    _syncing = true;
    try {
      final s = await status();
      if (![
        'consent',
        'foregroundAlerts',
        'precise',
        'background',
        'notifications',
        'location',
        'gms',
      ].every((key) => s[key] == true)) {
        if ((s['zoneCount'] as num? ?? 0) > 0) await remove();
        return 'authorization_required';
      }
      if (automatic &&
          s['registration'] == 'accepted_by_gms' &&
          (s['zoneCount'] as num? ?? 0) > 0 &&
          _lastSync != null &&
          DateTime.now().difference(_lastSync!) < const Duration(minutes: 15)) {
        return 'sync_recent';
      }

      if (!await prepareHistory()) return 'storage_error';
      final position =
          (await GeolocatorUbicacionService().obtenerUbicacion()).ubicacion;
      if (position == null ||
          position.precisionMetros == null ||
          position.precisionMetros! > 200) {
        return 'location_unavailable';
      }
      final settings = await PreferenciasAlertasProximidadLocal().cargar();
      final userId = _currentUserId();
      if (userId == null) {
        await remove();
        return 'authentication_required';
      }
      final promotions = await PromocionPublicaService().listarVigentes(
        latitudUsuario: position.latitud,
        longitudUsuario: position.longitud,
        radioMaximoMetros: 25000,
        resolverImagenes: false,
      );
      final outcome = await registerZones(
        selectZones(promotions, settings.radioMetros, DateTime.now(), userId),
      );
      _lastSync = DateTime.now();
      return outcome;
    } catch (_) {
      return 'query_or_registration_error';
    } finally {
      _syncing = false;
    }
  }
}
