import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'auth_options.dart';

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
    return _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (nombre != null) 'nombre': nombre.trim(),
        'tipo_cuenta': tipoCuenta,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
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
    if (error is AuthException) {
      if (error.statusCode == '429' ||
          (error.code?.contains('rate_limit') ?? false)) {
        return 'Demasiados intentos. Espera unos minutos antes de reintentar.';
      }
      return switch (error.code) {
        'provider_unavailable' ||
        'provider_disabled' => 'Este método todavía no está disponible.',
        'browser_unavailable' =>
          'No se pudo abrir el navegador. Inténtalo de nuevo.',
        'otp_expired' || 'otp_disabled' =>
          'El código es incorrecto o ha vencido. Solicita uno nuevo.',
        'invalid_credentials' => 'Los datos o el código no son correctos.',
        'email_not_confirmed' => 'Primero confirma tu correo electrónico.',
        _ => 'No se pudo completar el acceso. Inténtalo de nuevo.',
      };
    }
    return 'Comprueba tu conexión y vuelve a intentarlo.';
  }

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }
}
