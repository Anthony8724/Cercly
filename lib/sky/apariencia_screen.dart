import 'package:flutter/material.dart';

import 'sky_controller.dart';
import 'sky_backdrop.dart';
import 'sky_theme.dart';

class AparienciaScreen extends StatelessWidget {
  const AparienciaScreen({required this.controller, super.key});

  final SkyController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: SkySurface(
        intensity: .5,
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Elige el ambiente de Cercly Sky. Automático usa la hora local del teléfono.',
                ),
              ),
              for (final mode in SkyMode.values)
                Card(
                  child: ListTile(
                    key: Key('ambiente-${mode.name}'),
                    title: Text(mode.label),
                    subtitle: mode == SkyMode.automatico
                        ? const Text(
                            'Cambia con la hora y zona horaria del dispositivo',
                          )
                        : null,
                    selected: controller.mode == mode,
                    leading: Icon(
                      mode == SkyMode.automatico
                          ? Icons.schedule_rounded
                          : switch (mode.environment!) {
                              SkyEnvironment.amanecer =>
                                Icons.wb_twilight_rounded,
                              SkyEnvironment.dia => Icons.wb_sunny_outlined,
                              SkyEnvironment.atardecer =>
                                Icons.wb_twilight_rounded,
                              SkyEnvironment.noche => Icons.nightlight_round,
                            },
                    ),
                    trailing: controller.mode == mode
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: () async {
                      try {
                        await controller.selectMode(mode);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo guardar la selección.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              const Divider(),
              Card(
                child: SwitchListTile(
                  key: const Key('efectos-decorativos'),
                  title: const Text('Efectos ambientales'),
                  subtitle: const Text(
                    'Sol, nubes y estrellas. Se animan suavemente salvo si el sistema pide menos movimiento.',
                  ),
                  value: controller.decorationsEnabled,
                  onChanged: (value) async {
                    try {
                      await controller.setDecorationsEnabled(value);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo guardar la selección.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
