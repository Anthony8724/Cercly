import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class HistorialNotificacionesPromocion {
  Future<Map<String, DateTime>> cargar();

  Future<void> guardar(Map<String, DateTime> historial);
}

class HistorialNotificacionesPromocionLocal
    implements HistorialNotificacionesPromocion {
  HistorialNotificacionesPromocionLocal({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _clave =
      'cercly.notificaciones.promociones.ultima_notificacion.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<Map<String, DateTime>> cargar() async {
    final contenido = await _preferences.getString(_clave);
    if (contenido == null || contenido.trim().isEmpty) {
      return <String, DateTime>{};
    }

    try {
      final datos = jsonDecode(contenido);
      if (datos is! Map<String, dynamic>) {
        return <String, DateTime>{};
      }

      final historial = <String, DateTime>{};

      for (final entrada in datos.entries) {
        final valor = entrada.value;
        if (valor is! num) {
          continue;
        }

        historial[entrada.key] = DateTime.fromMillisecondsSinceEpoch(
          valor.toInt(),
          isUtc: true,
        );
      }

      return historial;
    } on FormatException {
      return <String, DateTime>{};
    }
  }

  @override
  Future<void> guardar(Map<String, DateTime> historial) async {
    final datos = historial.map(
      (id, fecha) => MapEntry(id, fecha.toUtc().millisecondsSinceEpoch),
    );

    await _preferences.setString(_clave, jsonEncode(datos));
  }
}
