import 'package:geolocator/geolocator.dart';

import '../models/ubicacion_usuario.dart';

abstract class UbicacionService {
  Future<ResultadoUbicacion> obtenerUbicacion();

  Future<bool> abrirAjustesUbicacion();

  Future<bool> abrirAjustesAplicacion();
}

class GeolocatorUbicacionService implements UbicacionService {
  @override
  Future<ResultadoUbicacion> obtenerUbicacion() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoUbicacion(
          estado: EstadoUbicacion.servicioDesactivado,
          mensaje: 'Activa la ubicación del dispositivo para explorar cerca.',
        );
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied) {
        return const ResultadoUbicacion(
          estado: EstadoUbicacion.permisoDenegado,
          mensaje: 'Necesitamos tu permiso para mostrar lugares cercanos.',
        );
      }

      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion(
          estado: EstadoUbicacion.permisoDenegadoPermanentemente,
          mensaje: 'Habilita el permiso de ubicación desde los ajustes.',
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
