import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/auth_options.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({
    super.key,
    this.service,
    this.recovery = false,
    this.onComplete,
  });
  final AuthService? service;
  final bool recovery;
  final VoidCallback? onComplete;
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  bool _busy = false, _hidden = true;
  String? _message;
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = widget.service ?? AuthService();
      if (widget.recovery) {
        await service.updatePassword(_value.text);
      } else {
        await service.resetPassword(_value.text);
      }
      if (!mounted) return;
      _value.clear();
      setState(
        () => _message = widget.recovery ? 'Contraseña actualizada.' : 'Si el correo está registrado, recibirás un enlace para recuperar tu cuenta.',
      );
      if (widget.recovery) widget.onComplete?.call();
    } catch (e) {
      if (mounted) setState(() => _message = AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.recovery ? 'Nueva contraseña' : 'Recuperar contraseña',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _value,
                    enabled: !_busy,
                    obscureText: widget.recovery && _hidden,
                    keyboardType: widget.recovery
                        ? TextInputType.visiblePassword
                        : TextInputType.emailAddress,
                    autofillHints: [
                      widget.recovery
                          ? AutofillHints.newPassword
                          : AutofillHints.email,
                    ],
                    decoration: InputDecoration(
                      labelText: widget.recovery
                          ? 'Nueva contraseña'
                          : 'Correo electrónico',
                      suffixIcon: widget.recovery
                          ? IconButton(
                              tooltip: _hidden
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            )
                          : null,
                    ),
                    validator: widget.recovery
                        ? (v) => (v?.length ?? 0) < 8
                              ? 'Usa al menos 8 caracteres'
                              : null
                        : validarCorreo,
                  ),
                  if (widget.recovery) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      enabled: !_busy,
                      obscureText: _hidden,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                      ),
                      validator: (v) => v != _value.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Procesando…'
                          : widget.recovery
                          ? 'Guardar contraseña'
                          : 'Enviar enlace',
                    ),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
