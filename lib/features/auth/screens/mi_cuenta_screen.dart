import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../../../sky/sky_logo.dart';
import '../../../sky/sky_backdrop.dart';

import '../services/auth_service.dart';
import 'account_mode_selector.dart';
import 'account_settings_screen.dart';
import '../../establecimientos/screens/mis_negocios_screen.dart';
import '../../establecimientos/services/establecimiento_service.dart';
import '../../preferencias/screens/mis_preferencias_screen.dart';
import '../../notificaciones/widgets/monitor_proximidad_app.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({
    super.key,
    this.authService,
    this.correo,
    this.cerrarSesion,
    this.negociosScreenBuilder,
    this.registroScreenBuilder,
    this.tieneNegocios,
    this.preferenciasScreenBuilder,
    this.mostrarConfiguracion = true,
  });

  final AuthService? authService;
  final String? correo;
  final Future<void> Function()? cerrarSesion;
  final WidgetBuilder? negociosScreenBuilder;
  final WidgetBuilder? registroScreenBuilder;
  final Future<bool> Function()? tieneNegocios;
  final WidgetBuilder? preferenciasScreenBuilder;
  final bool mostrarConfiguracion;

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  late Future<bool> _relacionConNegocios;

  @override
  void initState() {
    super.initState();
    _relacionConNegocios = _consultarNegocios();
  }

  Future<bool> _consultarNegocios() async {
    try {
      final rows =
          await (widget.tieneNegocios?.call() ??
              EstablecimientoService().listarEstablecimientosDelUsuario().then(
                (items) => items.isNotEmpty,
              ));
      return rows;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final servicio =
        widget.authService ??
        (widget.correo == null || widget.cerrarSesion == null
            ? AuthService()
            : null);
    final correoVisible =
        widget.correo ??
        servicio?.currentUser?.email ??
        servicio?.currentUser?.phone ??
        'Usuario de Cercly';

    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Mi cuenta',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: sky.headerGradient),
        ),
      ),
      body: SkySurface(
        intensity: .8,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: sky.headerGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: sky.primary.withValues(alpha: .14),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sky.onPrimary.withValues(alpha: .14),
                          border: Border.all(
                            color: sky.onPrimary.withValues(alpha: .5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 46,
                          color: sky.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SkyHorizontalLogo(
                        markSize: 36,
                        wordSize: 28,
                        onDark: true,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        correoVisible,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sky.onPrimary.withValues(alpha: .88),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const AccountModeSelector(),
                if ((AccountModeScope.maybeOf(context)
                            ?.capabilities
                            .availableModes
                            .length ??
                        0) >
                    1)
                  const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sky.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sky.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: sky.soft,
                        child: Icon(
                          Icons.explore_outlined,
                          color: sky.interactive,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu experiencia Cercly',
                              style: TextStyle(
                                color: sky.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Explora lugares y promociones manteniendo tu sesión activa.',
                              style: TextStyle(
                                color: sky.muted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.mostrarConfiguracion)
                  OutlinedButton.icon(
                    key: const Key('abrir-configuracion-cuenta'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MonitorProximidadScope.wrapRouteIfAvailable(
                              context: context,
                              child: ConfiguracionCuentaScreen(
                                registroScreenBuilder:
                                    widget.registroScreenBuilder,
                              ),
                            ),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Configuración'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('abrir-mis-preferencias'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          widget.preferenciasScreenBuilder ??
                          (_) => const MisPreferenciasScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Mis preferencias'),
                ),
                FutureBuilder<bool>(
                  future: _relacionConNegocios,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          Text(
                            'No pudimos comprobar tus establecimientos. Mis negocios permanecerá oculto hasta verificar el acceso.',
                            style: TextStyle(color: sky.muted),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _relacionConNegocios = _consultarNegocios(),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      );
                    }
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return OutlinedButton.icon(
                      key: const Key('abrir-mis-negocios'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              widget.negociosScreenBuilder ??
                              (_) => const MisNegociosScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Mis negocios'),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    key: const Key('cerrar-sesion-cuenta'),
                    onPressed: () async {
                      try {
                        await (widget.cerrarSesion ?? servicio!.signOut)();
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AuthService.errorMessage(error)),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: sky.error,
                      side: BorderSide(color: sky.error.withValues(alpha: .45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
