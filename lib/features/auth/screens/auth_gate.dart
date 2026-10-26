import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/cercly_ui.dart';
import '../../../sky/sky_logo.dart';

import '../../administracion/screens/panel_administrador_screen.dart';
import '../../establecimientos/screens/panel_establecimiento_screen.dart';
import '../../explorar/controllers/explorar_controller.dart';
import '../../explorar/screens/navegacion_principal_screen.dart';
import '../../usuarios/models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'acceso_publico_screen.dart';
import 'mi_cuenta_screen.dart';

typedef CargarRolUsuario = Future<String> Function(String usuarioId);
typedef ConstruirNavegacionCuenta = Widget Function(
  BuildContext context,
  DestinoCuenta destino,
);

enum DestinoCuenta { registro, cuenta, negocio, administrador }

DestinoCuenta resolverDestinoCuenta({
  required String rol,
  Map<String, dynamic>? metadatos,
}) {
  if (rol == UsuarioModel.rolAdministrador) {
    return DestinoCuenta.administrador;
  }
  if (rol == UsuarioModel.rolPropietario) {
    return DestinoCuenta.negocio;
  }
  return DestinoCuenta.cuenta;
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authStateChanges,
    this.unauthenticatedBuilder,
    this.authenticatedBuilder,
    this.cargarRol,
    this.construirNavegacion,
    this.explorarController,
    this.service,
  });

  final AuthService? service;
  final Stream<User?>? authStateChanges;
  final WidgetBuilder? unauthenticatedBuilder;
  final WidgetBuilder? authenticatedBuilder;
  final CargarRolUsuario? cargarRol;
  final ConstruirNavegacionCuenta? construirNavegacion;
  final ExplorarController? explorarController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _stream;
  bool _retryingSession = false;
  Object? _retryError;

  Future<void> _retrySession() async {
    if (_retryingSession) return;
    setState(() {
      _retryingSession = true;
      _retryError = null;
    });
    try {
      if (widget.authStateChanges == null) {
        await (widget.service ?? AuthService()).retrySession();
      } else {
        _subscribe();
      }
    } catch (error) {
      _retryError = error;
    } finally {
      if (mounted) setState(() => _retryingSession = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final source =
        widget.authStateChanges ??
        (widget.service ?? AuthService()).authStateChanges;
    _stream = Stream<User?>.multi((controller) {
      final timer = Timer(const Duration(seconds: 15), () {
        controller.addError(TimeoutException('session'));
      });
      final subscription = source.listen(
        (user) {
          timer.cancel();
          controller.add(user);
        },
        onError: (Object error, StackTrace stack) {
          timer.cancel();
          controller.addError(error, stack);
        },
        onDone: () {
          timer.cancel();
          controller.close();
        },
      );
      controller.onCancel = () {
        timer.cancel();
        return subscription.cancel();
      };
    });
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authStateChanges != widget.authStateChanges ||
        oldWidget.service != widget.service) {
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _stream,
      initialData: widget.authStateChanges == null
          ? (widget.service ?? AuthService()).currentUser
          : null,
      builder: (context, snapshot) {
        if (_retryingSession) {
          return const _PantallaCarga(message: 'Comprobando sesión…');
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AuthService.errorMessage(
                          _retryError ?? snapshot.error!,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _retrySession,
                        child: const Text('Reintentar'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await (widget.service ?? AuthService()).signOut();
                            if (mounted) setState(_subscribe);
                          } catch (_) {
                            if (mounted) setState(_subscribe);
                          }
                        },
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _PantallaCarga(message: 'Comprobando sesión…');
        }

        final usuario = snapshot.data;

        if (usuario == null) {
          return widget.unauthenticatedBuilder?.call(context) ??
              _construirNavegacionPredeterminada(
                context,
                DestinoCuenta.registro,
                controller: widget.explorarController,
              );
        }

        if (widget.authenticatedBuilder != null) {
          return widget.authenticatedBuilder!(context);
        }

        final constructor =
            widget.construirNavegacion ??
            (context, destino) => _construirNavegacionPredeterminada(
              context,
              destino,
              controller: widget.explorarController,
            );

        return _PantallaSegunRol(
          key: ValueKey(usuario.id),
          usuario: usuario,
          service: widget.service ?? AuthService(),
          cargarRol: widget.cargarRol ?? _cargarRolPredeterminado,
          construirNavegacion: constructor,
        );
      },
    );
  }

  static Future<String> _cargarRolPredeterminado(String usuarioId) =>
      ProfileService().loadRole(usuarioId);

  static Widget _construirNavegacionPredeterminada(
    BuildContext context,
    DestinoCuenta destino, {
    ExplorarController? controller,
  }) {
    if (destino == DestinoCuenta.administrador) {
      return const PanelAdministradorScreen();
    }

    late final WidgetBuilder terceraOpcionBuilder;
    late final String etiqueta;
    late final IconData icono;
    late final IconData iconoSeleccionado;

    switch (destino) {
      case DestinoCuenta.registro:
        terceraOpcionBuilder = (_) => const AccesoPublicoScreen();
        etiqueta = 'Regístrate';
        icono = Icons.person_add_outlined;
        iconoSeleccionado = Icons.person_add;
        break;
      case DestinoCuenta.cuenta:
        terceraOpcionBuilder = (_) => const MiCuentaScreen();
        etiqueta = 'Mi cuenta';
        icono = Icons.person_outline;
        iconoSeleccionado = Icons.person;
        break;
      case DestinoCuenta.negocio:
        terceraOpcionBuilder = (_) => const PanelEstablecimientoScreen();
        etiqueta = 'Mi negocio';
        icono = Icons.storefront_outlined;
        iconoSeleccionado = Icons.storefront;
        break;
      case DestinoCuenta.administrador:
        throw StateError('El administrador no utiliza navegación pública.');
    }

    return NavegacionPrincipalScreen(
      terceraOpcionBuilder: terceraOpcionBuilder,
      terceraOpcionLabel: etiqueta,
      terceraOpcionIcon: icono,
      terceraOpcionSelectedIcon: iconoSeleccionado,
      controller: controller,
    );
  }
}

class _PantallaSegunRol extends StatefulWidget {
  const _PantallaSegunRol({
    super.key,
    required this.service,
    required this.usuario,
    required this.cargarRol,
    required this.construirNavegacion,
  });

  final AuthService service;
  final User usuario;
  final CargarRolUsuario cargarRol;
  final ConstruirNavegacionCuenta construirNavegacion;

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

  @override
  void didUpdateWidget(covariant _PantallaSegunRol oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario != widget.usuario) _cargarRol();
  }

  void _cargarRol() {
    _rolFuture = _obtenerRol();
  }

  Future<String> _obtenerRol() async {
    final role = await widget
        .cargarRol(widget.usuario.id)
        .timeout(const Duration(seconds: 15));
    if (!UsuarioModel.rolesPermitidos.contains(role)) {
      throw const ProfileException(ProfileFailure.inconsistent);
    }
    return role;
  }

  Future<void> _cerrarSesion() async {
    try {
      await widget.service.signOut().timeout(const Duration(seconds: 15));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(error))),
        );
      }
    }
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
            backgroundColor: CerclyColors.background,
            body: Column(
              children: [
                const CerclyPageHeader(
                  title: 'Cercly',
                  subtitle: 'No pudimos cargar tu cuenta',
                  icon: Icons.person_rounded,
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: CerclySectionCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFEEEE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    size: 38,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No pudimos cargar tu perfil.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CerclyColors.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AuthService.errorMessage(snapshot.error!),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: CerclyColors.muted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      setState(_cargarRol);
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: CerclyColors.blue,
                                    ),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text(
                                      'Reintentar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _cerrarSesion,
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('Cerrar sesión'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final destino = resolverDestinoCuenta(
          rol: snapshot.data ?? UsuarioModel.rolUsuario,
          metadatos: widget.usuario.userMetadata,
        );
        return widget.construirNavegacion(context, destino);
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga({this.message = 'Cargando tu perfil…'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerclyColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkyMark(size: 54),
            SizedBox(height: 14),
            SkyWordmark(size: 24),
            Text(message),
            const SizedBox(height: 16),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: CerclyColors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
