import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../services/notificacion_local_service.dart';
import '../services/geofencing_experimental_service.dart';
import '../services/preferencias_alertas_proximidad.dart';
import 'monitor_proximidad_app.dart';

/// Panel de soporte compilado solo para builds con CERCLY_STAGING=true.
/// La ubicación se obtiene tras una acción y consentimiento explícitos y se
/// conserva únicamente en memoria durante esta pantalla.
class StagingProximityDiagnostics extends StatefulWidget {
  const StagingProximityDiagnostics({super.key});

  static const establecimientoId = 'f14a1f14-14b0-4b14-8a14-140000000001';
  static const promocionId = 'f14a1f14-14b0-4b14-8a14-140000000002';
  static const bool _staging = bool.fromEnvironment('CERCLY_STAGING');

  @override
  State<StagingProximityDiagnostics> createState() =>
      _StagingProximityDiagnosticsState();
}

class _StagingProximityDiagnosticsState
    extends State<StagingProximityDiagnostics>
    with WidgetsBindingObserver {
  final _ubicacion = GeolocatorUbicacionService();
  final _geofencing = GeofencingExperimentalService();
  UbicacionUsuario? _posicion;
  GeofencingExperimentalStatus _geofenceStatus =
      const GeofencingExperimentalStatus();
  String? _resultado;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actualizarEstadoGeofence();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _actualizarEstadoGeofence();
  }

  Future<void> _actualizarEstadoGeofence() async {
    try {
      final status = await _geofencing.status();
      if (mounted) setState(() => _geofenceStatus = status);
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado = 'No se pudo consultar el estado QA nativo.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _obtenerUbicacionConConsentimiento() async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar ubicación para la prueba'),
        content: const Text(
          'Cercly consultará tu ubicación una vez para medir precisión y distancia. No guardará coordenadas ni historial. Puedes cancelar y seguir usando la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (continuar != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final resultado = await _ubicacion.obtenerUbicacion(
        solicitarPermiso: true,
      );
      if (!mounted) return;
      setState(() {
        _posicion = resultado.ubicacion;
        _resultado = resultado.estado == EstadoUbicacion.disponible
            ? 'Ubicación consultada. Las coordenadas solo permanecen en memoria.'
            : resultado.mensaje ?? 'Permiso o servicio de ubicación pendiente.';
      });
      if (resultado.ubicacion != null) await _consultarElegibilidad();
    } catch (_) {
      if (mounted) {
        setState(() => _resultado = 'No se pudo consultar ubicación.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _consultarElegibilidad() async {
    final posicion = _posicion;
    if (posicion == null) {
      setState(
        () => _resultado = 'Primero consulta la ubicación con consentimiento.',
      );
      return;
    }
    final precision = posicion.precisionMetros;
    final capturada = posicion.capturadaEn;
    if (precision == null ||
        !precision.isFinite ||
        precision <= 0 ||
        precision > 100 ||
        capturada == null ||
        DateTime.now().difference(capturada) > const Duration(minutes: 2)) {
      setState(
        () => _resultado = 'Ubicación imprecisa o desactualizada. Consulta una ubicación nueva con precisión de hasta 100 m.',
      );
      return;
    }
    setState(() => _ocupado = true);
    try {
      final fila = await Supabase.instance.client
          .from('promociones')
          .select(
            'id,titulo,fecha_inicio,fecha_fin,radio_alerta_metros,activa,establecimientos!inner(id,nombre,latitud,longitud,estado,publicable)',
          )
          .eq('id', StagingProximityDiagnostics.promocionId)
          .maybeSingle();
      if (!mounted) return;
      if (fila == null) {
        setState(
          () => _resultado = 'La promoción ficticia no existe o Staging no la muestra como pública.',
        );
        return;
      }

      final establecimiento = Map<String, dynamic>.from(
        fila['establecimientos'] as Map,
      );
      final latitud = (establecimiento['latitud'] as num).toDouble();
      final longitud = (establecimiento['longitud'] as num).toDouble();
      final distancia = _distanciaMetros(
        posicion.latitud,
        posicion.longitud,
        latitud,
        longitud,
      );
      final radioNegocio = (fila['radio_alerta_metros'] as num).toDouble();
      final now = DateTime.now().toUtc();
      final inicio = DateTime.parse(fila['fecha_inicio'] as String).toUtc();
      final fin = DateTime.parse(fila['fecha_fin'] as String).toUtc();
      final visible =
          establecimiento['estado'] == 'aprobado' &&
          establecimiento['publicable'] == true;
      final vigente =
          fila['activa'] == true && !now.isBefore(inicio) && !now.isAfter(fin);
      final configuracion = await PreferenciasAlertasProximidadLocal().cargar();
      final radioPreferido = configuracion.radioMetros;
      final elegible =
          visible &&
          vigente &&
          distancia <= math.min(radioNegocio, radioPreferido);
      setState(() {
        _resultado =
            'Negocio ${visible ? 'publicado' : 'no publicado'}; promoción ${vigente ? 'vigente' : 'fuera de vigencia'}; distancia ${distancia.round()} m; radio efectivo ${math.min(radioNegocio, radioPreferido).round()} m; ${elegible ? 'elegible' : 'no elegible'}.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado = 'No se pudo consultar la elegibilidad pública. Comprueba conexión y que el registro ficticio exista.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _evaluarAhora() async {
    final controller = MonitorProximidadScope.maybeOf(context);
    if (controller == null) {
      setState(
        () => _resultado = 'El monitor no está disponible en esta pantalla.',
      );
      return;
    }
    setState(() => _ocupado = true);
    try {
      await controller.verificarAhora();
      if (mounted) {
        setState(
          () => _resultado = _mensajeResultado(
            controller.ultimoResultadoDiagnostico,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _restablecerHistorial() async {
    final controller = MonitorProximidadScope.maybeOf(context);
    if (controller == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar cooldown de pruebas'),
        content: const Text(
          'Se borrará únicamente el historial local de notificaciones de proximidad de esta app Staging y los contadores QA nativos. No cambiará promociones, permisos Android ni datos de Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar cooldown'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _ocupado = true);
    try {
      await controller.reiniciarHistorialLocalDiagnostico();
      await _actualizarEstadoGeofence();
      if (mounted) {
        setState(
          () => _resultado = 'Cooldown individual, global y límite diario de Staging reiniciados. Permisos y datos remotos sin cambios.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado = 'No se completó el reinicio QA; revisa el estado local y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _simularEntrada() async {
    final controller = MonitorProximidadScope.maybeOf(context);
    if (controller == null) {
      setState(
        () =>
            _resultado = 'El motor foreground no está disponible para simular.',
      );
      return;
    }
    setState(() => _ocupado = true);
    try {
      final resultado = await controller.simularEntradaUpec();
      await _geofencing.recordSimulationResult(resultado);
      await _actualizarEstadoGeofence();
      if (mounted) {
        setState(
          () => _resultado =
              'SIMULACIÓN QA (no es evento geográfico Android): ${_mensajeResultadoSimulacion(resultado)}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado = 'SIMULACIÓN QA: falló la evaluación; no se afirma entrada geográfica.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _senalReceptorInterno() async {
    setState(() => _ocupado = true);
    try {
      final enviada = await _geofencing.sendQaReceiverSignal();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _actualizarEstadoGeofence();
      if (mounted) {
        setState(
          () => _resultado = enviada
              ? 'Señal QA enviada al receiver interno no exportado. No es una transición real de GeofencingClient.'
              : 'El receiver QA interno no está disponible en este build.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _resultado = 'Falló la señal al receiver interno QA.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _programarPantallaBloqueada() async {
    setState(() => _ocupado = true);
    try {
      final result = await _geofencing.scheduleScreenLockQa();
      await _actualizarEstadoGeofence();
      if (!mounted) return;
      setState(
        () => _resultado = switch (result) {
          'scheduled_inexact' => 'Prueba programada para aproximadamente 30 segundos. Android puede retrasarla por ahorro de batería; no es una entrada geográfica. Bloquea la pantalla y espera.',
          'already_scheduled' => 'Ya existe una prueba programada. Cancélala antes de programar otra para evitar duplicados.',
          'notification_permission_denied' => 'Android no permite notificaciones o el canal está bloqueado. Habilítalos en Ajustes y vuelve a comprobar; no se solicitó el permiso automáticamente.',
          'unavailable' =>
            'Esta herramienta solo está disponible en Cercly STAGING.',
          _ => 'No se pudo programar la prueba ($result).',
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado = 'Falló la programación nativa de la prueba.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelarPantallaBloqueada() async {
    setState(() => _ocupado = true);
    try {
      final canceled = await _geofencing.cancelScreenLockQa();
      await _actualizarEstadoGeofence();
      if (mounted) {
        setState(
          () => _resultado = canceled
              ? 'Prueba programada cancelada. No cambió permisos ni cooldown comercial.'
              : 'No se pudo confirmar la cancelación de la prueba.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _resultado = 'Falló la cancelación nativa de la prueba.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _mensajeResultadoSimulacion(String result) => switch (result) {
    'simulacion_notificacion_enviada' =>
      'promoción de Staging elegible; notificación marcada como simulada.',
    'simulacion_sin_consentimiento' =>
      'alertas de proximidad desactivadas o sin consentimiento.',
    'simulacion_permiso_ubicacion_denegado' =>
      'Android no concede ubicación foreground; no se solicitó permiso.',
    'simulacion_permiso_notificaciones_denegado' =>
      'Android no concede notificaciones.',
    'simulacion_canal_notificaciones_bloqueado' => 'canal Android bloqueado.',
    'simulacion_sin_promocion_vigente' =>
      'la promoción ficticia no está publicada y vigente.',
    'simulacion_bloqueada_cooldown_o_radio' =>
      'bloqueada por radio, cooldown, deduplicación o límite diario.',
    'simulacion_notificacion_bloqueada' => 'Android bloqueó la notificación.',
    _ => 'no se pudo completar ($result).',
  };

  String _duracion(int millis) {
    if (millis <= 0) return 'libre';
    final minutos = (millis / 60000).ceil();
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return horas > 0 ? '${horas}h ${resto}m' : '${minutos}m';
  }

  String _fechaQA(int millis) => millis <= 0
      ? 'ninguno'
      : DateTime.fromMillisecondsSinceEpoch(millis).toLocal().toString();

  Future<void> _consultarPermiso() async {
    setState(() => _ocupado = true);
    final estado = await MonitorProximidadScope.maybeOf(context)
        ?.consultarPermisoNotificaciones();
    if (mounted) {
      setState(() {
        _resultado = switch (estado) {
          null => 'El monitor no está disponible para consultar permisos.',
          EstadoPermisoNotificaciones.concedido =>
            'Permiso de notificaciones concedido.',
          EstadoPermisoNotificaciones.denegado =>
            'Permiso de notificaciones denegado.',
          EstadoPermisoNotificaciones.desactivadoEnAjustes =>
            'Notificaciones desactivadas en los ajustes de Android.',
          EstadoPermisoNotificaciones.noDisponible =>
            'El sistema no devolvió el estado del permiso.',
          EstadoPermisoNotificaciones.errorTecnico => 'Error técnico consultando el permiso; revisa el log seguro cercly.notifications.',
        };
      });
    }
    if (mounted) setState(() => _ocupado = false);
  }

  String _mensajeResultado(String resultado) => switch (resultado) {
    'notificacion_enviada' => 'Evaluación completada: notificación enviada.',
    'notificacion_bloqueada' =>
      'Evaluación completada: Android o el plugin bloqueó el envío.',
    'cooldown_limite_o_misma_zona' => 'Sin alerta: cooldown, límite de frecuencia o permaneces dentro de la zona.',
    'sin_promociones_elegibles' =>
      'Sin alerta: no hay promociones vigentes dentro del radio.',
    'alertas_desactivadas' =>
      'Activa voluntariamente las alertas antes de evaluar.',
    'permiso_ubicacion_pendiente' => 'Falta permiso o servicio de ubicación.',
    'permiso_ubicacion_revocado' => 'Permiso de ubicación revocado en Android.',
    'ubicacion_servicio_desactivado' =>
      'El GPS o servicio de ubicación está desactivado.',
    'error_ubicacion' => 'Error consultando u obteniendo la posición.',
    'permiso_notificaciones_pendiente' => 'Falta permiso de notificaciones.',
    'permiso_notificaciones_indeterminado' =>
      'Android no devolvió el estado de notificaciones.',
    'error_permiso_notificaciones' =>
      'Error técnico consultando permiso de notificaciones.',
    'canal_notificaciones_bloqueado' =>
      'Canal de promociones bloqueado en Android.',
    'ubicacion_imprecisa_o_desactualizada' =>
      'La ubicación es imprecisa o tiene más de dos minutos.',
    'sin_promociones_vigentes' => 'No hay promociones vigentes publicadas.',
    'sin_promociones_en_radio' =>
      'Hay promociones vigentes, pero ninguna está dentro del radio efectivo.',
    'evaluacion_en_curso' => 'Ya hay una evaluación en curso.',
    _ => 'Falló la evaluación. Comprueba conexión, permisos y logs técnicos seguros.',
  };

  double _distanciaMetros(double lat1, double lon1, double lat2, double lon2) {
    const tierra = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return tierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double value) => value * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    if (!StagingProximityDiagnostics._staging) return const SizedBox.shrink();
    return Card(
      key: const Key('diagnostico-proximidad-staging'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnóstico de proximidad · STAGING',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Solo Staging. No registra coordenadas ni envía ubicaciones a Supabase. La simulación usa distancia 0 al punto UPEC de prueba, consulta el registro público actual y comprueba permisos reales; nunca se etiqueta como entrada GPS.',
            ),
            const SizedBox(height: 12),
            Text(
              'Android: ubicación foreground ${_geofenceStatus.foregroundLocation ? 'permitida' : 'denegada'} (${_geofenceStatus.preciseLocation ? 'precisa' : 'aproximada/no disponible'}); background ${_geofenceStatus.backgroundLocation ? 'permitida' : 'denegada'}; notificaciones ${_geofenceStatus.notifications ? 'permitidas' : 'denegadas'}; canal ${_geofenceStatus.notificationChannel ? 'activo' : 'bloqueado/no creado'}; Play Services ${_geofenceStatus.googlePlayServices ? 'disponible' : 'no disponible'}.',
            ),
            const SizedBox(height: 4),
            Text(
              'Consentimiento alertas: ${_geofenceStatus.foregroundAlerts ? 'activo' : 'apagado'}; consentimiento independiente background: ${_geofenceStatus.consent ? 'activo' : 'apagado'}. Geofence: ${_geofenceStatus.registered && _geofenceStatus.registrationState == 'confirmed_by_play_services' ? 'Play Services confirmó el alta (no hay API para consultar inventario actual)' : _geofenceStatus.registrationState}.',
            ),
            Text(
              'Cooldown UPEC: ${_duracion(_geofenceStatus.promotionCooldownRemainingMs)} · global: ${_duracion(_geofenceStatus.globalCooldownRemainingMs)} · hoy: ${_geofenceStatus.dailyNotificationCount}/3 (restan ${_geofenceStatus.dailyRemaining}).',
            ),
            Text(
              'Último resultado motor: ${MonitorProximidadScope.maybeOf(context)?.ultimoResultadoDiagnostico ?? 'no disponible'}',
            ),
            Text(
              'Último evento Android recibido: ${_fechaQA(_geofenceStatus.lastAndroidEventAt)} (${_geofenceStatus.lastAndroidEventResult.isEmpty ? 'ninguno' : _geofenceStatus.lastAndroidEventResult}).',
            ),
            Text(
              'Geofencing real Android: entrada ${_fechaQA(_geofenceStatus.lastAndroidEnterAt)} · salida ${_fechaQA(_geofenceStatus.lastAndroidExitAt)} · último error ${_geofenceStatus.lastNativeError.isEmpty ? 'ninguno registrado' : _geofenceStatus.lastNativeError}.',
            ),
            Text(
              'Notificación tras entrada real: ${_fechaQA(_geofenceStatus.lastRealEntryNotificationAt)} (${_geofenceStatus.lastRealEntryNotificationResult.isEmpty ? 'ninguna' : _geofenceStatus.lastRealEntryNotificationResult}).',
            ),
            Text(
              'Prueba programada independiente: ${_geofenceStatus.screenLockQaResult.isEmpty ? 'ninguna' : _geofenceStatus.screenLockQaResult}; programada ${_fechaQA(_geofenceStatus.screenLockQaScheduledAt)}; entrega ${_fechaQA(_geofenceStatus.screenLockQaDeliveredAt)}; vence ${_fechaQA(_geofenceStatus.screenLockQaDueAt)}. Esta prueba no acredita una entrada geográfica.',
            ),
            Text(
              'Última simulación QA: ${_fechaQA(_geofenceStatus.lastSimulationAt)} (${_geofenceStatus.lastSimulationResult.isEmpty ? 'ninguna' : _geofenceStatus.lastSimulationResult}). Señal receiver QA: ${_fechaQA(_geofenceStatus.lastQaReceiverSignalAt)}.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _ocupado
                      ? null
                      : _obtenerUbicacionConConsentimiento,
                  child: const Text('Consultar ubicación'),
                ),
                OutlinedButton(
                  onPressed: _ocupado ? null : _consultarPermiso,
                  child: const Text('Revisar notificaciones'),
                ),
                OutlinedButton(
                  onPressed: _ocupado ? null : _consultarElegibilidad,
                  child: const Text('Comprobar negocio y promoción'),
                ),
                FilledButton(
                  onPressed: _ocupado ? null : _evaluarAhora,
                  child: const Text('Evaluar ahora'),
                ),
                FilledButton.tonal(
                  onPressed: _ocupado ? null : _simularEntrada,
                  child: const Text('Simular entrada en zona'),
                ),
                OutlinedButton(
                  onPressed: _ocupado ? null : _senalReceptorInterno,
                  child: const Text('Probar receiver QA interno'),
                ),
                FilledButton.tonal(
                  onPressed: _ocupado ? null : _programarPantallaBloqueada,
                  child: const Text('Programar prueba con pantalla bloqueada'),
                ),
                OutlinedButton(
                  onPressed: _ocupado ? null : _cancelarPantallaBloqueada,
                  child: const Text('Cancelar prueba programada'),
                ),
                TextButton(
                  onPressed: _ocupado ? null : _restablecerHistorial,
                  child: const Text('Reiniciar cooldown de pruebas'),
                ),
              ],
            ),
            if (_ocupado) const LinearProgressIndicator(),
            if (_posicion != null)
              Text(
                'Precisión GPS: ${_posicion!.precisionMetros?.round() ?? 'sin dato'} m · datos solo en memoria.',
              ),
            if (_resultado != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_resultado!)),
            ],
          ],
        ),
      ),
    );
  }
}
