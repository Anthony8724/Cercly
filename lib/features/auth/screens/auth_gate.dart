import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../administracion/screens/panel_administrador_screen.dart';
import '../../establecimientos/screens/panel_establecimiento_screen.dart';
import '../../explorar/screens/navegacion_principal_screen.dart';
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
          return const _PantallaCarga();
        }

        final usuario = snapshot.data;

        if (usuario == null) {
          return unauthenticatedBuilder?.call(context) ?? const LoginScreen();
        }

        if (authenticatedBuilder != null) {
          return authenticatedBuilder!(context);
        }

        return _PantallaSegunRol(usuarioId: usuario.id);
      },
    );
  }
}

class _PantallaSegunRol extends StatefulWidget {
  const _PantallaSegunRol({required this.usuarioId});

  final String usuarioId;

  @override
  State<_PantallaSegunRol> createState() => _PantallaSegunRolState();
}

class _PantallaSegunRolState extends State<_PantallaSegunRol> {
  late Future<String> _rolFuture;

  @override
  void initState() {
    super.initState();
    _cargarRol();
  }

  void _cargarRol() {
    _rolFuture = _obtenerRol();
  }

  Future<String> _obtenerRol() async {
    final datos = await Supabase.instance.client
        .from('usuarios')
        .select('rol')
        .eq('id', widget.usuarioId)
        .single();

    return datos['rol'] as String? ?? 'usuario';
  }

  Future<void> _cerrarSesion() async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _rolFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PantallaCarga();
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cercly')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo obtener el rol del usuario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        setState(_cargarRol);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _cerrarSesion,
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final rol = snapshot.data ?? 'usuario';

        if (rol == 'administrador') {
          return const PanelAdministradorScreen();
        }

        return const NavegacionPrincipalScreen(
          negocioBuilder: _construirPanelNegocio,
        );
      },
    );
  }

  static Widget _construirPanelNegocio(BuildContext context) {
    return const PanelEstablecimientoScreen();
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
