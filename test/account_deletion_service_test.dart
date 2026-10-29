import 'dart:convert';
import 'dart:io';

import 'package:cercly/features/auth/services/account_deletion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<SupabaseClient> clientWithSession(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = SupabaseClient(
    'https://example.test',
    'public-test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handler),
  );
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': 'synthetic-jwt',
      'refresh_token': 'synthetic-refresh',
      'token_type': 'bearer',
      'user': {
        'id': 'b7000000-0000-0000-0000-000000000001',
        'aud': 'authenticated',
        'created_at': '2026-01-01',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
  return client;
}

void main() {
  test('respuesta eliminada cierra sesión y no envía ID al backend', () async {
    SharedPreferences.setMockInitialValues({
      'cercly_modo_cuenta_b7000000-0000-0000-0000-000000000001': 'usuario',
      'cercly_preferencias_v1_b7000000-0000-0000-0000-000000000001':
          '{"categorias_ids":["category-1"]}',
    });
    final requests = <http.Request>[];
    final client = await clientWithSession((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/logout')) return http.Response('', 204);
      return http.Response(
        jsonEncode({'estado': 'eliminada'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.dispose);
    final service = AccountDeletionService(supabase: client);
    expect(await service.requestDeletion(), AccountDeletionOutcome.deleted);
    expect(client.auth.currentSession, isNull);
    expect(requests.first.url.path, '/functions/v1/eliminar-cuenta');
    expect(requests.first.headers['Authorization'], 'Bearer synthetic-jwt');
    expect(jsonDecode(requests.first.body), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(
        'cercly_modo_cuenta_b7000000-0000-0000-0000-000000000001',
      ),
      isNull,
    );
    expect(
      preferences.getString(
        'cercly_preferencias_v1_b7000000-0000-0000-0000-000000000001',
      ),
      isNull,
    );
  });

  test('sin sesión no invoca la función', () async {
    final client = SupabaseClient('https://example.test', 'public-test');
    addTearDown(client.dispose);
    final service = AccountDeletionService(supabase: client);
    await expectLater(
      service.requestDeletion(),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.failure,
          'failure',
          AccountDeletionFailure.session,
        ),
      ),
    );
  });

  test('revisión conserva sesión y no afirma eliminación', () async {
    final client = await clientWithSession(
      (_) async => http.Response(
        jsonEncode({'estado': 'revision'}),
        202,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(client.dispose);
    final service = AccountDeletionService(supabase: client);
    expect(await service.requestDeletion(), AccountDeletionOutcome.review);
    expect(client.auth.currentSession, isNotNull);
  });

  test('fallo parcial queda pendiente sin cerrar sesión', () async {
    final client = await clientWithSession(
      (_) async => http.Response(
        jsonEncode({'estado': 'solicitud_pendiente'}),
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(client.dispose);
    final service = AccountDeletionService(supabase: client);
    await expectLater(
      service.requestDeletion(),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.failure,
          'failure',
          AccountDeletionFailure.pending,
        ),
      ),
    );
    expect(client.auth.currentSession, isNotNull);
  });

  test('fallo de transporte no afirma eliminación', () async {
    final client = await clientWithSession(
      (_) async => throw const SocketException('offline'),
    );
    addTearDown(client.dispose);
    final service = AccountDeletionService(supabase: client);
    await expectLater(
      service.requestDeletion(),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.failure,
          'failure',
          AccountDeletionFailure.network,
        ),
      ),
    );
    expect(client.auth.currentSession, isNotNull);
  });

  test('autenticación antigua exige reingreso', () async {
    final client = await clientWithSession(
      (_) async => http.Response(
        jsonEncode({'estado': 'autenticacion_reciente_requerida'}),
        403,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(client.dispose);
    final service = AccountDeletionService(supabase: client);
    await expectLater(
      service.requestDeletion(),
      throwsA(
        isA<AccountDeletionException>().having(
          (e) => e.failure,
          'failure',
          AccountDeletionFailure.recentAuth,
        ),
      ),
    );
  });
}
