import 'package:flutter/material.dart';

import '../../explorar/models/ubicacion_usuario.dart';
import '../../explorar/services/ubicacion_service.dart';
import '../../../shared/ui/cercly_ui.dart';
import '../../../sky/sky_theme.dart';
import '../models/configuracion_alertas_proximidad.dart';
import 'monitor_proximidad_app.dart';
import '../services/notificacion_local_service.dart';
import '../services/preferencias_alertas_proximidad.dart';

class AlertasProximidadSection extends StatefulWidget {
  const AlertasProximidadSection({
    super.key,
    this.preferencias,
    this.ubicacionService,
    this.notificaciones,
  });

  final PreferenciasAlertasProximidadRepository? preferencias;
  final UbicacionService? ubicacionService;
  final PermisosNotificacionesProximidad? notificaciones;

  @override
  State<AlertasProximidadSection> createState() =>
      _AlertasProximidadSectionState();
}

class _AlertasProximidadSectionState extends State<AlertasProximidadSection>
    with WidgetsBindingObserver {
  late final PreferenciasAlertasProximidadRepository _preferencias =
      widget.preferencias ?? PreferenciasAlertasProximidadLocal();
  late final UbicacionService _ubicacion =
      widget.ubicacionService ?? GeolocatorUbicacionService();
  late final PermisosNotificacionesProximidad _notificaciones =
      widget.notificaciones ?? NotificacionLocalService();

  ConfiguracionAlertasProximidad _configuracion =
      const ConfiguracionAlertasProximidad();
  bool _cargando = true;
  bool _guardando = false;
  bool _permisoNotificaciones = false;
  EstadoUbicacion? _estadoUbicacion;
  bool? _ubicacionPrecisa;
  DateTime? _ultimaComprobacion;
  String? _mensaje;
  String? _diagnostico;
  bool _mensajeError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _actualizarPermisos();
    }
  }

  Future<void> _cargar() async {
    try {
      final configuracion = await _preferencias.cargar();
      if (!mounted) return;
      setState(() {
        _configuracion = configuracion;
        _cargando = false;
      });
      await _actualizarPermisos();
      if (!mounted) return;
      final monitor = MonitorProximidadScope.maybeOf(context);
      final ultima = await monitor?.cargarUltimaComprobacion();
      if (mounted && ultima != null) {
        setState(() => _ultimaComprobacion = ultima.toLocal());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _mensaje = 'No pudimos leer la configuración de alertas.';
        _mensajeError = true;
      });
    }
  }

  Future<void> _actualizarPermisos() async {
    try {
      final permisoNotificaciones = await _consultarPermisoNotificaciones();
      final estadoUbicacion = await _ubicacion.consultarEstadoPermiso();
      final precision = _ubicacion is PrecisionUbicacionService
          ? await (_ubicacion as PrecisionUbicacionService).ubicacionPrecisa()
          : null;
      if (!mounted) return;
      setState(() {
        _permisoNotificaciones = permisoNotificaciones;
        _estadoUbicacion = estadoUbicacion;
        _ubicacionPrecisa = precision;
        if (_configuracion.activadas &&
            (!permisoNotificaciones ||
                estadoUbicacion != EstadoUbicacion.disponible)) {
          _mensaje = _textoPermisosPendientes(estadoUbicacion);
          _mensajeError = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensaje = 'No pudimos comprobar los permisos del dispositivo.';
          _mensajeError = true;
        });
      }
    }
  }

  Future<void> _cambiarAlertas(bool activar) async {
    if (_guardando || _cargando) return;
    setState(() {
      _guardando = true;
      _mensaje = null;
      _mensajeError = false;
    });

    try {
      if (!activar) {
        final nueva = _configuracion.copiarCon(activadas: false);
        try {
          await _preferencias.guardar(nueva);
        } catch (_) {
          _mostrarError(
            'No se pudo guardar el cambio en el dispositivo. El interruptor conserva su estado anterior; inténtalo de nuevo.',
            _estadoUbicacion ?? EstadoUbicacion.error,
          );
          return;
        }
        if (!mounted) return;
        setState(() {
          _configuracion = nueva;
          _mensaje = 'Alertas desactivadas. No consultaremos tu ubicación.';
        });
        return;
      }

      // Solo tras activar voluntariamente se solicitan los permisos del SO.
      ResultadoUbicacion resultado;
      try {
        resultado = await _ubicacion.obtenerUbicacion(solicitarPermiso: true);
      } catch (_) {
        _mostrarError(
          'No pudimos comprobar el permiso de ubicación. Revisa los ajustes de Cercly e inténtalo de nuevo.',
          EstadoUbicacion.error,
        );
        return;
      }
      if (resultado.estado != EstadoUbicacion.disponible ||
          resultado.ubicacion == null) {
        _mostrarError(
          resultado.mensaje ?? _textoPermisosPendientes(resultado.estado),
          resultado.estado,
        );
        return;
      }
      if (!_ubicacionTienePrecisionSuficiente(resultado.ubicacion!)) {
        _mostrarError(
          'La ubicación es demasiado aproximada para avisar con fiabilidad. Activa la ubicación precisa en Android.',
          EstadoUbicacion.disponible,
        );
        return;
      }

      bool permisoNotificaciones;
      if (_notificaciones is DiagnosticoPermisoNotificaciones) {
        final estado =
            await (_notificaciones as DiagnosticoPermisoNotificaciones)
                .solicitarPermisoDetallado();
        permisoNotificaciones = estado == EstadoPermisoNotificaciones.concedido;
        if (!permisoNotificaciones) {
          _mostrarError(
            _mensajePermisoNotificaciones(estado),
            EstadoUbicacion.disponible,
          );
          return;
        }
      } else {
        try {
          permisoNotificaciones = await _notificaciones
              .solicitarPermisoNotificaciones();
        } catch (_) {
          _mostrarError(
            'No pudimos comprobar el permiso de notificaciones. Revisa los ajustes de Cercly e inténtalo de nuevo.',
            EstadoUbicacion.disponible,
          );
          return;
        }
      }
      if (!permisoNotificaciones) {
        if (!mounted) return;
        setState(() {
          _permisoNotificaciones = false;
          _mensaje =
              'Permite las notificaciones de Cercly para activar las alertas.';
          _mensajeError = true;
        });
        return;
      }

      final nueva = _configuracion.copiarCon(activadas: true);
      try {
        await _preferencias.guardar(nueva);
      } catch (_) {
        _mostrarError(
          'No se pudo guardar la preferencia en el dispositivo. Las alertas siguen desactivadas; vuelve a intentarlo.',
          EstadoUbicacion.disponible,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _configuracion = nueva;
        _permisoNotificaciones = true;
        _estadoUbicacion = EstadoUbicacion.disponible;
        _mensaje = 'Alertas activadas. Cercly comprobará promociones solo mientras la app esté abierta.';
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<bool> _consultarPermisoNotificaciones() async {
    final notificaciones = _notificaciones;
    if (notificaciones is DiagnosticoPermisoNotificaciones) {
      final diagnostico = notificaciones as DiagnosticoPermisoNotificaciones;
      return await diagnostico.consultarEstadoDetallado() ==
          EstadoPermisoNotificaciones.concedido;
    }
    return notificaciones.tienePermisoParaNotificar();
  }

  String _mensajePermisoNotificaciones(EstadoPermisoNotificaciones estado) {
    return switch (estado) {
      EstadoPermisoNotificaciones.denegado => 'No concediste el permiso de notificaciones. Puedes habilitarlo en los ajustes de Cercly.',
      EstadoPermisoNotificaciones.desactivadoEnAjustes => 'Las notificaciones de Cercly están desactivadas en Android. Actívalas en Ajustes y vuelve a intentarlo.',
      EstadoPermisoNotificaciones.noDisponible => 'Android no pudo confirmar el permiso de notificaciones. Revisa los ajustes de Cercly e inténtalo de nuevo.',
      EstadoPermisoNotificaciones.errorTecnico => 'Cercly no pudo consultar el permiso del sistema por un error técnico. Inténtalo de nuevo o revisa Ajustes.',
      EstadoPermisoNotificaciones.concedido => '',
    };
  }

  Future<void> _cambiarRadio(int radio) async {
    if (_guardando || _cargando) return;
    final nueva = _configuracion.copiarCon(radioMetros: radio);
    setState(() => _guardando = true);
    try {
      await _preferencias.guardar(nueva);
      if (!mounted) return;
      setState(() {
        _configuracion = nueva;
        _mensaje = 'Radio de proximidad actualizado.';
        _mensajeError = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _mensaje =
              'No se pudo guardar el radio de proximidad en el dispositivo.';
          _mensajeError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _diagnosticarAhora() async {
    final monitor = MonitorProximidadScope.maybeOf(context);
    if (monitor == null) {
      setState(
        () => _diagnostico = 'El monitor no está disponible en esta pantalla.',
      );
      return;
    }
    setState(() => _diagnostico = 'Comprobando permisos y promociones…');
    await monitor.verificarAhora();
    if (!mounted) return;
    setState(() {
      _diagnostico = _textoDiagnostico(monitor.ultimoResultadoDiagnostico);
      _ultimaComprobacion = DateTime.now();
    });
  }

  String _textoDiagnostico(String resultado) => switch (resultado) {
    'notificacion_enviada' =>
      'Prueba completada: Android aceptó la notificación.',
    'notificacion_bloqueada' => 'El envío local fue rechazado por Android. Revisa el permiso de notificaciones.',
    'canal_notificaciones_bloqueado' =>
      'El canal “Promociones cercanas” está bloqueado en Android.',
    'permiso_notificaciones_pendiente' =>
      'Falta habilitar notificaciones para Cercly.',
    'permiso_notificaciones_indeterminado' =>
      'Android no pudo confirmar el permiso de notificaciones.',
    'error_permiso_notificaciones' => 'Falló la consulta nativa del permiso de notificaciones. Revisa el registro cercly.notifications.',
    'permiso_ubicacion_pendiente' || 'permiso_ubicacion_revocado' =>
      'Falta el permiso de ubicación en primer plano.',
    'ubicacion_servicio_desactivado' =>
      'Activa el servicio de ubicación del teléfono.',
    'error_ubicacion' => 'No se pudo obtener la ubicación. Inténtalo mientras Cercly esté abierta.',
    'ubicacion_imprecisa_o_desactualizada' => 'La posición es aproximada o tiene más de dos minutos; las alertas requieren una lectura precisa.',
    'sin_promociones_vigentes' =>
      'No hay promociones vigentes publicadas para evaluar ahora.',
    'sin_promociones_en_radio' =>
      'Hay promociones vigentes, pero ninguna está dentro del radio efectivo.',
    'sin_promociones_elegibles' =>
      'No se encontraron promociones elegibles en el radio.',
    'cooldown_limite_o_misma_zona' => 'No se envió: cooldown, límite global o sigues dentro de una zona ya notificada.',
    'alertas_desactivadas' =>
      'Activa voluntariamente las alertas antes de comprobarlas.',
    'evaluacion_en_curso' => 'Ya hay una comprobación en curso.',
    'error_evaluacion' => 'La comprobación falló por un error de red, GPS o sistema. No se registraron coordenadas.',
    _ => 'Aún no se ha ejecutado una comprobación.',
  };

  void _mostrarError(String mensaje, EstadoUbicacion estado) {
    if (!mounted) return;
    setState(() {
      _estadoUbicacion = estado;
      _mensaje = mensaje;
      _mensajeError = true;
    });
  }

  bool _ubicacionTienePrecisionSuficiente(UbicacionUsuario ubicacion) {
    final precision = ubicacion.precisionMetros;
    final tiempo = ubicacion.capturadaEn;
    if (precision == null ||
        !precision.isFinite ||
        precision <= 0 ||
        precision > 100 ||
        tiempo == null) {
      return false;
    }
    final antiguedad = DateTime.now().difference(tiempo);
    return !antiguedad.isNegative && antiguedad <= const Duration(minutes: 2);
  }

  String _textoPermisosPendientes(EstadoUbicacion? estado) {
    return switch (estado) {
      EstadoUbicacion.servicioDesactivado =>
        'Activa la ubicación del dispositivo y vuelve a intentarlo.',
      EstadoUbicacion.permisoDenegado =>
        'Concede el permiso de ubicación para activar las alertas.',
      EstadoUbicacion.permisoDenegadoPermanentemente =>
        'Habilita la ubicación desde los ajustes de la aplicación.',
      _ => 'Falta un permiso necesario para las alertas cercanas.',
    };
  }

  String get _textoEstadoUbicacion => switch (_estadoUbicacion) {
    EstadoUbicacion.disponible => 'permitida en primer plano',
    EstadoUbicacion.permisoDenegado ||
    EstadoUbicacion.permisoDenegadoPermanentemente => 'no permitida',
    EstadoUbicacion.servicioDesactivado => 'servicio del teléfono apagado',
    _ => 'sin comprobar',
  };

  String get _textoUltimaComprobacion {
    final momento = _ultimaComprobacion;
    if (momento == null) return 'Aún no se ha comprobado';
    final hora = momento.hour.toString().padLeft(2, '0');
    final minuto = momento.minute.toString().padLeft(2, '0');
    return '${momento.day.toString().padLeft(2, '0')}/${momento.month.toString().padLeft(2, '0')} $hora:$minuto';
  }

  Future<void> _abrirAjustes() async {
    var abierto = false;
    try {
      if (_estadoUbicacion != EstadoUbicacion.disponible) {
        abierto = await _ubicacion.abrirAjustesAplicacion();
      } else {
        abierto = await _notificaciones.abrirAjustesNotificaciones();
        // Algunos sistemas MagicOS no resuelven el intent de ajustes de
        // notificaciones. Geolocator abre la ficha estándar de la app.
        if (!abierto) abierto = await _ubicacion.abrirAjustesAplicacion();
      }
    } catch (_) {
      try {
        abierto = await _ubicacion.abrirAjustesAplicacion();
      } catch (_) {
        abierto = false;
      }
    }
    if (!abierto && mounted) await _mostrarInstruccionesAjustes();
  }

  Future<void> _mostrarInstruccionesAjustes() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustes de Cercly'),
        content: const Text(
          'Abre Ajustes del teléfono → Aplicaciones → Cercly → Permisos o Notificaciones. '
          'En Honor/MagicOS, busca “Cercly” en Ajustes si no aparece esa ruta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
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
    final sky = SkyPalette.of(context);
    return CerclySectionCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: sky.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CerclySectionTitle(
                title: 'Alertas de promociones cercanas',
                subtitle:
                    'Recibe un aviso cuando una promoción vigente esté cerca.',
                icon: Icons.notifications_active_outlined,
              ),
              const SizedBox(height: 10),
              Text(
                'Si las activas, Cercly consulta promociones cercanas cuando inicias el Radar en Mapa. La consulta usa tu ubicación actual; no guardamos un historial de tus recorridos en este dispositivo.',
                style: TextStyle(color: sky.muted, height: 1.4, fontSize: 12),
              ),
              const SizedBox(height: 10),
              _EstadoAlertaRow(
                etiqueta: 'Notificaciones',
                valor: _permisoNotificaciones ? 'activadas' : 'desactivadas',
              ),
              _EstadoAlertaRow(
                etiqueta: 'Ubicación',
                valor: _textoEstadoUbicacion,
              ),
              _EstadoAlertaRow(
                etiqueta: 'Precisión',
                valor: switch (_ubicacionPrecisa) {
                  true => 'precisa',
                  false => 'aproximada',
                  null => 'sin comprobar',
                },
              ),
              const _EstadoAlertaRow(
                etiqueta: 'Segundo plano',
                valor: 'no disponible en esta versión',
              ),
              _EstadoAlertaRow(
                etiqueta: 'Última comprobación',
                valor: _textoUltimaComprobacion,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: const Key('alertas-proximidad-switch'),
                contentPadding: EdgeInsets.zero,
                value: _configuracion.activadas,
                onChanged: _cargando || _guardando ? null : _cambiarAlertas,
                title: const Text('Activar alertas'),
                subtitle: Text(
                  _configuracion.activadas
                      ? 'Revisión cada tres minutos solo con Radar activo y Mapa visible.'
                      : 'Desactivadas hasta que tú las actives.',
                ),
                secondary: Icon(
                  _configuracion.activadas
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: sky.interactive,
                ),
              ),
              if (_cargando || _guardando) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(),
              ],
              if (_configuracion.activadas) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('diagnosticar-alertas'),
                    onPressed: _guardando ? null : _diagnosticarAhora,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Comprobar alertas ahora'),
                  ),
                ),
                if (_diagnostico != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _diagnostico!,
                        key: const Key('diagnostico-alertas-resultado'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Radio máximo',
                  style: TextStyle(
                    color: sky.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final radio
                        in ConfiguracionAlertasProximidad
                            .radiosDisponiblesMetros)
                      ChoiceChip(
                        key: Key('radio-alerta-$radio'),
                        label: Text('${radio ~/ 1000} km'),
                        selected: _configuracion.radioMetros == radio,
                        onSelected: _guardando
                            ? null
                            : (seleccionado) {
                                if (seleccionado) _cambiarRadio(radio);
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'El establecimiento también define su propio radio; se aplicará el más corto.',
                  style: TextStyle(
                    color: sky.muted,
                    height: 1.35,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_mensaje != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _mensajeError
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: _mensajeError ? sky.warning : sky.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mensaje!,
                          style: TextStyle(
                            color: _mensajeError ? sky.warning : sky.success,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_mensajeError &&
                  (_estadoUbicacion != EstadoUbicacion.disponible ||
                      !_permisoNotificaciones)) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('abrir-ajustes-alertas'),
                    onPressed: _abrirAjustes,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Abrir ajustes'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoAlertaRow extends StatelessWidget {
  const _EstadoAlertaRow({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              etiqueta,
              style: TextStyle(color: sky.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(valor, style: TextStyle(color: sky.text, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
