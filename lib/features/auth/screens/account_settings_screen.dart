import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../sky/apariencia_screen.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../../../sky/sky_controller.dart';
import '../../../shared/ui/cercly_ui.dart';
import '../../notificaciones/widgets/alertas_proximidad_section.dart';
import '../../notificaciones/widgets/staging_proximity_diagnostics.dart';
import '../../establecimientos/screens/registro_establecimiento_screen.dart';
import '../services/account_deletion_service.dart';

const _privacyPolicyUri = 'https://cercly-web.vercel.app/privacidad';
const _privacyContactUri =
    'https://cercly-web.vercel.app/privacidad#responsable';
const _accountDeletionWebUri = 'https://cercly-web.vercel.app/eliminar-cuenta';

class ConfiguracionCuentaScreen extends StatelessWidget {
  const ConfiguracionCuentaScreen({
    super.key,
    this.deletionService,
    this.abrirEnlace,
    this.registroScreenBuilder,
  });
  final AccountDeletionService? deletionService;
  final Future<bool> Function(Uri uri)? abrirEnlace;
  final WidgetBuilder? registroScreenBuilder;

  Future<void> _abrirExterno(String valor) async {
    final uri = Uri.parse(valor);
    final abrir = abrirEnlace;
    if (abrir != null) {
      await abrir(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        title: const Text('Configuración'),
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: sky.headerGradient),
        ),
      ),
      body: SkySurface(
        intensity: .48,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  gradient: sky.headerGradient,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: sky.primary.withValues(alpha: .13),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.settings_rounded, color: Colors.white, size: 29),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configura tu experiencia',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ajustes de tu cuenta, privacidad y apariencia.',
                            style: TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CerclySectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CerclySectionTitle(
                      title: '¿Tienes un negocio?',
                      subtitle: 'Regístralo en Cercly para que las personas puedan encontrarlo. Nuestro equipo revisará la solicitud antes de publicarlo.',
                      icon: Icons.storefront_outlined,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('registrar-mi-negocio-configuracion'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                registroScreenBuilder ??
                                (_) => const RegistroEstablecimientoScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('Registrar mi negocio'),
                      ),
                    ),
                  ],
                ),
              ),
              CerclySectionCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: sky.surface,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.manage_accounts_outlined,
                          color: sky.interactive,
                        ),
                        title: const Text('Cuenta'),
                        subtitle: const Text(
                          'Opciones y eliminación de cuenta',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CuentaScreen(deletionService: deletionService),
                          ),
                        ),
                      ),
                      Divider(height: 1, indent: 60, color: sky.border),
                      ListTile(
                        key: const Key('abrir-politica-privacidad'),
                        leading: Icon(
                          Icons.privacy_tip_outlined,
                          color: sky.interactive,
                        ),
                        title: const Text('Política de privacidad'),
                        subtitle: const Text(
                          'Cómo se usan y eliminan tus datos',
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _abrirExterno(_privacyPolicyUri),
                      ),
                      Divider(height: 1, indent: 60, color: sky.border),
                      ListTile(
                        key: const Key('abrir-contacto-cercly'),
                        leading: Icon(
                          Icons.mail_outline_rounded,
                          color: sky.interactive,
                        ),
                        title: const Text('Contacto de privacidad y soporte'),
                        subtitle: const Text(
                          'Correo disponible en el sitio de Cercly',
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _abrirExterno(_privacyContactUri),
                      ),
                      Divider(height: 1, indent: 60, color: sky.border),
                      ListTile(
                        key: const Key('abrir-eliminacion-web'),
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: sky.error,
                        ),
                        title: const Text('Eliminar cuenta desde la web'),
                        subtitle: const Text(
                          'También puedes iniciar la solicitud sin la app',
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _abrirExterno(_accountDeletionWebUri),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CerclySectionCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: sky.surface,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    key: const Key('abrir-apariencia'),
                    leading: Icon(
                      Icons.palette_outlined,
                      color: sky.interactive,
                    ),
                    title: const Text('Apariencia'),
                    subtitle: const Text(
                      'Cercly Sky: automático o ambiente manual',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
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
                ),
              ),
              const SizedBox(height: 12),
              const AlertasProximidadSection(),
              if (const bool.fromEnvironment('CERCLY_STAGING')) ...[
                const SizedBox(height: 12),
                const StagingProximityDiagnostics(),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
