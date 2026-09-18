import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/cercly_ui.dart';

import '../../administracion/screens/panel_administrador_screen.dart';
import '../../establecimientos/screens/panel_establecimiento_screen.dart';
import '../../explorar/controllers/explorar_controller.dart';
import '../../explorar/screens/navegacion_principal_screen.dart';
import '../../usuarios/models/usuario_model.dart';
import '../services/auth_service.dart';
import 'acceso_publico_screen.dart';
import 'mi_cuenta_screen.dart';

typedef CargarRolUsuario = Future<String> Function(String usuarioId);
typedef ConstruirNavegacionCuenta =
    Widget Function(BuildContext context, DestinoCuenta destino);

enum DestinoCuenta { registro, cuenta, negocio, administrador }

DestinoCuenta resolverDestinoCuenta({
  required String rol,
  Map<String, dynamic>? metadatos,
}) {
  if (rol == UsuarioModel.rolAdministrador) {
    return DestinoCuenta.administrador;
  }
  if (rol == UsuarioModel.rolPropietario ||
      metadatos?['tipo_cuenta'] == UsuarioModel.rolPropietario) {
    return DestinoCuenta.negocio;
  }
  return DestinoCuenta.cuenta;
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.authStateChanges,
    this.unauthenticatedBuilder,
    this.authenticatedBuilder,
    this.cargarRol,
    this.construirNavegacion,
    this.explorarController,
  });

  final Stream<User?>? authStateChanges;
  final WidgetBuilder? unauthenticatedBuilder;
  final WidgetBuilder? authenticatedBuilder;
  final CargarRolUsuario? cargarRol;
  final ConstruirNavegacionCuenta? construirNavegacion;
  final ExplorarController? explorarController;

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
          return unauthenticatedBuilder?.call(context) ??
              _construirNavegacionPredeterminada(
                context,
                DestinoCuenta.registro,
                controller: explorarController,
              );
        }

        if (authenticatedBuilder != null) {
          return authenticatedBuilder!(context);
        }

        final constructor =
            construirNavegacion ??
            (context, destino) => _construirNavegacionPredeterminada(
              context,
              destino,
              controller: explorarController,
            );

        return _PantallaSegunRol(
          usuario: usuario,
          cargarRol: cargarRol ?? _cargarRolPredeterminado,
          construirNavegacion: constructor,
        );
      },
    );
  }

  static Future<String> _cargarRolPredeterminado(String usuarioId) async {
    final datos = await Supabase.instance.client
        .from('usuarios')
        .select('rol')
        .eq('id', usuarioId)
        .single();
    return datos['rol'] as String? ?? UsuarioModel.rolUsuario;
  }

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
    required this.usuario,
    required this.cargarRol,
    required this.construirNavegacion,
  });

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

  void _cargarRol() {
    _rolFuture = _obtenerRol();
  }

  Future<String> _obtenerRol() async {
    return widget.cargarRol(widget.usuario.id);
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
                                'No se pudo obtener el rol del usuario.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: CerclyColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
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
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: CerclyColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: CerclyColors.blue,
              size: 46,
            ),
            SizedBox(height: 14),
            Text(
              'Cercly',
              style: TextStyle(
                color: CerclyColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
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
