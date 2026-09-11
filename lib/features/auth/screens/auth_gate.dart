import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.authStateChanges,
    this.unauthenticatedBuilder,
    this.authenticatedBuilder,
  });

  final Stream<User?>? authStateChanges;
  final WidgetBuilder? unauthenticatedBuilder;
  final WidgetBuilder? authenticatedBuilder;

  @override
  Widget build(BuildContext context) {
    final userStream = authStateChanges ?? AuthService().authStateChanges;

    return StreamBuilder<User?>(
      stream: userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return authenticatedBuilder?.call(context) ??
              const AuthenticatedScreen();
        }

        return unauthenticatedBuilder?.call(context) ?? const LoginScreen();
      },
    );
  }
}

class AuthenticatedScreen extends StatelessWidget {
  const AuthenticatedScreen({super.key});

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? 'Sin correo';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del establecimiento'),
        actions: [
          IconButton(
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Sesión iniciada como:\n$email',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
