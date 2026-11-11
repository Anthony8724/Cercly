import 'dart:convert';

import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';
import 'package:cercly/features/solicitudes_establecimientos/services/solicitud_establecimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'búsqueda acotada, orden estable y filtros diferentes por tipo',
    () async {
      final peticiones = <Uri>[];
      final client = SupabaseClient(
        'https://example.test',
        'publishable-test',
        httpClient: MockClient((r) async {
          peticiones.add(r.url);
          return http.Response(
            '[]',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = SolicitudEstablecimientoService(supabase: client);
      await service.listarEstablecimientosParaTipo(
        'reclamar',
        busqueda: 'Café%',
        offset: 20,
      );
      final query = peticiones.last.queryParameters;
      expect(query['estado'], 'eq.aprobado');
      expect(query['publicable'], 'eq.true');
      expect(query['fuente'], 'eq.osm');
      expect(query['propietario_id'], 'is.null');
      expect(query['nombre'], r'ilike.%Café\%%');
      expect(query['offset'], '20');
      expect(query['limit'], '20');
      expect(query['order'], 'nombre.asc.nullslast,id.asc.nullslast');
      await service.listarEstablecimientosParaTipo('acceso', id: 'negocio');
      expect(peticiones.last.queryParameters['propietario_id'], 'not.is.null');
      expect(peticiones.last.queryParameters['id'], 'eq.negocio');
      await service.listarEstablecimientosParaTipo('correccion');
      expect(
        peticiones.last.queryParameters.containsKey('propietario_id'),
        isFalse,
      );
      await expectLater(
        service.listarEstablecimientosParaTipo('otro'),
        throwsArgumentError,
      );
      await client.dispose();
    },
  );

  test(
    'detalle por ID exige público aprobado y respeta respuesta vacía',
    () async {
      late Uri uri;
      final client = SupabaseClient(
        'https://example.test',
        'publishable-test',
        httpClient: MockClient((r) async {
          uri = r.url;
          return http.Response(
            'null',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(
        await EstablecimientoPublicoService(supabase: client)
            .obtenerPorId('privado'),
        isNull,
      );
      expect(uri.queryParameters['id'], 'eq.privado');
      expect(uri.queryParameters['estado'], 'eq.aprobado');
      expect(uri.queryParameters['publicable'], 'eq.true');
      await client.dispose();
    },
  );

  test(
    'aprobar corrección usa RPC atómica y nunca cae en la aprobación antigua',
    () async {
      final requests = <http.Request>[];
      var disponible = false;
      final client = SupabaseClient(
        'https://example.test',
        'publishable-test',
        httpClient: MockClient((r) async {
          requests.add(r);
          return disponible
              ? http.Response('', 204, request: r)
              : http.Response(
                  jsonEncode({'code': 'PGRST202', 'message': 'missing RPC'}),
                  404,
                  request: r,
                  headers: {'content-type': 'application/json'},
                );
        }),
      );
      final service = SolicitudEstablecimientoService(supabase: client);
      await expectLater(
        service.aplicarCorreccion(solicitudId: 's', motivo: 'Revisado'),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests.length, 1);
      expect(
        requests.single.url.path,
        endsWith('/rpc/aplicar_correccion_establecimiento'),
      );
      disponible = true;
      await service.aplicarCorreccion(solicitudId: 's', motivo: 'Revisado');
      expect(jsonDecode(requests.last.body), {
        'p_solicitud_id': 's',
        'p_motivo': 'Revisado',
      });
      await service.responder(
        solicitudId: 's',
        estado: 'rechazada',
        motivoRespuesta: 'No se confirma',
      );
      expect(
        requests.last.url.path,
        endsWith('/rpc/responder_solicitud_establecimiento'),
      );
      expect(jsonDecode(requests.last.body)['p_estado'], 'rechazada');
      await expectLater(
        service.responder(solicitudId: 's', estado: 'rechazada'),
        throwsArgumentError,
      );
      await client.dispose();
    },
  );
}
