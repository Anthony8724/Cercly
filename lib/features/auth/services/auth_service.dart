import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

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

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }
}
