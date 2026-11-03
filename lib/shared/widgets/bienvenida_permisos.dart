import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Explica el uso de permisos una vez, sin abrir diálogos del sistema.
class BienvenidaPermisos extends StatefulWidget {
  const BienvenidaPermisos({required this.child, super.key});

  final Widget child;

  @override
  State<BienvenidaPermisos> createState() => _BienvenidaPermisosState();
}

class _BienvenidaPermisosState extends State<BienvenidaPermisos> {
  static const _claveVista = 'cercly.bienvenida_permisos.v1';
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    unawaited(_mostrarSiCorresponde());
  }

  Future<void> _mostrarSiCorresponde() async {
    var vista = true;
    try {
      final preferencias = await SharedPreferences.getInstance();
      vista = preferencias.getBool(_claveVista) ?? false;
    } catch (_) {
      // La bienvenida no debe bloquear el acceso básico si falla el almacén.
    }
    if (vista || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bienvenido a Cercly'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubicación: encuentra establecimientos cercanos. Cercly la solicitará cuando uses por primera vez una función que la necesita.',
              ),
              SizedBox(height: 12),
              Text(
                'Notificaciones: recibe avisos de promociones relevantes. Android preguntará solo cuando actives voluntariamente las alertas.',
              ),
              SizedBox(height: 12),
              Text(
                'Segundo plano: las alertas actuales funcionan mientras Cercly está abierta. No hacemos seguimiento en segundo plano. Si se incorpora esa opción, será voluntaria y pedirá un consentimiento separado.',
              ),
              SizedBox(height: 12),
              Text(
                'Puedes rechazar permisos y seguir usando las funciones básicas. Cambia tus decisiones después desde Configuración o los ajustes de Android.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setBool(_claveVista, true);
    } catch (_) {
      // En esta sesión no se vuelve a mostrar aunque el guardado falle.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
