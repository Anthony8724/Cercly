import 'dart:async';
import 'dart:convert';

import 'package:cercly/features/establecimientos/models/establecimiento_model.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'profile_service_test.dart' show clientFor;

Map<String, dynamic> ficha({
  String estado = 'pendiente',
  bool publicable = false,
}) => {
  'id': 'ficha',
  'propietario_id': 'a',
  'nombre': 'Negocio de prueba',
  'categoria_id': 'categoria',
  'direccion': 'Dirección',
  'latitud': 0.8,
  'longitud': -77.7,
  'estado': estado,
  'publicable': publicable,
};

http.Response respuesta(Object? body, [int status = 200]) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  for (final estado in ['pendiente', 'rechazado']) {
    test(
      'edición $estado solo envía información y detecta fila modificada',
      () async {
        final requests = <http.Request>[];
        final client = await clientFor((r) async {
          requests.add(r);
          if (r.url.path.contains('/rpc/')) return respuesta(true);
          return respuesta(
            r.method == 'PATCH' ? {'id': 'ficha'} : ficha(estado: estado),
          );
        });
        await EstablecimientoService(supabase: client).actualizarInformacion(
          EstablecimientoModel.fromSupabase(ficha(estado: estado)),
        );
        final update = requests.singleWhere((r) => r.method == 'PATCH');
        expect(
          (jsonDecode(update.body) as Map).keys,
          unorderedEquals([
            'nombre',
            'descripcion',
            'direccion',
            'telefono_publico',
          ]),
        );
        expect(update.url.queryParameters['estado'], 'eq.$estado');
      },
    );
  }

  test('estado aprobado reciente bloquea editor obsoleto sin UPDATE', () async {
    final requests = <http.Request>[];
    final client = await clientFor((r) async {
      requests.add(r);
      return respuesta(
        r.url.path.contains('/rpc/')
            ? true
            : ficha(estado: 'aprobado', publicable: true),
      );
    });
    await expectLater(
      EstablecimientoService(supabase: client)
          .actualizarInformacion(EstablecimientoModel.fromSupabase(ficha())),
      throwsStateError,
    );
    expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  test('permiso revocado impide editar y consultar datos de ficha', () async {
    final requests = <http.Request>[];
    final client = await clientFor((r) async {
      requests.add(r);
      return respuesta(false);
    });
    await expectLater(
      EstablecimientoService(supabase: client)
          .actualizarInformacion(EstablecimientoModel.fromSupabase(ficha())),
      throwsStateError,
    );
    expect(requests, hasLength(1));
  });

  for (final publicar in [true, false]) {
    test(
      'aprobación explícita publicar=$publicar usa RPC cerrada y verifica resultado',
      () async {
        final requests = <http.Request>[];
        final client = await clientFor((r) async {
          requests.add(r);
          return r.method == 'POST'
              ? respuesta(null, 204)
              : respuesta(ficha(estado: 'aprobado', publicable: publicar));
        });
        final actual = await EstablecimientoService(supabase: client)
            .cambiarEstado(
              establecimientoId: 'ficha',
              nuevoEstado: 'aprobado',
              publicar: publicar,
            );
        expect(actual.publicable, publicar);
        expect(
          requests.first.url.path,
          '/rest/v1/rpc/moderar_estado_establecimiento',
        );
        expect(jsonDecode(requests.first.body), {
          'p_id': 'ficha',
          'p_estado': 'aprobado',
          'p_publicable': publicar,
        });
        expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
      },
    );
  }

  test('rechazo envía publicación false y no conserva visibilidad', () async {
    final requests = <http.Request>[];
    final client = await clientFor((r) async {
      requests.add(r);
      return r.method == 'POST'
          ? respuesta(null, 204)
          : respuesta(ficha(estado: 'rechazado'));
    });
    await EstablecimientoService(supabase: client).rechazar('ficha');
    expect(jsonDecode(requests.first.body)['p_publicable'], false);
  });

  test('sin elección explícita o estado incompatible no llama API', () async {
    var calls = 0;
    final client = await clientFor((r) async {
      calls++;
      return respuesta(null);
    });
    final service = EstablecimientoService(supabase: client);
    await expectLater(
      service.cambiarEstado(
        establecimientoId: 'ficha',
        nuevoEstado: 'aprobado',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.cambiarEstado(
        establecimientoId: 'ficha',
        nuevoEstado: 'rechazado',
        publicar: true,
      ),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test(
    'RPC denegada no utiliza UPDATE alternativo ni confirma éxito',
    () async {
      final requests = <http.Request>[];
      final client = await clientFor((r) async {
        requests.add(r);
        return respuesta({
          'code': '42501',
          'message': 'Administrador requerido',
        }, 403);
      });
      await expectLater(
        EstablecimientoService(supabase: client).cambiarEstado(
          establecimientoId: 'ficha',
          nuevoEstado: 'aprobado',
          publicar: true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test('lectura sin publicación efectiva no anuncia éxito', () async {
    final client = await clientFor(
      (r) async => r.method == 'POST'
          ? respuesta(null, 204)
          : respuesta(ficha(estado: 'aprobado')),
    );
    await expectLater(
      EstablecimientoService(supabase: client).cambiarEstado(
        establecimientoId: 'ficha',
        nuevoEstado: 'aprobado',
        publicar: true,
      ),
      throwsStateError,
    );
  });

  test(
    'doble toque mientras RPC pendiente envía una sola moderación',
    () async {
      final completer = Completer<http.Response>();
      var calls = 0;
      final client = await clientFor((r) async {
        if (r.method == 'POST') {
          calls++;
          return completer.future;
        }
        return respuesta(ficha(estado: 'aprobado', publicable: true));
      });
      final service = EstablecimientoService(supabase: client);
      final first = service.cambiarEstado(
        establecimientoId: 'ficha',
        nuevoEstado: 'aprobado',
        publicar: true,
      );
      await expectLater(
        service.cambiarEstado(
          establecimientoId: 'ficha',
          nuevoEstado: 'aprobado',
          publicar: true,
        ),
        throwsStateError,
      );
      completer.complete(respuesta(null, 204));
      await first;
      expect(calls, 1);
    },
  );
}
