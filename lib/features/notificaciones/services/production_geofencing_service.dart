import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../explorar/services/ubicacion_service.dart';
import '../../promociones/models/promocion_destacada_model.dart';
import '../../promociones/services/promocion_publica_service.dart';
import 'historial_notificaciones_promocion.dart';
import 'preferencias_alertas_proximidad.dart';

/// Compile-time private candidate. No QA methods or fixed establishment IDs.
class ProductionGeofencingService {
  ProductionGeofencingService({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel(channelName),
      _enabled = enabled ?? enabledBuild;
  static const enabledBuild = bool.fromEnvironment('CERCLY_PRIVATE_PROXIMITY');
  static const channelName = 'cercly/production_proximity';
  final MethodChannel _channel;
  final bool _enabled;
  static bool _syncing = false;
  static DateTime? _lastSync;

  Future<Map<Object?, Object?>> status() async => _enabled
      ? await _channel.invokeMapMethod<Object?, Object?>('status') ?? {}
      : {};
  Future<bool> setConsent(bool enabled) async =>
      _enabled &&
      await _channel.invokeMethod<bool>('setConsent', {'enabled': enabled}) ==
          true;
  Future<bool> openSettings() async =>
      _enabled && await _channel.invokeMethod<bool>('openAppSettings') == true;
  Future<void> remove() async {
    if (_enabled) await _channel.invokeMethod<void>('remove');
  }

  Future<bool> prepareHistory({
    HistorialNotificacionesPromocion? history,
  }) async {
    if (!_enabled) return false;
    final old = await (history ?? HistorialNotificacionesPromocionLocal())
        .cargar();
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

  static List<Map<String, Object>> selectZones(
    List<PromocionDestacadaModel> promotions,
    int userRadius,
    DateTime now,
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
    if (automatic &&
        _lastSync != null &&
        DateTime.now().difference(_lastSync!) < const Duration(minutes: 15)) {
      return 'sync_recent';
    }
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
      if (!await prepareHistory()) return 'storage_error';
      final position =
          (await GeolocatorUbicacionService().obtenerUbicacion()).ubicacion;
      if (position == null ||
          position.precisionMetros == null ||
          position.precisionMetros! > 200) {
        return 'location_unavailable';
      }
      final settings = await PreferenciasAlertasProximidadLocal().cargar();
      final promotions = await PromocionPublicaService().listarVigentes(
        latitudUsuario: position.latitud,
        longitudUsuario: position.longitud,
        radioMaximoMetros: 25000,
        resolverImagenes: false,
      );
      final outcome = await registerZones(
        selectZones(promotions, settings.radioMetros, DateTime.now()),
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
