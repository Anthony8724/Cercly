import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../sky/apariencia_screen.dart';
import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../../../sky/sky_controller.dart';
import '../../../shared/ui/cercly_ui.dart';
import '../../notificaciones/widgets/alertas_proximidad_section.dart';
import '../../notificaciones/widgets/production_proximity_section.dart';
import '../../notificaciones/widgets/staging_proximity_diagnostics.dart';
import '../../notificaciones/services/geofencing_experimental_service.dart';
import '../../notificaciones/services/notificacion_local_service.dart';
import '../../notificaciones/services/preferencias_alertas_proximidad.dart';
import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/consentimiento_ubicacion.dart';
import '../../explorar/services/ubicacion_service.dart';
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
              const UbicacionExploracionSection(),
              const SizedBox(height: 12),
              const AlertasProximidadSection(),
              const SizedBox(height: 12),
              if (const bool.fromEnvironment('CERCLY_PRIVATE_PROXIMITY'))
                const ProductionProximitySection(),
              if (const bool.fromEnvironment('CERCLY_STAGING'))
                const AlertasSegundoPlanoSection(),
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

class UbicacionExploracionSection extends StatefulWidget {
  const UbicacionExploracionSection({super.key, this.ubicacionService});

  final UbicacionService? ubicacionService;

  @override
  State<UbicacionExploracionSection> createState() =>
      _UbicacionExploracionSectionState();
}

class _UbicacionExploracionSectionState
    extends State<UbicacionExploracionSection>
    with WidgetsBindingObserver {
  late final UbicacionService _service =
      widget.ubicacionService ?? GeolocatorUbicacionService();
  EstadoUbicacion? _estado;
  bool _consentimiento = false;
  bool? _precisa;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actualizar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _actualizar();
  }

  Future<void> _actualizar() async {
    final estado = await _service.consultarEstadoPermiso();
    final consentimiento = await ConsentimientoUbicacion.estaAceptado();
    final precision = _service is PrecisionUbicacionService
        ? await (_service as PrecisionUbicacionService).ubicacionPrecisa()
        : null;
    if (!mounted) return;
    setState(() {
      _estado = estado;
      _consentimiento = consentimiento;
      _precisa = precision;
      _cargando = false;
    });
  }

  Future<void> _abrirAjustes() async {
    var abierto = false;
    try {
      abierto = await _service.abrirAjustesAplicacion();
    } catch (_) {
      abierto = false;
    }
    if (!mounted || abierto) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abre Ajustes de Android → Aplicaciones → Cercly → Permisos → Ubicación.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = _cargando
        ? 'Comprobando permiso…'
        : switch (_estado) {
            EstadoUbicacion.disponible =>
              _precisa == false
                  ? 'Ubicación aproximada concedida · sirve para explorar; las alertas requieren precisión.'
                  : _consentimiento
                  ? 'Permiso concedido · Cercly puede actualizar tu ubicación al explorar.'
                  : 'Permiso Android concedido · aún no has activado ubicación en Cercly.',
            EstadoUbicacion.servicioDesactivado =>
              'La ubicación del dispositivo está apagada.',
            EstadoUbicacion.permisoDenegado ||
            EstadoUbicacion.permisoDenegadoPermanentemente =>
              'Permiso de ubicación no concedido.',
            _ => 'No se pudo comprobar el permiso.',
          };
    return CerclySectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ubicación para explorar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(estado),
          const SizedBox(height: 5),
          const Text(
            'Se solicita al usar una función cercana. Rechazarla no impide explorar el catálogo.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _abrirAjustes,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Ajustes de ubicación'),
            ),
          ),
        ],
      ),
    );
  }
}

class AlertasSegundoPlanoSection extends StatefulWidget {
  const AlertasSegundoPlanoSection({super.key});

  @override
  State<AlertasSegundoPlanoSection> createState() =>
      _AlertasSegundoPlanoSectionState();
}

class _AlertasSegundoPlanoSectionState extends State<AlertasSegundoPlanoSection>
    with WidgetsBindingObserver {
  final _service = GeofencingExperimentalService();
  final _location = GeolocatorUbicacionService();
  final _notifications = NotificacionLocalService();
  GeofencingExperimentalStatus _status = const GeofencingExperimentalStatus();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final value = await _service.status();
      if (mounted) setState(() => _status = value);
      if (value.consent &&
          (!value.backgroundLocation || !value.foregroundLocation)) {
        await _service.remove();
        if (mounted) {
          setState(
            () => _message =
                'Se retiró la zona porque Android revocó un permiso.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'No se pudo consultar el estado nativo.');
      }
    }
  }

  Future<void> _enable() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prueba de alertas en segundo plano'),
        content: const Text(
          'Solo Staging: Cercly registrará una zona alrededor del establecimiento ficticio de prueba de la UPEC y recibirá el evento de entrada para validar la promoción pública. Android puede retrasar o bloquear estos eventos. No se guarda tu ubicación ni un historial de recorridos. Para continuar, concede primero ubicación mientras usas la app y notificaciones; después Android abrirá Ajustes para que, si lo deseas, permitas ubicación todo el tiempo. Puedes desactivar la prueba aquí en cualquier momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final location = await _location.consultarEstadoPermiso(
        solicitarPermiso: true,
      );
      if (location != EstadoUbicacion.disponible) {
        setState(
          () => _message = 'Se necesita primero el permiso de ubicación mientras Cercly está en uso.',
        );
        return;
      }
      final notifications = await _notifications
          .solicitarPermisoNotificaciones();
      if (!notifications) {
        setState(
          () => _message = 'Concede notificaciones desde Ajustes antes de activar la prueba.',
        );
        return;
      }
      await _service.setConsent(true);
      await _refresh();
      if (!_status.backgroundLocation) {
        setState(
          () => _message = 'Activa “Permitir siempre” en la pantalla de Ajustes que abrirá Android.',
        );
        await _service.openAppSettings();
      } else {
        setState(
          () => _message = 'Permisos concedidos. Pulsa “Registrar zona UPEC” para sincronizar la promoción vigente.',
        );
      }
    } catch (_) {
      setState(
        () => _message = 'No se pudo completar la activación. Revisa permisos y vuelve a consultar.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final status = await _service.status();
      if (!status.consent ||
          !status.foregroundAlerts ||
          !status.foregroundLocation ||
          !status.preciseLocation ||
          !status.backgroundLocation ||
          !status.notifications ||
          !status.googlePlayServices) {
        setState(
          () => _message = 'Falta consentimiento, alertas activadas, ubicación precisa todo el tiempo, notificaciones o Google Play Services.',
        );
        await _refresh();
        return;
      }
      final row = await Supabase.instance.client
          .from('promociones')
          .select(
            'id,titulo,fecha_fin,radio_alerta_metros,activa,establecimientos!inner(id,nombre,latitud,longitud,estado,publicable)',
          )
          .eq('id', GeofencingExperimentalService.promotionId)
          .maybeSingle();
      if (row == null || row['activa'] != true) {
        setState(
          () => _message = 'La promoción de prueba no está activa en Staging; no se registró zona.',
        );
        return;
      }
      final establishment = Map<String, dynamic>.from(
        row['establecimientos'] as Map,
      );
      if (establishment['id'] !=
              GeofencingExperimentalService.establishmentId ||
          establishment['estado'] != 'aprobado' ||
          establishment['publicable'] != true) {
        setState(
          () => _message = 'El establecimiento de prueba no es elegible; no se registró zona.',
        );
        return;
      }
      final expiresAt = DateTime.parse(row['fecha_fin'] as String).toUtc();
      if (!expiresAt.isAfter(DateTime.now().toUtc())) {
        setState(
          () => _message = 'La promoción ya venció; no se registró zona.',
        );
        return;
      }
      final settings = await PreferenciasAlertasProximidadLocal().cargar();
      final result = await _service.register(
        latitude: (establishment['latitud'] as num).toDouble(),
        longitude: (establishment['longitud'] as num).toDouble(),
        radiusMeters: math.min(
          (row['radio_alerta_metros'] as num).toInt(),
          settings.radioMetros,
        ),
        expiresAt: expiresAt,
        establishmentName:
            establishment['nombre'] as String? ?? 'Cercly Test UPEC',
        promotionTitle:
            row['titulo'] as String? ?? 'Promoción de prueba Cercly',
      );
      setState(
        () => _message = switch (result) {
          'registration_submitted' => 'Solicitud de registro enviada. Android puede tardar en confirmar el geofence.',
          'background_permission_required' =>
            'Android aún no concedió ubicación todo el tiempo.',
          'precise_location_required' => 'Para este geofence de prueba, permite ubicación precisa en los ajustes de Android.',
          'google_play_services_unavailable' =>
            'Google Play Services no está disponible en este dispositivo.',
          'promotion_expired' => 'La promoción de prueba venció.',
          _ => 'No se registró la zona ($result).',
        },
      );
      await _refresh();
    } catch (_) {
      setState(
        () => _message =
            'No se pudo verificar Staging; por seguridad no se registró zona.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    await _service.setConsent(false);
    await _service.remove();
    await _refresh();
    if (mounted) {
      setState(() => _message = 'Prueba desactivada y geofence retirado.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CerclySectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alertas en segundo plano · experimento Staging',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Text(
          'Ubicación: ${_status.foregroundLocation ? 'permitida en uso' : 'no permitida'}, precisión ${_status.preciseLocation ? 'precisa' : 'aproximada/no disponible'}, segundo plano ${_status.backgroundLocation ? 'permitido' : 'no permitido'}. Notificaciones ${_status.notifications ? 'permitidas' : 'no permitidas'}, canal ${_status.notificationChannel ? 'disponible' : 'bloqueado/no creado'}. Play Services: ${_status.googlePlayServices ? 'disponible' : 'no disponible'}. ${_status.registered ? 'Zona registrada.' : 'Sin zona registrada.'}',
        ),
        const SizedBox(height: 8),
        if (!_status.consent)
          FilledButton(
            onPressed: _busy ? null : _enable,
            child: const Text('Activar prueba experimental'),
          )
        else ...[
          FilledButton.tonal(
            onPressed: _busy ? null : _register,
            child: const Text('Registrar zona UPEC'),
          ),
          TextButton(
            onPressed: _busy ? null : _disable,
            child: const Text('Desactivar y retirar zona'),
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) ...[const SizedBox(height: 6), Text(_message!)],
        const SizedBox(height: 6),
        const Text(
          'Solo monitorea la promoción ficticia autorizada de UPEC. Sin GPS continuo ni historial de recorridos. Android puede retrasar eventos y la detención forzada impide la reactivación hasta abrir Cercly.',
        ),
      ],
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
