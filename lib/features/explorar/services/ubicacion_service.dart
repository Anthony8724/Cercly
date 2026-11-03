import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ubicacion_usuario.dart';

abstract class UbicacionService {
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  });

  Future<ResultadoUbicacion> obtenerUbicacion({bool solicitarPermiso = false});

  Future<bool> abrirAjustesUbicacion();

  Future<bool> abrirAjustesAplicacion();
}

abstract interface class PrecisionUbicacionService {
  /// `null` cuando Android no puede informar precisión aproximada o exacta.
  Future<bool?> ubicacionPrecisa();
}

class GeolocatorUbicacionService
    implements UbicacionService, PrecisionUbicacionService {
  static const _permisoSolicitadoKey =
      'cercly.permisos.ubicacion.solicitud_resuelta.v1';

  @override
  Future<bool?> ubicacionPrecisa() async {
    try {
      return await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.precise;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return EstadoUbicacion.servicioDesactivado;
      }

      var permiso = await Geolocator.checkPermission();
      final preferencias = SharedPreferencesAsync();
      if (permiso == LocationPermission.denied && solicitarPermiso) {
        final solicitudResuelta =
            await preferencias.getBool(_permisoSolicitadoKey) ?? false;
        if (!solicitudResuelta) {
          permiso = await Geolocator.requestPermission();
          await preferencias.setBool(_permisoSolicitadoKey, true);
        }
      }

      if (permiso == LocationPermission.denied) {
        return EstadoUbicacion.permisoDenegado;
      }

      if (permiso == LocationPermission.deniedForever) {
        return EstadoUbicacion.permisoDenegadoPermanentemente;
      }

      // El permiso real sigue siendo el estado autoritativo. Esta marca solo
      // evita volver a lanzar el diálogo si Android lo revoca después.
      await preferencias.setBool(_permisoSolicitadoKey, true);

      return EstadoUbicacion.disponible;
    } catch (_) {
      return EstadoUbicacion.error;
    }
  }

  @override
  Future<ResultadoUbicacion> obtenerUbicacion({
    bool solicitarPermiso = false,
  }) async {
    try {
      final estado = await consultarEstadoPermiso(
        solicitarPermiso: solicitarPermiso,
      );
      if (estado != EstadoUbicacion.disponible) {
        return ResultadoUbicacion(
          estado: estado,
          mensaje: switch (estado) {
            EstadoUbicacion.servicioDesactivado => 'Activa la ubicación del dispositivo para buscar promociones cercanas.',
            EstadoUbicacion.permisoDenegado =>
              'Concede el permiso de ubicación para activar las alertas.',
            EstadoUbicacion.permisoDenegadoPermanentemente =>
              'Habilita el permiso de ubicación desde los ajustes de Android.',
            _ => 'No pudimos comprobar el permiso de ubicación.',
          },
        );
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return ResultadoUbicacion(
        estado: EstadoUbicacion.disponible,
        ubicacion: UbicacionUsuario(
          latitud: posicion.latitude,
          longitud: posicion.longitude,
          precisionMetros: posicion.accuracy,
          capturadaEn: posicion.timestamp,
        ),
      );
    } catch (_) {
      return const ResultadoUbicacion(
        estado: EstadoUbicacion.error,
        mensaje: 'No pudimos obtener tu ubicación. Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<bool> abrirAjustesAplicacion() => Geolocator.openAppSettings();

  @override
  Future<bool> abrirAjustesUbicacion() => Geolocator.openLocationSettings();
}
