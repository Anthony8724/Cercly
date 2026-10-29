import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'auth_options.dart';
import 'profile_service.dart';

typedef OAuthLauncher = Future<bool> Function(
  OAuthProvider provider, {
  String? redirectTo,
  String? scopes,
  LaunchMode authScreenLaunchMode,
});

class AuthService {
  AuthService({
    SupabaseClient? supabase,
    this.options = const AuthOptions(),
    this.oauthLauncher,
  }) : _client = supabase;

  final SupabaseClient? _client;
  final AuthOptions options;
  final OAuthLauncher? oauthLauncher;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Stream<AuthState> get events => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  Stream<User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map(
      (authState) => authState.session?.user,
    );
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    String? nombre,
    String tipoCuenta = 'usuario',
  }) {
    return _supabase.auth
        .signUp(
          email: email.trim(),
          password: password,
          data: {
            if (nombre != null) 'nombre': nombre.trim(),
            'tipo_cuenta': tipoCuenta,
          },
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _supabase.auth
        .signInWithPassword(email: email.trim(), password: password)
        .timeout(const Duration(seconds: 30));
  }

  Future<bool> signInWithProvider(MetodoAcceso metodo) async {
    _requireAvailable(metodo);
    final provider = switch (metodo) {
      MetodoAcceso.google => OAuthProvider.google,
      MetodoAcceso.microsoft => OAuthProvider.azure,
      MetodoAcceso.facebook => OAuthProvider.facebook,
      MetodoAcceso.celular => throw ArgumentError('Usa OTP para celular'),
    };
    final launched = await (oauthLauncher ?? _supabase.auth.signInWithOAuth)(
      provider,
      redirectTo: AuthOptions.redirect(),
      scopes: metodo == MetodoAcceso.microsoft ? 'email' : null,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const AuthException(
        'No se pudo abrir el navegador',
        code: 'browser_unavailable',
      );
    }
    return launched;
  }

  void _requireAvailable(MetodoAcceso metodo) {
    if (!options.disponible(metodo)) {
      throw const AuthException(
        'Método pendiente de configuración',
        code: 'provider_unavailable',
      );
    }
  }

  Future<void> requestPhoneOtp(String phone) async {
    _requireAvailable(MetodoAcceso.celular);
    if (validarTelefono(phone) != null) {
      throw ArgumentError('Teléfono inválido');
    }
    await _supabase.auth.signInWithOtp(
      phone: phone.trim(),
      shouldCreateUser: true,
    );
  }

  Future<void> verifyPhoneOtp(String phone, String code) async {
    _requireAvailable(MetodoAcceso.celular);
    if (validarTelefono(phone) != null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw ArgumentError('Teléfono o código inválido');
    }
    final response = await _supabase.auth.verifyOTP(
      phone: phone.trim(),
      token: code,
      type: OtpType.sms,
    );
    if (response.session == null) {
      throw const AuthException('No se pudo verificar la sesión');
    }
  }

  Future<void> resetPassword(String email) => _supabase.auth
      .resetPasswordForEmail(email.trim(), redirectTo: AuthOptions.redirect());

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  static String errorMessage(Object error) {
    if (error is ProfileException) {
      return switch (error.failure) {
        ProfileFailure.missing => 'Tu perfil todavía no está disponible. Reintenta en unos momentos. Si continúa, contacta con soporte.',
        ProfileFailure.inconsistent => 'Tu perfil necesita revisión. Contacta con soporte para recuperar el acceso.',
        ProfileFailure.expired =>
          'Tu sesión venció. Cierra la sesión e inicia sesión de nuevo.',
      };
    }
    if (error is TimeoutException || error is AuthRetryableFetchException) {
      return 'La conexión está tardando demasiado. Comprueba tu conexión y reintenta.';
    }
    if (error is PostgrestException) {
      if (error.code == 'PGRST301' ||
          error.code == 'PGRST303' ||
          error.code == '28000') {
        return 'Tu sesión venció. Cierra la sesión e inicia sesión de nuevo.';
      }
      return 'No pudimos cargar tu perfil. Reintenta en unos momentos.';
    }
    if (error is AuthException) {
      if (error.statusCode == '429' ||
          (error.code?.contains('rate_limit') ?? false)) {
        return 'Demasiados intentos. Espera unos minutos antes de reintentar.';
      }
      return switch (error.code) {
        'access_denied' => 'Cancelaste el acceso. Puedes intentarlo de nuevo.',
        'session_expired' ||
        'session_missing' ||
        'session_not_found' ||
        'refresh_token_not_found' ||
        'refresh_token_already_used' ||
        'bad_jwt' => 'Tu sesión venció. Inicia sesión de nuevo.',
        'provider_unavailable' ||
        'provider_disabled' => 'Este método todavía no está disponible.',
        'browser_unavailable' =>
          'No se pudo abrir el navegador. Inténtalo de nuevo.',
        'otp_expired' || 'otp_disabled' =>
          'El código es incorrecto o ha vencido. Solicita uno nuevo.',
        'flow_state_expired' => 'El enlace de recuperación venció. Solicita uno nuevo desde la pantalla de acceso.',
        'invalid_credentials' => 'Los datos o el código no son correctos.',
        'email_not_confirmed' => 'Primero confirma tu correo electrónico.',
        _ => 'No se pudo completar el acceso. Inténtalo de nuevo.',
      };
    }
    if (error is SocketException || error is ClientException) {
      return 'Comprueba tu conexión y vuelve a intentarlo.';
    }
    return 'Ocurrió un error inesperado. Vuelve a intentarlo.';
  }

  Future<void> signOut() {
    return _supabase.auth.signOut().timeout(const Duration(seconds: 15));
  }

  /// Reintento explícito: una nueva suscripción sola repetiría el último error
  /// almacenado por el stream del SDK.
  Future<void> retrySession() async {
    if (_supabase.auth.currentSession == null) {
      await signOut();
    } else {
      await _supabase.auth.refreshSession().timeout(
        const Duration(seconds: 15),
      );
    }
  }
}
