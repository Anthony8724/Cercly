import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/configuracion_alertas_proximidad.dart';

abstract interface class PreferenciasAlertasProximidadRepository {
  Stream<ConfiguracionAlertasProximidad> get cambios;

  Future<ConfiguracionAlertasProximidad> cargar();

  Future<void> guardar(ConfiguracionAlertasProximidad configuracion);
}

class PreferenciasAlertasProximidadLocal
    implements PreferenciasAlertasProximidadRepository {
  PreferenciasAlertasProximidadLocal();

  static const _claveActivas = 'cercly.alertas_proximidad.activas.v1';
  static const _claveRadio = 'cercly.alertas_proximidad.radio_metros.v1';
  static final StreamController<ConfiguracionAlertasProximidad> _cambios =
      StreamController<ConfiguracionAlertasProximidad>.broadcast();

  @override
  Stream<ConfiguracionAlertasProximidad> get cambios => _cambios.stream;

  @override
  Future<ConfiguracionAlertasProximidad> cargar() async {
    final preferencias = await SharedPreferences.getInstance();
    final activas = preferencias.getBool(_claveActivas) ?? false;
    final radio = preferencias.getInt(_claveRadio);
    final radioValido = ConfiguracionAlertasProximidad.radiosDisponiblesMetros
        .contains(radio);

    return ConfiguracionAlertasProximidad(
      activadas: activas,
      radioMetros: radioValido
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
    if (!configuracion.activadas) {
      // Pausa el monitor inmediatamente, incluso si falla la escritura local.
      _cambios.add(configuracion);
      final guardado = await preferencias.setBool(_claveActivas, false);
      if (!guardado) {
        throw StateError('No se pudo persistir el estado desactivado.');
      }
      return;
    }

    // Primero se persiste el radio y al final el consentimiento. Si falla la
    // primera escritura, las alertas permanecen apagadas.
    final radioGuardado = await preferencias.setInt(
      _claveRadio,
      configuracion.radioMetros,
    );
    if (!radioGuardado) {
      throw StateError('No se pudo persistir el radio de alertas.');
    }
    final activacionGuardada = await preferencias.setBool(_claveActivas, true);
    if (!activacionGuardada) {
      throw StateError('No se pudo persistir el consentimiento de alertas.');
    }
    _cambios.add(configuracion);
  }

  Future<void> borrarDatosLocales() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveActivas);
    await preferencias.remove(_claveRadio);
    _cambios.add(const ConfiguracionAlertasProximidad());
  }
}
