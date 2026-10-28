import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class ConsentimientoUbicacion {
  static const _clave = 'cercly_uso_ubicacion_cercania_aceptado';
  static final _cambios = StreamController<bool>.broadcast();

  static Stream<bool> get cambios => _cambios.stream;

  static Future<bool> estaAceptado() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      return preferencias.getBool(_clave) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> aceptar() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setBool(_clave, true);
    _cambios.add(true);
  }

  static Future<void> revocar() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.remove(_clave);
    } catch (_) {
      // Si no hay almacenamiento disponible, Android aún permite revocar GPS.
    } finally {
      _cambios.add(false);
    }
  }
}
