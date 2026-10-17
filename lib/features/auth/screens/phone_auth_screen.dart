import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/auth_options.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.service, this.now});
  final AuthService? service;
  final DateTime Function()? now;
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController(text: '+593');
  final _code = TextEditingController();
  late final AuthService _service = widget.service ?? AuthService();
  bool _busy = false;
  String? _sentPhone, _error;
  DateTime? _nextSend;
  Timer? _timer;
  DateTime get _now => (widget.now ?? DateTime.now)();
  int get _remaining {
    final milliseconds = _nextSend?.difference(_now).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void _cooldown() {
    _nextSend = _now.add(const Duration(seconds: 60));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == 0) _timer?.cancel();
    });
  }

  Future<void> _send() async {
    if (_busy || _remaining > 0) return;
    if (_sentPhone == null && !_form.currentState!.validate()) return;
    final phone = _sentPhone ?? _phone.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    // También limita reintentos después de errores de red o del proveedor.
    _cooldown();
    try {
      await _service.requestPhoneOtp(phone);
      if (mounted) {
        setState(() {
          _sentPhone = phone;
          _code.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || !_form.currentState!.validate()) return;
    final code = _code.text;
    _code.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.verifyPhoneOtp(_sentPhone!, code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _sentPhone == null ? 'Acceso con celular' : 'Verifica tu celular',
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
                  const Icon(
                    Icons.sms_outlined,
                    size: 52,
                    color: Color(0xFF1769FF),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _sentPhone == null
                        ? 'Te enviaremos un código por SMS para crear tu cuenta o iniciar sesión.'
                        : 'Ingresa el código enviado a $_sentPhone.',
                  ),
                  const SizedBox(height: 20),
                  if (_sentPhone == null)
                    TextFormField(
                      key: const ValueKey('phone'),
                      controller: _phone,
                      enabled: !_busy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Número internacional',
                        helperText:
                            'Incluye + y el código de país, sin espacios.',
                        helperMaxLines: 3,
                      ),
                      validator: validarTelefono,
                    )
                  else
                    TextFormField(
                      key: const ValueKey('otp'),
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Código de 6 dígitos',
                      ),
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                          ? null
                          : 'Ingresa los 6 dígitos del SMS',
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy || (_sentPhone == null && _remaining > 0)
                        ? null
                        : _sentPhone == null
                        ? _send
                        : _verify,
                    child: Text(
                      _busy
                          ? 'Procesando…'
                          : _sentPhone == null
                          ? 'Enviar código'
                          : 'Verificar código',
                    ),
                  ),
                  if (_remaining > 0)
                    Text(
                      'Podrás reenviar en $_remaining s',
                      textAlign: TextAlign.center,
                    ),
                  if (_sentPhone != null) ...[
                    TextButton(
                      onPressed: _busy || _remaining > 0 ? null : _send,
                      child: const Text('Reenviar código'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _sentPhone = null;
                              _code.clear();
                              _error = null;
                            }),
                      child: const Text('Cambiar número'),
                    ),
                  ],
                  if (_error != null)
                    Semantics(liveRegion: true, child: Text(_error!)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
