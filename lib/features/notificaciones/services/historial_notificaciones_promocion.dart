import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistorialNotificacionesPromocionDatos {
  const HistorialNotificacionesPromocionDatos({
    this.ultimaPorPromocion = const {},
    this.recientes = const [],
    this.promocionesDentro = const {},
  });

  final Map<String, DateTime> ultimaPorPromocion;
  final List<DateTime> recientes;
  final Set<String> promocionesDentro;
}

abstract interface class HistorialNotificacionesPromocion {
  Future<HistorialNotificacionesPromocionDatos> cargar();

  Future<void> guardar(HistorialNotificacionesPromocionDatos historial);
}

abstract interface class BorradoHistorialLocalNotificaciones {
  Future<void> borrarDatosLocales();
}

class HistorialNotificacionesPromocionLocal
    implements
        HistorialNotificacionesPromocion,
        BorradoHistorialLocalNotificaciones {
  HistorialNotificacionesPromocionLocal({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _clave =
      'cercly.notificaciones.promociones.ultima_notificacion.v1';
  static const String _claveDentro =
      'cercly.notificaciones.promociones.dentro.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<HistorialNotificacionesPromocionDatos> cargar() async {
    final contenido = await _preferences.getString(_clave);
    final dentro = await _preferences.getStringList(_claveDentro) ?? const [];
    if (contenido == null || contenido.trim().isEmpty) {
      return HistorialNotificacionesPromocionDatos(
        promocionesDentro: dentro.toSet(),
      );
    }

    try {
      final dynamic datos = jsonDecode(contenido);
      if (datos is! Map<String, dynamic>) {
        return HistorialNotificacionesPromocionDatos(
          promocionesDentro: dentro.toSet(),
        );
      }

      // Formato anterior: { promocionId: epochMilliseconds }.
      if (datos['version'] != 2) {
        final anteriores = <String, DateTime>{};
        for (final entrada in datos.entries) {
          final valor = entrada.value;
          if (valor is num) {
            anteriores[entrada.key] = DateTime.fromMillisecondsSinceEpoch(
              valor.toInt(),
              isUtc: true,
            );
          }
        }
        return HistorialNotificacionesPromocionDatos(
          ultimaPorPromocion: anteriores,
          recientes: anteriores.values.toList()..sort(),
          promocionesDentro: dentro.toSet(),
        );
      }

      final porPromocion = <String, DateTime>{};
      final almacenadas = datos['ultima_por_promocion'];
      if (almacenadas is Map) {
        for (final entrada in almacenadas.entries) {
          if (entrada.key is! String || entrada.value is! num) continue;
          porPromocion[entrada.key
              as String] = DateTime.fromMillisecondsSinceEpoch(
            (entrada.value as num).toInt(),
            isUtc: true,
          );
        }
      }

      final recientes = <DateTime>[];
      final envios = datos['recientes'];
      if (envios is List) {
        for (final valor in envios) {
          if (valor is num) {
            recientes.add(
              DateTime.fromMillisecondsSinceEpoch(valor.toInt(), isUtc: true),
            );
          }
        }
      }

      final dentroGuardado = datos['promociones_dentro'];
      final idsDentro = dentroGuardado is List
          ? dentroGuardado.whereType<String>().toSet()
          : dentro.toSet();
      return HistorialNotificacionesPromocionDatos(
        ultimaPorPromocion: porPromocion,
        recientes: recientes,
        promocionesDentro: idsDentro,
      );
    } on FormatException {
      return HistorialNotificacionesPromocionDatos(
        promocionesDentro: dentro.toSet(),
      );
    }
  }

  @override
  Future<void> guardar(HistorialNotificacionesPromocionDatos historial) async {
    final datos = <String, Object>{
      'version': 2,
      'ultima_por_promocion': historial.ultimaPorPromocion.map(
        (id, fecha) => MapEntry(id, fecha.toUtc().millisecondsSinceEpoch),
      ),
      'recientes': historial.recientes
          .map((fecha) => fecha.toUtc().millisecondsSinceEpoch)
          .toList(growable: false),
      'promociones_dentro': historial.promocionesDentro.toList(growable: false),
    };

    await _preferences.setString(_clave, jsonEncode(datos));
    await _preferences.setStringList(
      _claveDentro,
      historial.promocionesDentro.toList(growable: false),
    );
  }

  @override
  Future<void> borrarDatosLocales() async {
    await _preferences.remove(_clave);
    await _preferences.remove(_claveDentro);
  }
}
