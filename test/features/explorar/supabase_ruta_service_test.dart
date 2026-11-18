import 'package:cercly/features/explorar/services/supabase_ruta_service.dart';
import 'package:cercly/features/explorar/services/ruta_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const origen = LatLng(0.8116, -77.7172);
  const destino = LatLng(0.815, -77.72);
  test('envía coordenadas y perfil, interpreta ruta segura', () async {
    Map<String, dynamic>? capturado;
    final service = SupabaseRutaService(
      invocar: (body) async {
        capturado = body;
        return {
          'puntos': [
            [0.8116, -77.7172],
            [0.815, -77.72],
          ],
          'distanciaMetros': 750.0,
          'duracionSegundos': 540.0,
        };
      },
    );
    final ruta = await service.calcularRuta(
      origen: origen,
      destino: destino,
      perfil: PerfilRuta.auto,
    );
    expect(capturado?['origen'], [0.8116, -77.7172]);
    expect(capturado?['perfil'], 'driving-car');
    expect(ruta.puntos.length, 2);
    expect(ruta.distanciaMetros, 750);
    expect(ruta.duracionSegundos, 540);
  });
  test('rechaza una respuesta malformada', () async {
    final service = SupabaseRutaService(
      invocar: (_) async => {
        'puntos': [
          [99.0, 0.0],
          [0.815, -77.72],
        ],
        'distanciaMetros': 1,
        'duracionSegundos': 1,
      },
    );
    expect(
      () => service.calcularRuta(origen: origen, destino: destino),
      throwsA(
        isA<RutaException>().having(
          (e) => e.tipo,
          'tipo',
          TipoErrorRuta.respuestaInvalida,
        ),
      ),
    );
  });
}
