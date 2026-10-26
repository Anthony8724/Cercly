import 'package:flutter/material.dart';

import '../../../sky/apariencia_screen.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../../../sky/sky_controller.dart';
import '../services/account_deletion_service.dart';

class ConfiguracionCuentaScreen extends StatelessWidget {
  const ConfiguracionCuentaScreen({super.key, this.deletionService});
  final AccountDeletionService? deletionService;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configuración')),
    body: SkySurface(
      intensity: .48,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Cuenta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CuentaScreen(deletionService: deletionService),
                ),
              ),
            ),
            ListTile(
              key: const Key('abrir-apariencia'),
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Apariencia'),
              subtitle: const Text('Cercly Sky: automático o ambiente manual'),
              trailing: const Icon(Icons.chevron_right),
              onTap: SkyScope.maybeOf(context) == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AparienciaScreen(
                          controller: SkyScope.maybeOf(context)!,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key, this.deletionService});
  final AccountDeletionService? deletionService;

  @override
  Widget build(BuildContext context) {
    const deletionEnabled = bool.fromEnvironment(
      'ACCOUNT_DELETION_ENABLED',
      defaultValue: true,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: SkySurface(
        intensity: .48,
        child: SafeArea(
          child: ListTile(
            key: const Key('abrir-eliminar-cuenta'),
            leading: const Icon(
              Icons.person_remove_outlined,
              color: Color(0xFFB91C1C),
            ),
            title: const Text('Eliminar mi cuenta'),
            subtitle: Text(
              deletionEnabled
                  ? 'Solicita la eliminación de tu identidad y datos.'
                  : 'Disponible cuando termine la validación del servicio.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: !deletionEnabled
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EliminarCuentaScreen(
                        deletionService: deletionService,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class EliminarCuentaScreen extends StatefulWidget {
  const EliminarCuentaScreen({super.key, this.deletionService});
  final AccountDeletionService? deletionService;

  @override
  State<EliminarCuentaScreen> createState() => _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends State<EliminarCuentaScreen> {
  late final AccountDeletionService _service =
      widget.deletionService ?? AccountDeletionService();
  bool _loading = false;
  AccountDeletionOutcome? _outcome;
  AccountDeletionFailure? _failure;

  Future<void> _confirmar() async {
    if (_loading) return;
    if (!_service.hasSession) {
      setState(() => _failure = AccountDeletionFailure.session);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar solicitud'),
        content: const Text(
          'Se eliminarán tu identidad de acceso y tus datos personales cuando '
          'el proceso se complete. Si hay negocios, solicitudes o archivos '
          'compartidos, un responsable deberá revisar su destino. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-eliminacion'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-eliminacion'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sí, solicitar eliminación'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final result = await _service.requestDeletion();
      if (mounted) setState(() => _outcome = result);
    } on AccountDeletionException catch (error) {
      if (mounted) setState(() => _failure = error.failure);
    } catch (_) {
      if (mounted) setState(() => _failure = AccountDeletionFailure.unknown);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _message {
    if (_outcome == AccountDeletionOutcome.deleted) {
      return 'Tu cuenta se eliminó y cerramos la sesión en este dispositivo.';
    }
    if (_outcome == AccountDeletionOutcome.review) {
      return 'Recibimos tu solicitud. Un responsable debe revisar los negocios '
          'o datos compartidos antes de eliminar tu identidad. Tu cuenta aún '
          'no está eliminada.';
    }
    return switch (_failure) {
      AccountDeletionFailure.session => 'No hay una sesión válida. Inicia sesión para solicitar la eliminación.',
      AccountDeletionFailure.recentAuth => 'Por seguridad, cierra sesión y vuelve a iniciar sesión antes de intentarlo.',
      AccountDeletionFailure.network => 'Se perdió la conexión. No podemos confirmar el estado; vuelve a intentarlo.',
      AccountDeletionFailure.pending => 'La solicitud quedó pendiente. No se confirmó el borrado; vuelve a intentarlo.',
      AccountDeletionFailure.unknown => 'No podemos confirmar el estado de la solicitud. Reintenta o contacta con soporte.',
      null => '',
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Eliminar mi cuenta')),
    body: SkySurface(
      intensity: .4,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: SkyPalette.of(context).error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Antes de continuar',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Al completar la eliminación perderás el acceso a Cercly. '
              'Se quitarán tu identidad de Supabase Auth y tu perfil. '
              'Los negocios compartidos no se borran automáticamente. '
              'Si tienes negocios, solicitudes o archivos, la solicitud quedará '
              'en revisión y te informaremos de los pasos pendientes.',
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  key: Key('eliminacion-cargando'),
                ),
              ),
            if (_message.isNotEmpty) ...[
              Text(_message, key: const Key('estado-eliminacion')),
              const SizedBox(height: 14),
            ],
            if (_failure == AccountDeletionFailure.recentAuth)
              TextButton(
                onPressed: _service.signOutForReauthentication,
                child: const Text('Cerrar sesión para volver a entrar'),
              ),
            if (_outcome == null)
              FilledButton(
                key: const Key('solicitar-eliminacion'),
                onPressed: _loading ? null : _confirmar,
                child: const Text('Continuar con la eliminación'),
              ),
          ],
        ),
      ),
    ),
  );
}
