import 'ruta_service.dart';

/// La revisión contractual pendiente no puede sustituirse por consentimiento,
/// una clave API ni un dart-define. Reactivar requiere un cambio revisado.
class PoliticaRutas {
  const PoliticaRutas._();

  static bool get internasHabilitadas => false;

  static void exigirProveedorAutorizado() {
    if (!internasHabilitadas) {
      throw const RutaException(
        TipoErrorRuta.servicioNoConfigurado,
        'Las rutas internas no están disponibles en esta versión. Abre otra app de mapas para llegar.',
      );
    }
  }
}
