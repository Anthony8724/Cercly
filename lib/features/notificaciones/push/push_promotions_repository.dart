import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/configuracion_alertas_proximidad.dart';

abstract interface class FreshLocationPushEvaluator {
  Future<void> evaluateFreshLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
  });
}

abstract interface class PushPromotionsRepository {
  Future<void> savePreferences(ConfiguracionAlertasProximidad config);
  Future<void> registerInstallation({
    required String installationId,
    required String fcmInstallationId,
    required String platform,
  });
  Future<void> revokeInstallation(String installationId);
  Future<void> evaluateFreshLocation({
    required String installationId,
    required String eventId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
    required int utcOffsetMinutes,
  });
}

class SupabasePushPromotionsRepository implements PushPromotionsRepository {
  SupabasePushPromotionsRepository({this._client});

  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  @override
  Future<void> savePreferences(ConfiguracionAlertasProximidad config) async {
    final descanso = config.horarioDescanso;
    await client.rpc(
      'configurar_mis_alertas_push_promociones',
      params: {
        'p_enabled': config.pushPromocionesActivadas,
        'p_location_consent': config.pushPromocionesActivadas,
        'p_daily_limit': config.frecuencia.maximoPorDia,
        'p_quiet_start_minutes': descanso?.inicioMinutos,
        'p_quiet_end_minutes': descanso?.finMinutos,
        'p_radius_meters': config.radioMetros,
      },
    );
  }

  @override
  Future<void> registerInstallation({
    required String installationId,
    required String fcmInstallationId,
    required String platform,
  }) async {
    await client.rpc(
      'registrar_mi_instalacion_fcm',
      params: {
        'p_installation_id': installationId,
        'p_fcm_installation_id': fcmInstallationId,
        'p_platform': platform,
      },
    );
  }

  @override
  Future<void> revokeInstallation(String installationId) async {
    await client.rpc(
      'retirar_mi_instalacion_fcm',
      params: {'p_installation_id': installationId},
    );
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
    final response = await client.functions.invoke(
      'evaluar-promocion-push',
      body: {
        'installation_id': installationId,
        'event_id': eventId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'observed_at': observedAt.toUtc().toIso8601String(),
        'utc_offset_minutes': utcOffsetMinutes,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('No se pudo evaluar la promoción push.');
    }
  }
}
