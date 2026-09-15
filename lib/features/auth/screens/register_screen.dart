import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

typedef RegistrarCuenta = Future<bool> Function({
  required String nombre,
  required String email,
  required String password,
  required TipoCuenta tipoCuenta,
});

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    this.tipoCuenta = TipoCuenta.usuario,
    this.registrarCuenta,
    this.devolverResultado = false,
    super.key,
  });

  final TipoCuenta tipoCuenta;
  final RegistrarCuenta? registrarCuenta;
  final bool devolverResultado;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final registrarCuenta = widget.registrarCuenta;
      final bool requiresConfirmation;
      if (registrarCuenta == null) {
        final response = await AuthService().register(
          nombre: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          tipoCuenta: widget.tipoCuenta.name,
        );
        requiresConfirmation = response.session == null;
      } else {
        requiresConfirmation = await registrarCuenta(
          nombre: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          tipoCuenta: widget.tipoCuenta,
        );
      }

      if (!mounted) return;

      final message = requiresConfirmation
          ? 'Cuenta creada. Revisa tu correo para confirmarla'
          : 'Cuenta creada correctamente';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      if (requiresConfirmation) {
        Navigator.pop(context);
      } else if (widget.devolverResultado) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on AuthException catch (error) {
      if (!mounted) return;

      String message = 'No se pudo completar el registro';
      if (error.statusCode == '429' ||
          error.code == 'over_email_send_rate_limit') {
        message =
            'Se alcanzó temporalmente el límite de registros. '
            'Espera unos minutos e inténtalo nuevamente.';
      } else if (error.code == 'user_already_exists') {
        message = 'Este correo ya está registrado';
      } else if (error.code == 'weak_password') {
        message = 'La contraseña es demasiado débil';
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

  @override
  Widget build(BuildContext context) {
    final esPropietario = widget.tipoCuenta == TipoCuenta.propietario;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FE),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(
          esPropietario ? 'Cuenta de propietario' : 'Crear cuenta',
          style: const TextStyle(fontWeight: FontWeight.w800),
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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF031633), Color(0xFF1769FF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x22FFFFFF),
                        ),
                        child: Icon(
                          esPropietario
                              ? Icons.storefront_rounded
                              : Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esPropietario
                                  ? 'Haz crecer tu negocio en Cercly'
                                  : 'Crea tu cuenta Cercly',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              esPropietario
                                  ? 'Administra tu establecimiento y publica información para tus clientes.'
                                  : 'Guarda tus preferencias y descubre lugares cerca de ti.',
                              style: const TextStyle(
                                color: Color(0xFFDCEBFF),
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                        'Tus datos',
                        style: TextStyle(
                          color: Color(0xFF102A56),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Completa la información para crear tu cuenta.',
                        style: TextStyle(
                          color: Color(0xFF65758C),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: _inputDecoration(
                          label: 'Nombre completo',
                          icono: Icons.person_outline_rounded,
                        ),
                        validator: (value) {
                          final nombre = value?.trim() ?? '';

                          if (nombre.length < 2) {
                            return 'Ingresa un nombre válido';
                          }

                          if (nombre.length > 80) {
                            return 'El nombre no puede superar 80 caracteres';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
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
                        autofillHints: const [AutofillHints.newPassword],
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
                          if (value == null || value.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _inputDecoration(
                          label: 'Confirmar contraseña',
                          icono: Icons.verified_user_outlined,
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Las contraseñas no coinciden';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _register,
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
                                  'Crear cuenta',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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

enum TipoCuenta { usuario, propietario }
