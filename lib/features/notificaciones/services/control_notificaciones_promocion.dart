import 'dart:math' as math;

import '../../promociones/models/promocion_destacada_model.dart';
import 'historial_notificaciones_promocion.dart';

class ControlNotificacionesPromocion {
  ControlNotificacionesPromocion({
    this.cooldown = const Duration(hours: 4),
    this.intervaloGlobal = const Duration(minutes: 15),
    this.maximoPorDia = 3,
  }) : assert(maximoPorDia > 0);

  final Duration cooldown;
  final Duration intervaloGlobal;
  final int maximoPorDia;
  final Map<String, DateTime> _ultimaNotificacion = {};
  final Map<String, DateTime> _ultimaPorEstablecimiento = {};
  final Set<String> _promocionesDentro = {};
  final List<DateTime> _notificacionesRecientes = [];

  Map<String, DateTime> get historialUltimasNotificaciones =>
      Map.unmodifiable(_ultimaNotificacion);

  Map<String, DateTime> get historialPorEstablecimiento =>
      Map.unmodifiable(_ultimaPorEstablecimiento);

  Set<String> get promocionesDentro => Set.unmodifiable(_promocionesDentro);

  List<DateTime> get notificacionesRecientes =>
      List.unmodifiable(_notificacionesRecientes);

  bool get hayNotificacionesPorRegistrar =>
      _ultimaNotificacion.isNotEmpty ||
      _ultimaPorEstablecimiento.isNotEmpty ||
      _promocionesDentro.isNotEmpty ||
      _notificacionesRecientes.isNotEmpty;

  void cargarHistorial(HistorialNotificacionesPromocionDatos historial) {
    _ultimaNotificacion
      ..clear()
      ..addAll(historial.ultimaPorPromocion);
    _ultimaPorEstablecimiento
      ..clear()
      ..addAll(historial.ultimaPorEstablecimiento);
    _promocionesDentro
      ..clear()
      ..addAll(historial.promocionesDentro);
    _notificacionesRecientes
      ..clear()
      ..addAll(historial.recientes);
  }

  void registrarNotificacion(
    String promocionId, {
    required DateTime ahora,
    required String establecimientoId,
  }) {
    _ultimaNotificacion[promocionId] = ahora;
    _ultimaPorEstablecimiento[establecimientoId] = ahora;
    _notificacionesRecientes.add(ahora);
    _recortarHistorial(ahora);
  }

  List<PromocionDestacadaModel> evaluar(
    Iterable<PromocionDestacadaModel> promociones, {
    required DateTime ahora,
    int radioUsuarioMetros = 500,
    double precisionUbicacionMetros = 0,
    bool conservarPromocionesDentro = false,
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
          distancia != null &&
          distancia.isFinite &&
          distancia >= 0 &&
          precisionUbicacionMetros.isFinite &&
          precisionUbicacionMetros >= 0 &&
          distancia + precisionUbicacionMetros <= radioEfectivo;

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
      final ultimaDelNegocio =
          _ultimaPorEstablecimiento[promocion.establecimientoId];
      final negocioDisponible =
          ultimaDelNegocio == null ||
          ahora.difference(ultimaDelNegocio) >= cooldown;

      // Una promoción bloqueada temporalmente puede notificarse cuando se
      // libere el límite global. Una ya notificada no se repite mientras la
      // persona permanezca dentro de la zona; debe salir y volver a entrar.
      if ((acabaDeEntrar || ultima == null) &&
          cooldownCumplido &&
          negocioDisponible) {
        notificables.add(promocion);
      }
    }

    if (conservarPromocionesDentro) {
      _promocionesDentro.addAll(dentroAhora);
    } else {
      _promocionesDentro
        ..clear()
        ..addAll(dentroAhora);
    }

    if (notificables.isEmpty || _limiteGlobalActivo(ahora)) {
      return const [];
    }

    // Un solo aviso por ciclo evita varias notificaciones simultáneas al entrar
    // en una zona con varias promociones.
    notificables.sort((a, b) {
      final porDistancia = a.distanciaMetros!.compareTo(b.distanciaMetros!);
      if (porDistancia != 0) return porDistancia;
      final porNegocio = a.establecimientoId.compareTo(b.establecimientoId);
      return porNegocio != 0 ? porNegocio : a.id.compareTo(b.id);
    });
    return [notificables.first];
  }

  HistorialNotificacionesPromocionDatos crearHistorial() {
    return HistorialNotificacionesPromocionDatos(
      ultimaPorPromocion: historialUltimasNotificaciones,
      ultimaPorEstablecimiento: historialPorEstablecimiento,
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
    _ultimaPorEstablecimiento.removeWhere(
      (_, fecha) => fecha.isBefore(antiguedadMaxima),
    );
    final limiteDiario = ahora.subtract(const Duration(hours: 24));
    _notificacionesRecientes.removeWhere(
      (fecha) => !fecha.isAfter(limiteDiario) || fecha.isAfter(ahora),
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
