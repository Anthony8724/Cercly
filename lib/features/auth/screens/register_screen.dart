import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../sky/sky_logo.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/auth_options.dart';

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
    if (_isLoading || !_formKey.currentState!.validate()) return;

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

      String message = AuthService.errorMessage(error);
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
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final esPropietario = widget.tipoCuenta == TipoCuenta.propietario;

    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(
          esPropietario ? 'Cuenta de propietario' : 'Crear cuenta',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: sky.headerGradient),
        ),
      ),
      body: SkySurface(
        intensity: .42,
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: 560,
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
                          gradient: sky.headerGradient,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            const SkyMark(size: 62),
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
                                        ? 'Solicita acceso a tu negocio. Los permisos requieren aprobación administrativa.'
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
                          color: sky.surface,
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
                            Text(
                              'Tus datos',
                              style: TextStyle(
                                color: sky.text,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Completa la información para crear tu cuenta.',
                              style: TextStyle(
                                color: sky.muted,
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
                              validator: validarCorreo,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration:
                                  _inputDecoration(
                                    label: 'Contraseña',
                                    icono: Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      tooltip: _hidePassword
                                          ? 'Mostrar contraseña'
                                          : 'Ocultar contraseña',
                                      onPressed: () {
                                        setState(() {
                                          _hidePassword = !_hidePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: sky.muted,
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
                                  backgroundColor: sky.primary,
                                  foregroundColor: sky.onPrimary,
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
                            const SizedBox(height: 8),
                            TextButton.icon(
                              key: const Key(
                                'abrir-politica-privacidad-registro',
                              ),
                              onPressed: () => launchUrl(
                                Uri.parse(
                                  'https://cercly-web.vercel.app/privacidad',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.privacy_tip_outlined),
                              label: const Text('Leer política de privacidad'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    final sky = SkyPalette.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icono, color: sky.primary),
      filled: true,
      fillColor: sky.inputFill,
      labelStyle: TextStyle(color: sky.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: sky.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: sky.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: sky.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: sky.error, width: 1.5),
      ),
    );
  }
}

enum TipoCuenta { usuario, propietario }
