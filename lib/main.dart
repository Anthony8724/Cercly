import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_options.dart';
import 'evaluation/cercly_ui_evaluation_app.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/auth/screens/auth_recovery_host.dart';
import 'features/notificaciones/widgets/monitor_proximidad_app.dart';
import 'shared/ui/environment_banner.dart';
import 'sky/sky_controller.dart';
import 'sky/sky_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const uiEvaluation = bool.fromEnvironment('CERCLY_UI_EVALUATION');
  const demoRelease = bool.fromEnvironment('CERCLY_DEMO_RELEASE');
  if (demoRelease && !uiEvaluation) {
    runApp(const EvaluationConfigurationRejectedApp());
    return;
  }
  if (uiEvaluation) {
    if (SupabaseOptions.url.isNotEmpty ||
        SupabaseOptions.publishableKey.isNotEmpty) {
      runApp(const EvaluationConfigurationRejectedApp());
      return;
    }
    runApp(const CerclyUiEvaluationApp());
    return;
  }

  if (!SupabaseOptions.isConfigured) {
    runApp(const ConfiguracionFaltanteApp());
    return;
  }

  const isStagingBuild = bool.fromEnvironment('CERCLY_STAGING');
  if (isStagingBuild &&
      Uri.tryParse(SupabaseOptions.url)?.host !=
          'dlajxviqhkdcqnmczhvr.supabase.co') {
    runApp(const ConfiguracionEntornoInvalidaApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseOptions.url,
    publishableKey: SupabaseOptions.publishableKey,
  );

  runApp(const CerclyApp());
}

class EvaluationConfigurationRejectedApp extends StatelessWidget {
  const EvaluationConfigurationRejectedApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Evaluación bloqueada: esta compilación contiene configuración de Supabase. Compila sin SUPABASE_URL ni SUPABASE_PUBLISHABLE_KEY.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}

class CerclyApp extends StatefulWidget {
  const CerclyApp({super.key, this.skyController});
  final SkyController? skyController;

  @override
  State<CerclyApp> createState() => _CerclyAppState();
}

class _CerclyAppState extends State<CerclyApp> {
  late final SkyController _sky = widget.skyController ?? SkyController();

  @override
  void initState() {
    super.initState();
    unawaited(_sky.start());
  }

  @override
  void dispose() {
    if (widget.skyController == null) _sky.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sky,
      builder: (context, _) => SkyScope(
        controller: _sky,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cercly',
          builder: (context, child) =>
              EnvironmentBanner(child: child ?? const SizedBox.shrink()),
          theme: skyTheme(_sky.palette),
          themeAnimationDuration: Duration.zero,
          home: const AuthRecoveryHost(
            child: MonitorProximidadApp(child: AuthGate()),
          ),
        ),
      ),
    );
  }
}

class ConfiguracionEntornoInvalidaApp extends StatelessWidget {
  const ConfiguracionEntornoInvalidaApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Esta compilación STAGING requiere la configuración de Supabase Staging.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}

class ConfiguracionFaltanteApp extends StatelessWidget {
  const ConfiguracionFaltanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Falta configurar Supabase',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ejecuta Cercly utilizando el archivo '
                    'config/supabase.local.json.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
