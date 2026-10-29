import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../services/notificacion_local_service.dart';
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
    extends State<StagingProximityDiagnostics> {
  final _ubicacion = GeolocatorUbicacionService();
  UbicacionUsuario? _posicion;
  String? _resultado;
  bool _ocupado = false;

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
        title: const Text('Restablecer historial local de prueba'),
        content: const Text(
          'Se borrará solo el cooldown y el historial local de alertas de este dispositivo. No se cambiarán datos de Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await controller.reiniciarHistorialLocalDiagnostico();
    if (mounted) {
      setState(() => _resultado = 'Historial local de alertas restablecido.');
    }
  }

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
    'permiso_notificaciones_pendiente' => 'Falta permiso de notificaciones.',
    'ubicacion_imprecisa_o_desactualizada' =>
      'La ubicación es imprecisa o tiene más de dos minutos.',
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
              'Solo consulta ubicación tras consentimiento. No registra coordenadas ni envía ubicaciones a Supabase.',
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
                TextButton(
                  onPressed: _ocupado ? null : _restablecerHistorial,
                  child: const Text('Restablecer historial local'),
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
