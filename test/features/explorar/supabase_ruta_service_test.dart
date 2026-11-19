import 'package:cercly/features/explorar/services/supabase_ruta_service.dart';
import 'package:cercly/features/explorar/services/ruta_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  for (final caso in <int, TipoErrorRuta>{
    401: TipoErrorRuta.servicioNoConfigurado,
    403: TipoErrorRuta.servicioNoConfigurado,
    429: TipoErrorRuta.cuotaAgotada,
    422: TipoErrorRuta.sinRuta,
    500: TipoErrorRuta.servicioNoDisponible,
    502: TipoErrorRuta.servicioNoDisponible,
    503: TipoErrorRuta.servicioNoDisponible,
  }.entries) {
    test(
      'HTTP ${caso.key} informa el error sin reintentar ni filtrar detalles',
      () async {
        var llamadas = 0;
        final service = SupabaseRutaService(
          invocar: (_) async {
            llamadas++;
            throw FunctionException(
              status: caso.key,
              details: 'detalle privado',
            );
          },
        );
        await expectLater(
          service.calcularRuta(origen: origen, destino: destino),
          throwsA(
            isA<RutaException>()
                .having((e) => e.tipo, 'tipo', caso.value)
                .having(
                  (e) => e.mensaje,
                  'mensaje',
                  isNot(contains('detalle privado')),
                ),
          ),
        );
        expect(llamadas, 1);
      },
    );
  }
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
