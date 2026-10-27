import 'dart:convert';

import 'package:cercly/features/auth/services/auth_service.dart';
import 'package:cercly/features/auth/services/auth_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('registro y login conservan contrato HTTP y no envían rol', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.test',
      'public-test',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode({
            'id': 'u',
            'aud': 'authenticated',
            'created_at': '2026-01-01',
            'app_metadata': {},
            'user_metadata': {},
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);
    final service = AuthService(supabase: client);
    await service.register(
      email: ' a@example.com ',
      password: 'secret',
      tipoCuenta: 'propietario',
    );
    final body = jsonDecode(requests.first.body) as Map;
    expect(body['email'], 'a@example.com');
    expect(body['data']['rol'], isNull);
    expect(body['data']['tipo_cuenta'], 'propietario');
    await service.signIn(email: ' a@example.com ', password: 'secret');
    expect(requests.last.url.path, '/auth/v1/token');
    expect(jsonDecode(requests.last.body)['email'], 'a@example.com');
  });
  test('OAuth selecciona proveedor y scope mínimo de Microsoft', () async {
    final providers = <OAuthProvider>[];
    final receivedScopes = <String?>[];
    final service = AuthService(
      options: const AuthOptions(google: true, microsoft: true, facebook: true),
      oauthLauncher:
          (
            provider, {
            redirectTo,
            scopes,
            authScreenLaunchMode = LaunchMode.platformDefault,
          }) async {
            providers.add(provider);
            receivedScopes.add(scopes);
            expect(redirectTo, AuthOptions.redirect());
            return true;
          },
    );
    for (final method in [
      MetodoAcceso.google,
      MetodoAcceso.microsoft,
      MetodoAcceso.facebook,
    ]) {
      await service.signInWithProvider(method);
    }
    expect(providers, [
      OAuthProvider.google,
      OAuthProvider.azure,
      OAuthProvider.facebook,
    ]);
    expect(receivedScopes, [null, 'email', null]);
  });
  test(
    'OTP usa endpoints reales con transporte simulado sin enviar SMS',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'public-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/verify')) {
            return http.Response(
              jsonEncode({
                'access_token': 'fake',
                'token_type': 'bearer',
                'refresh_token': 'fake-refresh',
                'user': {
                  'id': 'u',
                  'aud': 'authenticated',
                  'created_at': '2026-01-01',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.dispose);
      final service = AuthService(
        supabase: client,
        options: const AuthOptions(celular: true),
      );
      await service.requestPhoneOtp('+593991234567');
      expect(requests.first.url.path, '/auth/v1/otp');
      expect(jsonDecode(requests.first.body)['create_user'], true);
      await service.verifyPhoneOtp('+593991234567', '123456');
      expect(requests.last.url.path, '/auth/v1/verify');
      expect(jsonDecode(requests.last.body)['type'], 'sms');
      expect(client.auth.currentUser?.id, 'u');
      final count = requests.length;
      await expectLater(
        service.requestPhoneOtp('0991234567'),
        throwsArgumentError,
      );
      await expectLater(
        service.verifyPhoneOtp('+593991234567', 'abc'),
        throwsArgumentError,
      );
      expect(requests.length, count);
    },
  );
  test(
    'Google habilitado por defecto; proveedores sin configuración cerrados',
    () async {
      final providers = <OAuthProvider>[];
      final service = AuthService(
        oauthLauncher:
            (
              provider, {
              redirectTo,
              scopes,
              authScreenLaunchMode = LaunchMode.platformDefault,
            }) async {
              providers.add(provider);
              expect(redirectTo, AuthOptions.redirect());
              return true;
            },
      );
      expect(await service.signInWithProvider(MetodoAcceso.google), isTrue);
      expect(providers, [OAuthProvider.google]);
      for (final method in MetodoAcceso.values.where(
        (m) => m != MetodoAcceso.celular && m != MetodoAcceso.google,
      )) {
        await expectLater(
          service.signInWithProvider(method),
          throwsA(isA<AuthException>()),
        );
      }
      await expectLater(
        service.requestPhoneOtp('+593991234567'),
        throwsA(isA<AuthException>()),
      );
    },
  );
  test('redirecciones Android y web eliminan credenciales del callback', () {
    expect(
      AuthOptions.redirect(web: false),
      'com.cercly.cercly://auth-callback/',
    );
    expect(
      AuthOptions.redirect(
        web: true,
        base: Uri.parse('https://cercly.test/app/?code=secret#token'),
      ),
      'https://cercly.test/app/',
    );
  });
}
