import '../../promociones/models/promocion_destacada_model.dart';

class ControlNotificacionesPromocion {
  ControlNotificacionesPromocion({this.cooldown = const Duration(hours: 2)});

  final Duration cooldown;
  final Map<String, DateTime> _ultimaNotificacion = {};
  final Set<String> _promocionesDentro = {};

  List<PromocionDestacadaModel> evaluar(
    Iterable<PromocionDestacadaModel> promociones, {
    required DateTime ahora,
  }) {
    final dentroAhora = <String>{};
    final notificables = <PromocionDestacadaModel>[];

    for (final promocion in promociones) {
      final distancia = promocion.distanciaMetros;
      final dentroDelRadio =
          distancia != null && distancia <= promocion.radioAlertaMetros;

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

      if (acabaDeEntrar && cooldownCumplido) {
        notificables.add(promocion);
        _ultimaNotificacion[promocion.id] = ahora;
      }
    }

    _promocionesDentro
      ..clear()
      ..addAll(dentroAhora);

    return notificables;
  }
}
