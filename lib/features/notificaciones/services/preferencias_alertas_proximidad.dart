import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/configuracion_alertas_proximidad.dart';
import 'production_geofencing_service.dart';

abstract interface class PreferenciasAlertasProximidadRepository {
  Stream<ConfiguracionAlertasProximidad> get cambios;

  Future<ConfiguracionAlertasProximidad> cargar();

  Future<void> guardar(ConfiguracionAlertasProximidad configuracion);
}

class PreferenciasAlertasProximidadLocal
    implements PreferenciasAlertasProximidadRepository {
  PreferenciasAlertasProximidadLocal({String? Function()? usuarioId})
    : _usuarioId = usuarioId ?? _usuarioActual;

  static const _claveConfiguracion = 'cercly.alertas_proximidad.config.v2';
  static const _claveActivas = 'cercly.alertas_proximidad.activas.v1';
  static const _claveRadio = 'cercly.alertas_proximidad.radio_metros.v1';
  static final StreamController<ConfiguracionAlertasProximidad> _cambios =
      StreamController<ConfiguracionAlertasProximidad>.broadcast();
  final String? Function() _usuarioId;

  static String? _usuarioActual() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String _clavePara(String? usuario) => usuario == null || usuario.isEmpty
      ? _claveConfiguracion
      : '$_claveConfiguracion.usuario.$usuario';

  @override
  Stream<ConfiguracionAlertasProximidad> get cambios => _cambios.stream;

  @override
  Future<ConfiguracionAlertasProximidad> cargar() async {
    final preferencias = await SharedPreferences.getInstance();
    final usuario = _usuarioId();
    final contenido = preferencias.getString(_clavePara(usuario));
    if (contenido != null) {
      try {
        final datos = jsonDecode(contenido);
        if (datos is! Map<String, dynamic> || datos['version'] != 2) {
          return const ConfiguracionAlertasProximidad();
        }
        final radio = datos['radio_metros'];
        if (radio is! int ||
            !ConfiguracionAlertasProximidad.radiosDisponiblesMetros.contains(
              radio,
            )) {
          return const ConfiguracionAlertasProximidad();
        }
        final frecuencia = FrecuenciaAlertasProximidad.values
            .where((valor) => valor.name == datos['frecuencia'])
            .firstOrNull;
        if (frecuencia == null) return const ConfiguracionAlertasProximidad();
        final descanso = datos['descanso'];
        HorarioDescanso? horario;
        if (descanso != null) {
          if (descanso is! Map) return const ConfiguracionAlertasProximidad();
          final inicio = descanso['inicio'];
          final fin = descanso['fin'];
          if (inicio is! int ||
              fin is! int ||
              inicio < 0 ||
              inicio >= 1440 ||
              fin < 0 ||
              fin >= 1440 ||
              inicio == fin) {
            return const ConfiguracionAlertasProximidad();
          }
          horario = HorarioDescanso(inicioMinutos: inicio, finMinutos: fin);
        }
        return ConfiguracionAlertasProximidad(
          activadas: datos['activadas'] == true,
          radioMetros: radio,
          frecuencia: frecuencia,
          horarioDescanso: horario,
        );
      } on FormatException {
        return const ConfiguracionAlertasProximidad();
      }
    }
    // Las claves v1 no tienen propietario. Solo sirven para el modo sin
    // sesión; nunca se hereda consentimiento de otra cuenta.
    if (usuario != null) return const ConfiguracionAlertasProximidad();
    final radio = preferencias.getInt(_claveRadio);
    return ConfiguracionAlertasProximidad(
      activadas: preferencias.getBool(_claveActivas) ?? false,
      radioMetros:
          ConfiguracionAlertasProximidad.radiosDisponiblesMetros.contains(radio)
          ? radio!
          : ConfiguracionAlertasProximidad.radioPredeterminadoMetros,
    );
  }

  @override
  Future<void> guardar(ConfiguracionAlertasProximidad configuracion) async {
    if (!ConfiguracionAlertasProximidad.radiosDisponiblesMetros.contains(
      configuracion.radioMetros,
    )) {
      throw ArgumentError.value(
        configuracion.radioMetros,
        'radioMetros',
        'Radio de alertas no permitido.',
      );
    }

    final preferencias = await SharedPreferences.getInstance();
    final usuario = _usuarioId();
    if (!configuracion.activadas) {
      if (const bool.fromEnvironment('CERCLY_STAGING') ||
          ProductionGeofencingService.enabledBuild) {
        try {
          const canal = MethodChannel(
            ProductionGeofencingService.enabledBuild
                ? ProductionGeofencingService.channelName
                : 'cercly/geofence_experiment',
          );
          await canal.invokeMethod<void>('setConsent', {'enabled': false});
          await canal.invokeMethod<void>('remove');
        } on MissingPluginException {
          // El flujo foreground sigue siendo independiente de Android nativo.
        } on PlatformException {
          // La preferencia local se apaga igual; el receiver omite cualquier evento.
        }
      }
    }
    final datos = <String, Object?>{
      'version': 2,
      'activadas': configuracion.activadas,
      'radio_metros': configuracion.radioMetros,
      'frecuencia': configuracion.frecuencia.name,
      'descanso': configuracion.horarioDescanso == null
          ? null
          : <String, int>{
              'inicio': configuracion.horarioDescanso!.inicioMinutos,
              'fin': configuracion.horarioDescanso!.finMinutos,
            },
    };
    if (!await preferencias.setString(_clavePara(usuario), jsonEncode(datos))) {
      throw StateError('No se pudo persistir la configuración de alertas.');
    }
    // Los candidatos nativos privados todavía consultan las claves v1.
    if (const bool.fromEnvironment('CERCLY_STAGING') ||
        ProductionGeofencingService.enabledBuild) {
      await preferencias.setInt(_claveRadio, configuracion.radioMetros);
      await preferencias.setBool(_claveActivas, configuracion.activadas);
    }
    _cambios.add(configuracion);
  }

  Future<void> borrarDatosLocales() async {
    if (ProductionGeofencingService.enabledBuild) {
      await ProductionGeofencingService().setConsent(false);
    }
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_clavePara(_usuarioId()));
    await preferencias.remove(_claveActivas);
    await preferencias.remove(_claveRadio);
    _cambios.add(const ConfiguracionAlertasProximidad());
  }
}
