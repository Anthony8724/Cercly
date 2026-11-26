import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/features/administracion/models/estadisticas_admin_model.dart';
import 'package:cercly/features/administracion/services/estadisticas_administrador_service.dart';

http.Response respuesta(Object datos, [int estado = 200]) {
  return http.Response(
    jsonEncode(datos),
    estado,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  EstadisticasAdministradorService crearServicio(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final cliente = SupabaseClient(
      'https://cercly.invalid',
      'clave-exclusiva-de-pruebas',
      httpClient: MockClient((request) async {
        final original = await handler(request);

        return http.Response.bytes(
          original.bodyBytes,
          original.statusCode,
          headers: original.headers,
          request: request,
          reasonPhrase: original.reasonPhrase,
        );
      }),
    );

    addTearDown(cliente.dispose);

    return EstadisticasAdministradorService(supabase: cliente);
  }

  List<Map<String, dynamic>> filas(int inicio, int cantidad) {
    return List.generate(cantidad, (i) {
      final numero = inicio + i;

      return {
        'id': 'id-$numero',
        'nombre': 'Registro $numero',
        'titulo': 'Promoción $numero',
        'rol': 'propietario',
        'estado': 'aprobado',
        'mensaje': 'Solicitud $numero',
        'tipo': 'registro',
        'establecimiento_id': null,
        'solicitante_id': null,
      };
    });
  }

  group('Paginación administrativa', () {
    test('divide consultas relacionadas en lotes de 40', () async {
      String uuid(int numero) =>
          '00000000-0000-4000-8000-'
          '${numero.toString().padLeft(12, '0')}';

      final consultas = <String, int>{'establecimientos': 0, 'usuarios': 0};

      final servicio = crearServicio((request) async {
        final tabla = request.url.pathSegments.last;
        final query = request.url.queryParameters;

        if (tabla == 'es_administrador') {
          return respuesta(true);
        }

        if (tabla == 'solicitudes_establecimientos') {
          final offset = int.parse(query['offset'] ?? '0');

          return respuesta(
            offset == 0
                ? List.generate(
                    200,
                    (i) => {
                      'id': uuid(i + 2000),
                      'tipo': 'acceso',
                      'mensaje': 'Solicitud $i',
                      'establecimiento_id': uuid(i),
                      'solicitante_id': uuid(i + 1000),
                    },
                  )
                : [],
          );
        }

        expect(consultas.containsKey(tabla), isTrue);

        final filtro = query['id']!;

        expect(filtro, startsWith('in.('));

        final ids = filtro
            .substring(4, filtro.length - 1)
            .split(',')
            .map((id) => id.replaceAll('"', ''))
            .toList();

        expect(ids.length, lessThanOrEqualTo(40));
        expect(request.url.toString().length, lessThan(2500));

        consultas[tabla] = consultas[tabla]! + 1;

        return respuesta(
          ids.map((id) {
            final numero = int.parse(id.split('-').last);

            return {
              'id': id,
              'nombre': tabla == 'establecimientos'
                  ? 'Negocio $numero'
                  : 'Usuario ${numero - 1000}',
            };
          }).toList(),
        );
      });

      final items = await servicio.obtenerDetalleIndicador(
        TipoIndicadorAdmin.solicitudesPendientes,
      );

      expect(items.length, 200);

      for (var i = 0; i < 200; i++) {
        expect(items[i].titulo, 'Negocio $i');
        expect(items[i].subtitulo, 'Solicitante: Usuario $i');
      }

      expect(consultas['establecimientos'], 5);
      expect(consultas['usuarios'], 5);
    });

    for (final tipo in TipoIndicadorAdmin.values) {
      test('${tipo.name}: recupera 1007 registros', () async {
        final offsets = <int>[];

        final servicio = crearServicio((request) async {
          if (request.url.path.endsWith('/rpc/es_administrador')) {
            return respuesta(true);
          }

          late int offset;
          late int limite;

          if (tipo == TipoIndicadorAdmin.usuariosActivos) {
            expect(
              request.url.path,
              endsWith('/rpc/admin_usuarios_activos_detalle'),
            );

            final params = jsonDecode(request.body) as Map<String, dynamic>;

            offset = params['p_offset'] as int;
            limite = params['p_limite'] as int;

            expect(params['p_dias_activos'], 30);
          } else {
            final query = request.url.queryParameters;

            offset = int.parse(query['offset'] ?? '0');
            limite = int.parse(query['limit']!);

            expect(query['order'], contains('id'));

            if (tipo == TipoIndicadorAdmin.propietarios) {
              expect(query['rol'], 'eq.propietario');
            }

            if (tipo == TipoIndicadorAdmin.solicitudesPendientes) {
              expect(query['estado'], 'eq.pendiente');
            }

            if (tipo == TipoIndicadorAdmin.promocionesActivas) {
              expect(query['activa'], 'eq.true');
            }
          }

          expect(limite, 200);
          offsets.add(offset);

          final cantidad = (1007 - offset).clamp(0, 200).toInt();

          return respuesta(filas(offset, cantidad));
        });

        final resultado = await servicio.obtenerDetalleIndicador(tipo);

        expect(resultado.length, 1007);
        expect(offsets, [0, 200, 400, 600, 800, 1000]);
      });
    }

    test('rechaza acceso no administrativo', () async {
      var peticiones = 0;

      final servicio = crearServicio((request) async {
        peticiones++;

        expect(request.url.path, endsWith('/rpc/es_administrador'));

        return respuesta(false);
      });

      await expectLater(
        servicio.obtenerDetalleIndicador(
          TipoIndicadorAdmin.usuariosRegistrados,
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'codigo', '42501'),
        ),
      );

      expect(peticiones, 1);
    });

    test('detecta identificadores duplicados', () async {
      final servicio = crearServicio((request) async {
        if (request.url.path.endsWith('/rpc/es_administrador')) {
          return respuesta(true);
        }

        return respuesta(filas(0, 200));
      });

      await expectLater(
        servicio.obtenerDetalleIndicador(
          TipoIndicadorAdmin.usuariosRegistrados,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('maneja una lista vacía', () async {
      final servicio = crearServicio((request) async {
        if (request.url.path.endsWith('/rpc/es_administrador')) {
          return respuesta(true);
        }

        return respuesta([]);
      });

      final resultado = await servicio.obtenerDetalleIndicador(
        TipoIndicadorAdmin.usuariosRegistrados,
      );

      expect(resultado, isEmpty);
    });

    test('no devuelve resultados parciales si falla otra página', () async {
      final servicio = crearServicio((request) async {
        if (request.url.path.endsWith('/rpc/es_administrador')) {
          return respuesta(true);
        }

        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');

        if (offset == 0) {
          return respuesta(filas(0, 200));
        }

        return respuesta({
          'code': 'XX000',
          'message': 'Error interno de prueba',
          'details': null,
          'hint': null,
        }, 500);
      });

      await expectLater(
        servicio.obtenerDetalleIndicador(
          TipoIndicadorAdmin.usuariosRegistrados,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('termina correctamente con exactamente 200 registros', () async {
      final offsets = <int>[];

      final servicio = crearServicio((request) async {
        if (request.url.path.endsWith('/rpc/es_administrador')) {
          return respuesta(true);
        }

        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');

        offsets.add(offset);

        return respuesta(offset == 0 ? filas(0, 200) : []);
      });

      final resultado = await servicio.obtenerDetalleIndicador(
        TipoIndicadorAdmin.usuariosRegistrados,
      );

      expect(resultado.length, 200);
      expect(offsets, [0, 200]);
    });
  });
}
