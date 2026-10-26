import 'package:flutter/material.dart';

import '../../../sky/sky_logo.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';

import 'register_screen.dart';

class SeleccionTipoCuentaScreen extends StatelessWidget {
  const SeleccionTipoCuentaScreen({super.key, this.devolverResultado = false});

  final bool devolverResultado;

  Future<void> _abrirRegistro(
    BuildContext context,
    TipoCuenta tipoCuenta,
  ) async {
    final cuentaCreada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RegisterScreen(
          tipoCuenta: tipoCuenta,
          devolverResultado: devolverResultado,
        ),
      ),
    );

    if (cuentaCreada == true && devolverResultado && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Crear cuenta',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: sky.headerGradient),
        ),
      ),
      body: SkySurface(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: sky.headerGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkyHorizontalLogo(
                            markSize: 38,
                            wordSize: 27,
                            onDark: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 22),
                      Text(
                        '¿Cómo quieres usar Cercly?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Elige el tipo de cuenta que mejor se adapta a lo que quieres hacer.',
                        style: TextStyle(
                          color: Color(0xFFD9E9FF),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _OpcionCuenta(
                  key: const Key('registro-como-usuario'),
                  icono: Icons.person_outline_rounded,
                  titulo: 'Como usuario',
                  descripcion: 'Descubre lugares, consulta promociones y personaliza tu experiencia.',
                  etiqueta: 'Para descubrir',
                  onTap: () => _abrirRegistro(context, TipoCuenta.usuario),
                ),
                const SizedBox(height: 12),
                _OpcionCuenta(
                  key: const Key('registro-como-propietario'),
                  icono: Icons.storefront_outlined,
                  titulo: 'Como propietario de un negocio',
                  descripcion: 'Registra, reclama y administra la información de tu establecimiento.',
                  etiqueta: 'Para negocios',
                  onTap: () => _abrirRegistro(context, TipoCuenta.propietario),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcionCuenta extends StatelessWidget {
  const _OpcionCuenta({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.etiqueta,
    required this.onTap,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Material(
      color: sky.surface,
      elevation: 1,
      shadowColor: sky.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [sky.soft, sky.soft],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icono, size: 30, color: sky.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sky.soft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        etiqueta,
                        style: TextStyle(
                          color: sky.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titulo,
                      style: TextStyle(
                        color: sky.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      descripcion,
                      style: TextStyle(
                        color: sky.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: sky.primary,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
