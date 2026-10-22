import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'password_screen.dart';

/// Observa también el regreso OAuth/recuperación al abrir la app desde cero.
class AuthRecoveryHost extends StatefulWidget {
  const AuthRecoveryHost({
    super.key,
    required this.child,
    this.events,
    this.service,
  });
  final Widget child;
  final Stream<AuthState>? events;
  final AuthService? service;
  @override
  State<AuthRecoveryHost> createState() => _AuthRecoveryHostState();
}

class _AuthRecoveryHostState extends State<AuthRecoveryHost> {
  StreamSubscription<AuthState>? _subscription;
  bool _recovering = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _subscription =
        (widget.events ?? Supabase.instance.client.auth.onAuthStateChange)
            .listen(
              (state) {
                if (!mounted) return;
                if (state.event == AuthChangeEvent.passwordRecovery &&
                    state.session != null) {
                  setState(() {
                    _recovering = true;
                    _error = null;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  });
                } else if (state.event == AuthChangeEvent.signedOut) {
                  setState(() {
                    _recovering = false;
                    _error =
                        state.signOutReason != null &&
                            state.signOutReason != SignOutReason.userInitiated
                        ? 'Tu sesión venció. Inicia sesión de nuevo.'
                        : null;
                  });
                } else if (state.session != null) {
                  setState(() => _error = null);
                }
              },
              onError: (Object error) {
                if (mounted) {
                  setState(() => _error = AuthService.errorMessage(error));
                }
              },
            );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering) {
      return PasswordScreen(
        service: widget.service,
        recovery: true,
        onComplete: () => setState(() => _recovering = false),
      );
    }
    return Column(
      children: [
        if (_error != null)
          Material(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(liveRegion: true, child: Text(_error!)),
                    ),
                    IconButton(
                      tooltip: 'Cerrar aviso',
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
