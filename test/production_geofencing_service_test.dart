import 'dart:convert';

import 'package:cercly/features/notificaciones/services/production_geofencing_service.dart';
import 'package:cercly/features/notificaciones/services/historial_notificaciones_promocion.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _History implements HistorialNotificacionesPromocion {
  @override
  Future<HistorialNotificacionesPromocionDatos> cargar() async =>
      HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: {
          '12345678-abcd-abcd-abcd-123456789abc':
              DateTime.fromMillisecondsSinceEpoch(100),
        },
        recientes: [DateTime.fromMillisecondsSinceEpoch(100)],
      );
  @override
  Future<void> guardar(HistorialNotificacionesPromocionDatos historial) async =>
      throw StateError('Migration must not overwrite old history');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/production');
  final calls = <MethodCall>[];
  var permissions = true;
  var consent = true;
  final now = DateTime.utc(2026, 11, 3);
  PromocionDestacadaModel promotion({
    int n = 1,
    bool active = true,
    DateTime? end,
    double distance = 1000,
    int radius = 5000,
    double lat = 0,
  }) => PromocionDestacadaModel(
    id: '${n.toString().padLeft(8, '0')}-abcd-abcd-abcd-123456789abc',
    establecimientoId: '12345678-abcd-abcd-abcd-123456789abc',
    establecimientoNombre: 'Public business',
    categoriaNombre: 'Comercio',
    titulo: 'Promoción',
    descripcion: '',
    fechaInicio: now.subtract(const Duration(days: 1)),
    fechaFin: end ?? now.add(const Duration(days: 20)),
    radioAlertaMetros: radius,
    latitud: lat,
    longitud: 0,
    activa: active,
    distanciaMetros: distance,
  );
  setUp(() {
    calls.clear();
    permissions = true;
    consent = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'status' => {
              'consent': consent,
              'foregroundAlerts': true,
              'precise': permissions,
              'background': permissions,
              'notifications': permissions,
              'location': true,
              'gms': true,
              'zoneCount': 1,
            },
            'setConsent' || 'importHistory' => true,
            'register' => 'accepted_by_gms',
            _ => null,
          };
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('public default never calls private native channel', () async {
    final service = ProductionGeofencingService(
      channel: channel,
      enabled: false,
    );
    expect(await service.status(), isEmpty);
    expect(await service.setConsent(true), false);
    expect(await service.registerZones([]), 'unavailable');
    expect(calls, isEmpty);
  });
  test('explicit consent travels independently and can be revoked', () async {
    final service = ProductionGeofencingService(
      channel: channel,
      enabled: true,
    );
    await service.setConsent(true);
    await service.setConsent(false);
    expect(calls.map((c) => c.arguments['enabled']), [true, false]);
  });
  test(
    'denied permission removes saved zones without requesting permission',
    () async {
      permissions = false;
      expect(
        await ProductionGeofencingService(
          channel: channel,
          enabled: true,
        ).synchronize(),
        'authorization_required',
      );
      expect(calls.map((c) => c.method), ['status', 'remove']);
    },
  );
  test('no background consent prevents network and registration', () async {
    consent = false;
    expect(
      await ProductionGeofencingService(
        channel: channel,
        enabled: true,
      ).synchronize(),
      'authorization_required',
    );
    expect(calls.any((c) => c.method == 'register'), false);
  });
  test('existing history imports without clearing original cooldown', () async {
    expect(
      await ProductionGeofencingService(
        channel: channel,
        enabled: true,
      ).prepareHistory(history: _History()),
      true,
    );
    expect(calls.single.arguments['recent'], [100]);
    expect((calls.single.arguments['last'] as Map).values.single, 100);
  });
  test('dynamic business payload radius and finite expiry preserved', () async {
    final zones = ProductionGeofencingService.selectZones(
      [promotion()],
      500,
      now,
    );
    await ProductionGeofencingService(
      channel: channel,
      enabled: true,
    ).registerZones(zones);
    final zone =
        (jsonDecode(calls.single.arguments['zones'] as String) as List).single
            as Map;
    expect(zone['business'], promotion().establecimientoId);
    expect(zone['radius'], 500);
    expect(
      zone['expires'],
      now.add(const Duration(days: 7)).millisecondsSinceEpoch,
    );
  });
  test('expired inactive and invalid geometry excluded', () {
    expect(
      ProductionGeofencingService.selectZones(
        [promotion(end: now), promotion(active: false), promotion(lat: 91)],
        500,
        now,
      ),
      isEmpty,
    );
  });
  test('radius below native minimum and remote zones excluded', () {
    expect(
      ProductionGeofencingService.selectZones(
        [promotion(radius: 50), promotion(distance: 25001)],
        500,
        now,
      ),
      isEmpty,
    );
  });
  test('selects at most twenty nearest zones without duplicate IDs', () {
    final list = List.generate(
      30,
      (i) => promotion(n: i + 1, distance: 3000 - i * 10),
    );
    final zones = ProductionGeofencingService.selectZones(
      [...list, list.last],
      5000,
      now,
    );
    expect(zones.length, 20);
    expect(zones.first['id'], list.last.id);
  });
}
