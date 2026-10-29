import 'package:geolocator/geolocator.dart';

import '../models/ubicacion_usuario.dart';

abstract class UbicacionService {
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  });

  Future<ResultadoUbicacion> obtenerUbicacion({bool solicitarPermiso = false});

  Future<bool> abrirAjustesUbicacion();

  Future<bool> abrirAjustesAplicacion();
}

class GeolocatorUbicacionService implements UbicacionService {
  @override
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return EstadoUbicacion.servicioDesactivado;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied && solicitarPermiso) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied) {
        return EstadoUbicacion.permisoDenegado;
      }

      if (permiso == LocationPermission.deniedForever) {
        return EstadoUbicacion.permisoDenegadoPermanentemente;
      }

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
