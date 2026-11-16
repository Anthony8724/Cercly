import 'package:flutter/material.dart';

import '../services/production_geofencing_service.dart';

class ProductionProximitySection extends StatefulWidget {
  const ProductionProximitySection({super.key});
  @override
  State<ProductionProximitySection> createState() =>
      _ProductionProximitySectionState();
}

class _ProductionProximitySectionState extends State<ProductionProximitySection>
    with WidgetsBindingObserver {
  final _service = ProductionGeofencingService();
  Map<Object?, Object?> _status = {};
  bool _busy = false;
  String _message = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await _service.status();
      if (mounted) setState(() => _status = s);
    } catch (_) {
      if (mounted) setState(() => _message = 'No se pudo consultar Android.');
    }
  }

  Future<void> _activate() async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alertas aunque Cercly esté cerrada'),
        content: const Text(
          'En Staging privado, si activas esta prueba, Android detectará entradas a zonas de promociones mientras Cercly está en segundo plano. Se consulta la promoción vigente y se valida la ubicación del evento; no se guarda un recorrido ni se mantiene GPS continuo. El permiso de ubicación en segundo plano es separado y revocable. Android puede retrasar o impedir alertas. Esta función experimental no está habilitada para publicación en Google Play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Acepto activar'),
          ),
        ],
      ),
    );
    if (accept != true || !mounted) return;
    await _run(() async {
      if (!await _service.setConsent(true)) {
        return 'No se pudo guardar el consentimiento.';
      }
      final s = await _service.status();
      if (s['precise'] != true || s['notifications'] != true) {
        await _service.requestForegroundPermissions();
        return 'Acepta los permisos de ubicación precisa y notificaciones. Al volver, continúa con el permiso de segundo plano.';
      }
      return s['background'] == true
          ? 'Consentimiento guardado. Pulsa Actualizar zonas cercanas.'
          : 'Consentimiento guardado. Ahora concede por separado el permiso de ubicación en segundo plano.';
    });
  }

  Future<void> _run(Future<String> Function() operation) async {
    setState(() => _busy = true);
    try {
      final message = await operation();
      if (mounted) setState(() => _message = message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'No se pudo completar la operación.');
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ProductionGeofencingService.enabledBuild) {
      return const SizedBox.shrink();
    }
    String state(String key) => _status[key] == true ? 'sí' : 'no';
    final checked = _status['checkedAt'] as int? ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alertas de promociones en segundo plano',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Opcionales · candidata privada. Registra hasta 20 zonas cercanas; actualiza al abrir Cercly o con el botón. Sin conexión se omiten los avisos. Si cambias de ciudad, vuelve a actualizar las zonas.',
            ),
            Text(
              'Ubicación precisa: ${state('precise')}. Todo el tiempo: ${state('background')}. Notificaciones: ${state('notifications')}. Servicios de ubicación: ${state('location')}. Google Play Services: ${state('gms')}.',
            ),
            Text(
              'Consentimiento: ${state('consent')}. Zonas guardadas vigentes: ${_status['zoneCount'] ?? 0}. Registro: ${_status['registration'] ?? 'sin consultar'}.',
            ),
            const Text(
              'Una aceptación de Google Play Services no prueba que la zona siga activa; Android no ofrece una lista para verificarlo.',
            ),
            if (checked > 0)
              Text(
                'Última comprobación: ${DateTime.fromMillisecondsSinceEpoch(checked)}. Resultado: ${_status['result']}.',
              ),
            if (_status['consent'] != true)
              FilledButton(
                onPressed: _busy ? null : _activate,
                child: const Text('Activar segundo plano'),
              )
            else ...[
              if (_status['background'] != true)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _service.requestBackgroundPermission();
                          return 'En Ajustes de Cercly, selecciona Ubicación → Permitir todo el tiempo. Vuelve a la app para comprobar el permiso.';
                        }),
                  child: const Text('Configurar ubicación en segundo plano'),
                ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final r = await _service.synchronize();
                        return switch (r) {
                          'accepted_by_gms' => 'Google Play Services aceptó las zonas. No garantiza una entrega inmediata.',
                          'no_eligible_zones' => 'No hay promociones elegibles cercanas. Se retiraron las zonas anteriores.',
                          'authorization_required' => 'Faltan permisos, alertas activas, ubicación o Google Play Services.',
                          'location_unavailable' => 'No hay ubicación suficientemente precisa. Inténtalo al recibir una posición mejor.',
                          _ => 'No se confirmó el registro ($r).',
                        };
                      }),
                child: const Text('Actualizar zonas cercanas'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        if (!await _service.setConsent(false)) {
                          return 'No se pudo guardar la desactivación.';
                        }
                        return 'Alertas de segundo plano desactivadas. Retirada de zonas solicitada a Android.';
                      }),
                child: const Text('Desactivar segundo plano'),
              ),
            ],
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () async => await _service.openSettings()
                          ? 'Revisa Ubicación y Notificaciones en Ajustes Android.'
                          : 'Abre Ajustes del teléfono → Aplicaciones → Cercly → Permisos.',
                    ),
              child: const Text('Abrir Ajustes Android'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message.isNotEmpty) Text(_message),
          ],
        ),
      ),
    );
  }
}
