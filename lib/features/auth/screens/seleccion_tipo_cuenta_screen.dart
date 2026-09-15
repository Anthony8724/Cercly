import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FE),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Crear cuenta',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF02142F), Color(0xFF0B5DD8)],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF031633), Color(0xFF1769FF)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cercly',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
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
                descripcion:
                    'Descubre lugares, consulta promociones y personaliza tu experiencia.',
                etiqueta: 'Para descubrir',
                onTap: () => _abrirRegistro(context, TipoCuenta.usuario),
              ),
              const SizedBox(height: 12),
              _OpcionCuenta(
                key: const Key('registro-como-propietario'),
                icono: Icons.storefront_outlined,
                titulo: 'Como propietario de un negocio',
                descripcion:
                    'Registra, reclama y administra la información de tu establecimiento.',
                etiqueta: 'Para negocios',
                onTap: () => _abrirRegistro(context, TipoCuenta.propietario),
              ),
            ],
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
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x1A0B4EA9),
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
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE6F0FF), Color(0xFFD8E9FF)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icono,
                  size: 30,
                  color: const Color(0xFF1769FF),
                ),
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
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        etiqueta,
                        style: const TextStyle(
                          color: Color(0xFF1769FF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Color(0xFF102A56),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: Color(0xFF65758C),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF1769FF),
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
