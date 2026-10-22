import 'dart:async';
import 'dart:convert';

import 'package:cercly/features/auth/services/auth_service.dart';
import 'package:cercly/features/auth/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> sessionJson({String id = 'a', bool expired = false}) => {
  'access_token':
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600)}))).replaceAll('=', '')}.synthetic',
  'refresh_token': 'synthetic-refresh',
  'token_type': 'bearer',
  'expires_at':
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600),
  'user': {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-01-01',
    'app_metadata': {},
    'user_metadata': {'rol': 'administrador'},
  },
};

Future<SupabaseClient> clientFor(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = SupabaseClient(
    'https://example.test',
    'public-test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  await client.auth.recoverSession(jsonEncode(sessionJson()));
  return client;
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(status == 200 && body is Map ? [body] : body ?? []),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  for (final role in ['usuario', 'propietario', 'administrador']) {
    test('perfil $role existente se conserva sin RPC', () async {
      final requests = <http.Request>[];
      final client = await clientFor((r) async {
        requests.add(r);
        return jsonResponse({'id': 'a', 'rol': role});
      });
      expect(await ProfileService(supabase: client).loadRole('a'), role);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.queryParameters['id'], 'eq.a');
    });
  }
  test('ausencia recupera una vez sin enviar identidad ni rol', () async {
    final requests = <http.Request>[];
    final client = await clientFor((r) async {
      requests.add(r);
      return r.url.path.contains('/rpc/')
          ? jsonResponse([
              {'id': 'a', 'rol': 'usuario'},
            ])
          : jsonResponse(null);
    });
    expect(await ProfileService(supabase: client).loadRole('a'), 'usuario');
    expect(requests.length, 2);
    expect(requests.last.url.path, '/rest/v1/rpc/recuperar_mi_perfil');
    expect(jsonDecode(requests.last.body), anyOf(isNull, isEmpty));
  });
  test(
    'red fallida no intenta crear perfil y permite reintento manual',
    () async {
      var calls = 0;
      final client = await clientFor((r) async {
        calls++;
        if (calls == 1) throw http.ClientException('detalle privado');
        return jsonResponse({'id': 'a', 'rol': 'usuario'});
      });
      final service = ProfileService(supabase: client);
      await expectLater(
        service.loadRole('a'),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
      expect(await service.loadRole('a'), 'usuario');
      expect(calls, 2);
    },
  );
  for (final code in ['PGRST301', '42501']) {
    test('error $code nunca activa recuperación', () async {
      var calls = 0;
      final client = await clientFor((_) async {
        calls++;
        return jsonResponse({'code': code, 'message': 'detalle privado'}, 401);
      });
      await expectLater(
        ProfileService(supabase: client).loadRole('a'),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1);
    });
  }
  test('RPC sin desplegar produce error recuperable sin bucle', () async {
    var calls = 0;
    final client = await clientFor((r) async {
      calls++;
      return r.url.path.contains('/rpc/')
          ? jsonResponse({'code': 'PGRST202', 'message': 'private'}, 404)
          : jsonResponse(null);
    });
    await expectLater(
      ProfileService(supabase: client).loadRole('a'),
      throwsA(
        isA<ProfileException>().having(
          (e) => e.failure,
          'failure',
          ProfileFailure.missing,
        ),
      ),
    );
    expect(calls, 2);
  });
  for (final profile in [
    {'id': 'a', 'rol': null},
    {'id': 'a', 'rol': 'desconocido'},
    {'id': 'b', 'rol': 'administrador'},
  ]) {
    test(
      'perfil inconsistente $profile se rechaza sin reparación destructiva',
      () async {
        var calls = 0;
        final client = await clientFor((_) async {
          calls++;
          return jsonResponse(profile);
        });
        await expectLater(
          ProfileService(supabase: client).loadRole('a'),
          throwsA(
            isA<ProfileException>().having(
              (e) => e.failure,
              'failure',
              ProfileFailure.inconsistent,
            ),
          ),
        );
        expect(calls, 1);
      },
    );
  }
  test(
    'cambio de sesión durante consulta descarta resultado sin recuperar',
    () async {
      final pending = Completer<http.Response>();
      final client = await clientFor((_) => pending.future);
      final result = ProfileService(supabase: client).loadRole('a');
      final check = expectLater(result, throwsA(isA<ProfileException>()));
      await client.auth.recoverSession(jsonEncode(sessionJson(id: 'b')));
      pending.complete(jsonResponse(null));
      await check;
    },
  );
  test(
    'sesión serializada se restaura y logout elimina identidad aun sin red',
    () async {
      final client = await clientFor((r) async {
        if (r.url.path.endsWith('/logout')) {
          throw http.ClientException('sin red');
        }
        return jsonResponse({'id': 'a', 'rol': 'usuario'});
      });
      final serialized = jsonEncode(client.auth.currentSession!.toJson());
      final restored = SupabaseClient(
        'https://example.test',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) async => http.Response('', 204)),
      );
      addTearDown(restored.dispose);
      await restored.auth.recoverSession(serialized);
      expect(AuthService(supabase: restored).currentUser?.id, 'a');
      await AuthService(supabase: restored).signOut();
      expect(restored.auth.currentSession, isNull);
      await expectLater(
        AuthService(supabase: client).signOut(),
        throwsA(isA<Exception>()),
      );
      expect(client.auth.currentSession, isNull);
      await expectLater(
        ProfileService(supabase: client).loadRole('a'),
        throwsA(isA<ProfileException>()),
      );
    },
  );
  test('reintento de sesión renueva realmente el token una vez', () async {
    final requests = <http.Request>[];
    final client = await clientFor((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(sessionJson()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await AuthService(supabase: client).retrySession();
    expect(requests.single.url.path, '/auth/v1/token');
    expect(requests.single.url.queryParameters['grant_type'], 'refresh_token');
    expect(client.auth.currentUser?.id, 'a');
  });
  test('sesión expirada sin renovación no autoriza perfil', () async {
    final client = await clientFor((_) async => http.Response('', 204));
    await client.auth.signOut();
    // Suscriptor requerido para consumir el error de sesión del SDK.
    final subscription = client.auth.onAuthStateChange.listen(
      (_) {},
      onError: (_) {},
    );
    addTearDown(subscription.cancel);
    await expectLater(
      client.auth.recoverSession(jsonEncode(sessionJson(expired: true))),
      throwsA(isA<AuthException>()),
    );
    expect(client.auth.currentSession, isNull);
  });
}
