import 'dart:convert';

import 'package:cercly/features/preferencias/models/preferencias_usuario.dart';
import 'package:cercly/features/preferencias/services/preferencias_usuario_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scenario in [
    ('PT409', 'Las preferencias cambiaron en otro dispositivo', true),
    ('40001', 'Las preferencias cambiaron en otro dispositivo', true),
    ('40001', 'could not serialize access due to concurrent update', false),
    ('42501', 'Permiso denegado', false),
  ]) {
    test('RPC ${scenario.$1}: ${scenario.$2}; una sola petición', () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls++;
          expect(request.url.path, '/rest/v1/rpc/guardar_preferencias_usuario');
          expect(jsonDecode(request.body)['p_revision_esperada'], 0);
          return http.Response(
            jsonEncode({'code': scenario.$1, 'message': scenario.$2}),
            scenario.$1 == 'PT409' ? 409 : 500,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'exp': exp})))
          .replaceAll('=', '');
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'e30.$payload.synthetic',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_at': exp,
          'user': {
            'id': 'qa-user',
            'aud': 'authenticated',
            'created_at': '2026-01-01',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
          },
        }),
      );
      final future = SupabasePreferenciasRemotas(client)
          .guardar('qa-user', const PreferenciasUsuario());
      await expectLater(
        future,
        throwsA(
          scenario.$3
              ? isA<PreferenciasConflictException>()
              : isA<PostgrestException>().having(
                  (e) => e.code,
                  'code',
                  scenario.$1,
                ),
        ),
      );
      expect(calls, 1);
    });
  }
}
