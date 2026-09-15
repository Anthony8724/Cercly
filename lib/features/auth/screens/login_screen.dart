import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'seleccion_tipo_cuenta_screen.dart';

typedef IniciarSesion = Future<void> Function({
  required String email,
  required String password,
});

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.iniciarSesion,
    this.devolverResultado = false,
  });

  final IniciarSesion? iniciarSesion;
  final bool devolverResultado;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final iniciarSesion = widget.iniciarSesion;
      if (iniciarSesion == null) {
        await AuthService().signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await iniciarSesion(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesión correcto')),
      );
      if (widget.devolverResultado) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on AuthException catch (error) {
      if (!mounted) return;

      String message = 'No se pudo iniciar sesión';

      if (error.code == 'invalid_credentials') {
        message = 'Correo o contraseña incorrectos';
      } else if (error.code == 'email_not_confirmed') {
        message = 'Primero debes confirmar tu correo electrónico';
      } else if (error.code == 'validation_failed') {
        message = 'El correo electrónico no es válido';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error inesperado')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openRegister() async {
    final cuentaCreada = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SeleccionTipoCuentaScreen(
          devolverResultado: widget.devolverResultado,
        ),
      ),
    );

    if (cuentaCreada == true && widget.devolverResultado && mounted) {
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
          'Iniciar sesión',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LoginHero(),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x180B4EA9),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '¡Hola de nuevo!',
                        style: TextStyle(
                          color: Color(0xFF102A56),
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Inicia sesión para continuar en Cercly.',
                        style: TextStyle(
                          color: Color(0xFF65758C),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: _inputDecoration(
                          label: 'Correo electrónico',
                          icono: Icons.mail_outline_rounded,
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Ingresa tu correo electrónico';
                          }

                          if (!email.contains('@')) {
                            return 'Ingresa un correo válido';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: _inputDecoration(
                          label: 'Contraseña',
                          icono: Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF65758C),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1769FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Iniciar sesión',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isLoading ? null : _openRegister,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1769FF),
                        ),
                        child: const Text(
                          '¿No tienes una cuenta? Crear cuenta',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icono,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icono, color: const Color(0xFF1769FF)),
      filled: true,
      fillColor: const Color(0xFFF8FAFE),
      labelStyle: const TextStyle(color: Color(0xFF65758C)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE5F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1769FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF031633), Color(0xFF0B5DD8)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Color(0x22FFFFFF),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cercly',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Tu mundo más cerca',
                  style: TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF8CCBFF),
          ),
        ],
      ),
    );
  }
}
