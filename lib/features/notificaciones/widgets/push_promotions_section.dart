import 'dart:async';

import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../models/configuracion_alertas_proximidad.dart';
import '../services/preferencias_alertas_proximidad.dart';
import '../push/fcm_push_service.dart';

class PushPromotionsSection extends StatefulWidget {
  const PushPromotionsSection({
    required this.preferences,
    required this.initialEnabled,
    this.service,
    super.key,
  });

  final PreferenciasAlertasProximidadRepository preferences;
  final bool initialEnabled;
  final FcmPushService? service;

  @override
  State<PushPromotionsSection> createState() => _PushPromotionsSectionState();
}

class _PushPromotionsSectionState extends State<PushPromotionsSection> {
  late final FcmPushService _service = widget.service ?? FcmPushService.shared;
  bool _enabled = false;
  bool _loading = true;
  bool _busy = false;
  String? _message;
  StreamSubscription<ConfiguracionAlertasProximidad>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.preferences.cambios.listen((config) {
      if (mounted) {
        setState(() => _enabled = config.pushPromocionesActivadas);
      }
    });
    _load();
  }

  void _load() {
    _enabled = widget.initialEnabled;
    _loading = false;
  }

  @override
  void didUpdateWidget(covariant PushPromotionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEnabled != widget.initialEnabled && !_busy) {
      _enabled = widget.initialEnabled;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _change(bool enable) async {
    if (_busy || _loading) return;
    if (enable && !await _askConsent()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (enable) {
        final result = await _service.enablePromotionalPush(
          explicitConsent: true,
        );
        if (result != FcmActivationResult.activated) {
          setState(() {
            _message = switch (result) {
              FcmActivationResult.consentRequired =>
                'Debes aceptar el aviso para activar las notificaciones push.',
              FcmActivationResult.signedOut =>
                'Inicia sesión para activar las notificaciones push.',
              FcmActivationResult.firebaseNotConfigured =>
                'Firebase todavía no está configurado para Cercly.',
              FcmActivationResult.permissionDenied =>
                'Permite las notificaciones de Cercly en Android.',
              FcmActivationResult.activated => null,
            };
          });
          return;
        }
      } else {
        await _service.disablePromotionalPush();
      }
      if (!mounted) return;
      setState(() {
        _enabled = enable;
        _message = enable
            ? 'Push activado. La ubicación solo se evalúa con Radar activo y Mapa visible.'
            : 'Push desactivado.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = enable
            ? 'No se pudo registrar esta instalación. Push permanece desactivado.'
            : 'Push se apagó en este dispositivo; falta confirmar la retirada en el servidor.';
        if (enable) _enabled = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _askConsent() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notificaciones push de promociones'),
          content: const Text(
            'Aceptas recibir promociones por notificación. Para decidir si hay una oferta cercana, Cercly enviará una ubicación reciente únicamente cuando el Radar esté activo y Mapa visible. La posición debe tener menos de 2 minutos y precisión de hasta 100 m; no se guarda como historial. No se usa ubicación en segundo plano.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aceptar y continuar'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          key: const Key('push-promociones-switch'),
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _loading || _busy ? null : _change,
          title: const Text('Push de promociones'),
          subtitle: Text(
            _enabled
                ? 'Se comparte el mismo límite de alertas entre tus dispositivos.'
                : 'La app comprobará la configuración de Firebase después de tu consentimiento.',
          ),
          secondary: Icon(Icons.cloud_outlined, color: sky.interactive),
        ),
        if (_busy || _loading) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_message!, style: TextStyle(color: sky.muted)),
          ),
      ],
    );
  }
}
