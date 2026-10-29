import 'dart:math' as math;

import '../../promociones/models/promocion_destacada_model.dart';
import 'historial_notificaciones_promocion.dart';

class ControlNotificacionesPromocion {
  ControlNotificacionesPromocion({
    this.cooldown = const Duration(hours: 2),
    this.intervaloGlobal = const Duration(minutes: 15),
    this.maximoPorDia = 3,
  }) : assert(maximoPorDia > 0);

  final Duration cooldown;
  final Duration intervaloGlobal;
  final int maximoPorDia;
  final Map<String, DateTime> _ultimaNotificacion = {};
  final Set<String> _promocionesDentro = {};
  final List<DateTime> _notificacionesRecientes = [];

  Map<String, DateTime> get historialUltimasNotificaciones =>
      Map.unmodifiable(_ultimaNotificacion);

  Set<String> get promocionesDentro => Set.unmodifiable(_promocionesDentro);

  List<DateTime> get notificacionesRecientes =>
      List.unmodifiable(_notificacionesRecientes);

  bool get hayNotificacionesPorRegistrar =>
      _ultimaNotificacion.isNotEmpty ||
      _promocionesDentro.isNotEmpty ||
      _notificacionesRecientes.isNotEmpty;

  void cargarHistorial(HistorialNotificacionesPromocionDatos historial) {
    _ultimaNotificacion
      ..clear()
      ..addAll(historial.ultimaPorPromocion);
    _promocionesDentro
      ..clear()
      ..addAll(historial.promocionesDentro);
    _notificacionesRecientes
      ..clear()
      ..addAll(historial.recientes);
  }

  void registrarNotificacion(String promocionId, {required DateTime ahora}) {
    _ultimaNotificacion[promocionId] = ahora;
    _notificacionesRecientes.add(ahora);
    _recortarHistorial(ahora);
  }

  List<PromocionDestacadaModel> evaluar(
    Iterable<PromocionDestacadaModel> promociones, {
    required DateTime ahora,
    int radioUsuarioMetros = 500,
  }) {
    _recortarHistorial(ahora);
    final dentroAhora = <String>{};
    final notificables = <PromocionDestacadaModel>[];

    for (final promocion in promociones) {
      final distancia = promocion.distanciaMetros;
      final radioEfectivo = math.min(
        promocion.radioAlertaMetros,
        radioUsuarioMetros,
      );
      final dentroDelRadio =
          distancia != null && distancia.isFinite && distancia <= radioEfectivo;

      if (!promocion.activa ||
          !promocion.estaVigenteEn(ahora) ||
          !dentroDelRadio) {
        continue;
      }

      dentroAhora.add(promocion.id);
      final acabaDeEntrar = !_promocionesDentro.contains(promocion.id);
      final ultima = _ultimaNotificacion[promocion.id];
      final cooldownCumplido =
          ultima == null || ahora.difference(ultima) >= cooldown;

      // Una promoción bloqueada temporalmente puede notificarse cuando se
      // libere el límite global. Una ya notificada no se repite mientras la
      // persona permanezca dentro de la zona; debe salir y volver a entrar.
      if ((acabaDeEntrar || ultima == null) && cooldownCumplido) {
        notificables.add(promocion);
      }
    }

    _promocionesDentro
      ..clear()
      ..addAll(dentroAhora);

    if (notificables.isEmpty || _limiteGlobalActivo(ahora)) {
      return const [];
    }

    // Un solo aviso por ciclo evita varias notificaciones simultáneas al entrar
    // en una zona con varias promociones.
    return notificables.take(1).toList(growable: false);
  }

  HistorialNotificacionesPromocionDatos crearHistorial() {
    return HistorialNotificacionesPromocionDatos(
      ultimaPorPromocion: historialUltimasNotificaciones,
      recientes: notificacionesRecientes,
      promocionesDentro: promocionesDentro,
    );
  }

  bool _limiteGlobalActivo(DateTime ahora) {
    if (_notificacionesRecientes.length >= maximoPorDia) return true;
    if (_notificacionesRecientes.isEmpty) return false;
    final ultima = _notificacionesRecientes.reduce(
      (primera, segunda) => primera.isAfter(segunda) ? primera : segunda,
    );
    return ahora.difference(ultima) < intervaloGlobal;
  }

  void _recortarHistorial(DateTime ahora) {
    final antiguedadMaxima = ahora.subtract(const Duration(days: 30));
    _ultimaNotificacion.removeWhere(
      (_, fecha) => fecha.isBefore(antiguedadMaxima),
    );
    final limiteDiario = ahora.subtract(const Duration(hours: 24));
    _notificacionesRecientes.removeWhere(
      (fecha) => fecha.isBefore(limiteDiario) || fecha.isAfter(ahora),
    );
    if (_notificacionesRecientes.length > 300) {
      _notificacionesRecientes.sort();
      _notificacionesRecientes.removeRange(
        0,
        _notificacionesRecientes.length - 300,
      );
    }
  }
}
