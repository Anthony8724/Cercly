import 'package:cercly/features/explorar/services/openrouteservice_ruta_service.dart';
import 'package:cercly/features/explorar/services/politica_rutas.dart';
import 'package:cercly/features/explorar/services/ruta_service.dart';
import 'package:cercly/features/explorar/services/supabase_ruta_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const origen = LatLng(0.8116, -77.7172);
  const destino = LatLng(0.815, -77.72);
  test(
    'la política de Play permanece cerrada incluso con flags de compilación',
    () {
      expect(PoliticaRutas.internasHabilitadas, isFalse);
    },
  );
  test(
    'Supabase real rechaza antes de inicialización, sesión, RPC o red',
    () async {
      await expectLater(
        SupabaseRutaService().calcularRuta(origen: origen, destino: destino),
        throwsA(
          isA<RutaException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorRuta.servicioNoConfigurado,
          ),
        ),
      );
    },
  );
  for (final host in [
    'https://api.heigit.org/openrouteservice',
    'https://api.openrouteservice.org',
    'https://otro-proveedor.example',
  ]) {
    test(
      'adaptador legado no transmite a $host aunque haya clave y cliente',
      () async {
        var llamadas = 0;
        final cliente = MockClient((_) async {
          llamadas++;
          return http.Response('{}', 200);
        });
        final service = OpenRouteServiceRutaService(
          cliente: cliente,
          apiKey: 'synthetic-key',
          baseUrl: host,
        );
        await expectLater(
          service.calcularRuta(origen: origen, destino: destino),
          throwsA(isA<RutaException>()),
        );
        expect(llamadas, 0);
        cliente.close();
      },
    );
  }
}
