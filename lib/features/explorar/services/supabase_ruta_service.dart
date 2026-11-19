import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ruta_model.dart';
import 'ruta_service.dart';

/// Función inyectable para pruebas; jamás recibe la clave privada ORS.
typedef InvocarRuta = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

/// La clave ORS vive exclusivamente en el secreto de la Edge Function.
class SupabaseRutaService implements RutaService {
  SupabaseRutaService({InvocarRuta? invocar})
    : _invocar = invocar ?? _invocarReal;
  final InvocarRuta _invocar;

  static Future<Map<String, dynamic>> _invocarReal(
    Map<String, dynamic> body,
  ) async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw const RutaException(
        TipoErrorRuta.servicioNoConfigurado,
        'Inicia sesión para calcular una ruta interna o abre el mapa externo.',
      );
    }
    final response = await client.functions.invoke('calcular-ruta', body: body);
    if (response.data is! Map) {
      throw const RutaException(
        TipoErrorRuta.respuestaInvalida,
        'Respuesta de ruta inválida.',
      );
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<RutaModel> calcularRuta({
    required LatLng origen,
    required LatLng destino,
    PerfilRuta perfil = PerfilRuta.aPie,
  }) async {
    final body = <String, dynamic>{
      'origen': [origen.latitude, origen.longitude],
      'destino': [destino.latitude, destino.longitude],
      'perfil': perfil.valorOrs,
    };
    try {
      final datos = await _invocar(body).timeout(const Duration(seconds: 18));
      final rawPuntos = datos['puntos'];
      if (rawPuntos is! List ||
          rawPuntos.length < 2 ||
          rawPuntos.length > 5000) {
        throw const FormatException('Puntos ausentes o demasiados');
      }
      final puntos = <LatLng>[];
      for (final raw in rawPuntos) {
        if (raw is! List ||
            raw.length != 2 ||
            raw[0] is! num ||
            raw[1] is! num) {
          throw const FormatException('Punto inválido');
        }
        final lat = (raw[0] as num).toDouble();
        final lon = (raw[1] as num).toDouble();
        if (!lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180) {
          throw const FormatException('Coordenadas inválidas');
        }
        puntos.add(LatLng(lat, lon));
      }
      final distance = (datos['distanciaMetros'] as num).toDouble();
      final duration = (datos['duracionSegundos'] as num).toDouble();
      if (!distance.isFinite ||
          !duration.isFinite ||
          distance <= 0 ||
          duration <= 0) {
        throw const FormatException('Distancia o tiempo inválidos');
      }
      return RutaModel(
        puntos: puntos,
        distanciaMetros: distance,
        duracionSegundos: duration,
      );
    } on RutaException {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 401 || error.status == 403) {
        throw const RutaException(
          TipoErrorRuta.servicioNoConfigurado,
          'Tu sesión no permite calcular rutas. Inicia sesión de nuevo o abre otra app de mapas.',
        );
      }
      if (error.status == 429) {
        throw const RutaException(
          TipoErrorRuta.cuotaAgotada,
          'Se alcanzó el límite de rutas. Espera antes de reintentar o abre otra app de mapas.',
        );
      }
      if (error.status == 422) {
        throw const RutaException(
          TipoErrorRuta.sinRuta,
          'No encontramos un recorrido entre estos puntos.',
        );
      }
      throw const RutaException(
        TipoErrorRuta.servicioNoDisponible,
        'El servicio de rutas no está disponible. Puedes abrir otra app de mapas.',
      );
    } on TimeoutException {
      throw const RutaException(
        TipoErrorRuta.tiempoAgotado,
        'El cálculo de la ruta tardó demasiado.',
      );
    } on FormatException {
      throw const RutaException(
        TipoErrorRuta.respuestaInvalida,
        'La ruta recibida no es válida.',
      );
    } on TypeError {
      throw const RutaException(
        TipoErrorRuta.respuestaInvalida,
        'La ruta recibida no es válida.',
      );
    } catch (_) {
      throw const RutaException(
        TipoErrorRuta.servicioNoDisponible,
        'No pudimos calcular la ruta. Puedes abrirla en otra app.',
      );
    }
  }
}
