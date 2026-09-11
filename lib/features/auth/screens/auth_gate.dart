import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../establecimientos/screens/panel_establecimiento_screen.dart';
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
              const PanelEstablecimientoScreen();
        }

        return unauthenticatedBuilder?.call(context) ?? const LoginScreen();
      },
    );
  }
}
