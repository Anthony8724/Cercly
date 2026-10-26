import 'dart:async';

import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../../../sky/sky_logo.dart';
import '../../../sky/sky_backdrop.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'seleccion_tipo_cuenta_screen.dart';
import 'password_screen.dart';
import 'phone_auth_screen.dart';
import '../services/auth_options.dart';

typedef IniciarSesion = Future<void> Function({
  required String email,
  required String password,
});

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.iniciarSesion,
    this.service,
    this.devolverResultado = false,
  });

  final AuthService? service;
  final IniciarSesion? iniciarSesion;
  final bool devolverResultado;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StreamSubscription<AuthState>? _oauthSubscription;
  String? _providerMessage;
  bool _oauthPending = false;
  bool _oauthCompleted = false;
  Timer? _oauthTimer;
  int _oauthAttempt = 0;
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _oauthTimer?.cancel();
    _oauthSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading || _oauthPending || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final iniciarSesion = widget.iniciarSesion;
      if (iniciarSesion == null) {
        await (widget.service ?? AuthService()).signIn(
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

      String message = AuthService.errorMessage(error);

      if (error.code == 'invalid_credentials') {
        message = 'Correo o contraseña incorrectos';
      } else if (error.code == 'email_not_confirmed') {
        message = 'Primero debes confirmar tu correo electrónico';
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

  Future<void> _provider(MetodoAcceso metodo) async {
    if (_isLoading || _oauthPending) return;
    final service = widget.service ?? AuthService();
    if (!service.options.disponible(metodo)) return;
    if (metodo == MetodoAcceso.celular) {
      setState(() => _isLoading = true);
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PhoneAuthScreen(service: service),
        ),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success != true) return;
      if (widget.devolverResultado) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _providerMessage = null;
      _oauthPending = true;
      _oauthCompleted = false;
    });
    final attempt = ++_oauthAttempt;
    _oauthTimer?.cancel();
    _oauthTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && _oauthPending && attempt == _oauthAttempt) {
        _cancelOAuth(
          message: 'El acceso no se completó. Puedes intentarlo de nuevo.',
        );
      }
    });
    _oauthSubscription ??= service.events.listen(
      (state) {
        if (!mounted ||
            _oauthCompleted ||
            state.event != AuthChangeEvent.signedIn ||
            state.session == null) {
          return;
        }
        _oauthPending = false;
        _oauthCompleted = true;
        _oauthTimer?.cancel();
        if (widget.devolverResultado) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      onError: (Object error) {
        if (mounted && _oauthPending) {
          _oauthTimer?.cancel();
          setState(() {
            _oauthPending = false;
            _providerMessage = AuthService.errorMessage(error);
          });
        }
      },
    );
    try {
      await service
          .signInWithProvider(metodo)
          .timeout(const Duration(seconds: 15));
      if (mounted && _oauthPending && attempt == _oauthAttempt) {
        setState(
          () => _providerMessage = 'Continúa en el navegador. Si cancelaste, puedes intentarlo de nuevo.',
        );
      }
    } catch (e) {
      if (mounted && attempt == _oauthAttempt) {
        _oauthTimer?.cancel();
        setState(() {
          _oauthPending = false;
          _providerMessage = AuthService.errorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelOAuth({
    String message = 'Acceso cancelado. Puedes intentarlo de nuevo.',
  }) {
    _oauthTimer?.cancel();
    setState(() {
      _oauthAttempt++;
      _oauthPending = false;
      _isLoading = false;
      _providerMessage = message;
    });
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
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Iniciar sesión',
          style: TextStyle(fontWeight: FontWeight.w800),
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
                              '¡Hola de nuevo!',
                              style: TextStyle(
                                color: sky.text,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Inicia sesión para continuar en Cercly.',
                              style: TextStyle(color: sky.muted, fontSize: 13),
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
                              validator: validarCorreo,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              autofillHints: const [AutofillHints.password],
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
                                onPressed: (_isLoading || _oauthPending)
                                    ? null
                                    : _signIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: sky.primary,
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
                            TextButton(
                              onPressed: (_isLoading || _oauthPending)
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PasswordScreen(
                                          service: widget.service,
                                        ),
                                      ),
                                    ),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'O continúa con',
                                    style: TextStyle(
                                      color: sky.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            for (final metodo in MetodoAcceso.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  height: 54,
                                  child: OutlinedButton(
                                    onPressed:
                                        _isLoading ||
                                            _oauthPending ||
                                            !(widget.service?.options ??
                                                    const AuthOptions())
                                                .disponible(metodo)
                                        ? null
                                        : () => _provider(metodo),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: sky.surface,
                                      disabledBackgroundColor: sky.surface,
                                      side: BorderSide(color: sky.border),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: sky.soft,
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: metodo == MetodoAcceso.google
                                              ? const Text(
                                                  'G',
                                                  style: TextStyle(
                                                    color: Color(0xFF4285F4),
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                )
                                              : Icon(
                                                  switch (metodo) {
                                                    MetodoAcceso.microsoft =>
                                                      Icons.window_rounded,
                                                    MetodoAcceso.facebook =>
                                                      Icons.facebook_rounded,
                                                    MetodoAcceso.celular =>
                                                      Icons
                                                          .phone_android_rounded,
                                                    MetodoAcceso.google =>
                                                      Icons.language_rounded,
                                                  },
                                                  color:
                                                      metodo ==
                                                          MetodoAcceso.facebook
                                                      ? const Color(0xFF1877F2)
                                                      : const Color(0xFF1769FF),
                                                  size: 22,
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _nombreMetodo(metodo),
                                            style: TextStyle(
                                              color: sky.text,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (!(widget.service?.options ??
                                                const AuthOptions())
                                            .disponible(metodo))
                                          Text(
                                            'Próximamente',
                                            style: TextStyle(
                                              color: sky.muted,
                                              fontSize: 11,
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: sky.primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (_oauthPending)
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _cancelOAuth(),
                                child: const Text('Cancelar intento'),
                              ),
                            if (_providerMessage != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(_providerMessage!),
                              ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: (_isLoading || _oauthPending)
                                  ? null
                                  : _openRegister,
                              style: TextButton.styleFrom(
                                foregroundColor: sky.primary,
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
          ),
        ),
      ),
    );
  }

  String _nombreMetodo(MetodoAcceso metodo) => switch (metodo) {
    MetodoAcceso.google => 'Google',
    MetodoAcceso.microsoft => 'Microsoft',
    MetodoAcceso.facebook => 'Facebook',
    MetodoAcceso.celular => 'Celular',
  };

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

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: SkyPalette.of(context).headerGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          SkyMark(size: 60),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkyWordmark(size: 28, onDark: true),
                SizedBox(height: 5),
                Text(
                  'Descubre lugares cerca de ti',
                  style: TextStyle(color: Color(0xFFDCEBFF), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
