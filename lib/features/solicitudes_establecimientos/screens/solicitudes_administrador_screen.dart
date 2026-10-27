import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';

import '../models/solicitud_establecimiento_model.dart';
import '../services/solicitud_establecimiento_service.dart';
import '../../establecimientos/services/establecimiento_service.dart';

class SolicitudesAdministradorScreen extends StatefulWidget {
  const SolicitudesAdministradorScreen({super.key});

  @override
  State<SolicitudesAdministradorScreen> createState() =>
      _SolicitudesAdministradorScreenState();
}

class _SolicitudesAdministradorScreenState
    extends State<SolicitudesAdministradorScreen> {
  final SolicitudEstablecimientoService _service =
      SolicitudEstablecimientoService();
  final EstablecimientoService _establecimientos = EstablecimientoService();

  late Future<List<SolicitudEstablecimientoDetalle>> _solicitudesFuture;
  late Future<List<Map<String, dynamic>>> _categoriasFuture;

  String _estadoSeleccionado = SolicitudEstablecimientoModel.estadoPendiente;

  String? _solicitudProcesando;

  @override
  void initState() {
    super.initState();
    _categoriasFuture = _establecimientos.listarCategoriasParaRevision();
    _cargar();
  }

  void _cargar() {
    _solicitudesFuture = _service.listarTodas();
  }

  Future<void> _recargar() async {
    setState(_cargar);
    await _solicitudesFuture;
  }

  Future<void> _responder(
    SolicitudEstablecimientoDetalle detalle,
    String nuevoEstado,
  ) async {
    final aprobando =
        nuevoEstado == SolicitudEstablecimientoModel.estadoAprobada;

    final motivo = await showDialog<String>(
      context: context,
      builder: (_) {
        return _DialogoRespuesta(
          aprobando: aprobando,
          nombreEstablecimiento: detalle.nombreEstablecimiento,
        );
      },
    );

    if (motivo == null || !mounted) {
      return;
    }

    setState(() {
      _solicitudProcesando = detalle.solicitud.id;
    });

    try {
      await _service.responder(
        solicitudId: detalle.solicitud.id,
        estado: nuevoEstado,
        motivoRespuesta: motivo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _solicitudProcesando = null;
        _cargar();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aprobando
                ? 'Solicitud aprobada correctamente.'
                : 'Solicitud rechazada correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _solicitudProcesando = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo responder: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDetalles(SolicitudEstablecimientoDetalle detalle) {
    final solicitud = detalle.solicitud;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalles de la solicitud',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _Detalle(
                  etiqueta: 'Solicitante',
                  valor: detalle.nombreSolicitante,
                ),
                _Detalle(
                  etiqueta: 'Establecimiento',
                  valor: detalle.nombreEstablecimiento,
                ),
                _Detalle(
                  etiqueta: 'Dirección',
                  valor: detalle.direccionEstablecimiento,
                ),
                if (solicitud.tipo ==
                    SolicitudEstablecimientoModel.tipoRegistro) ...[
                  _categoriaSolicitud(detalle),
                  _Detalle(
                    etiqueta: 'Descripción',
                    valor:
                        detalle.datosPropuestos['descripcion'] as String? ??
                        'Sin descripción',
                  ),
                  _Detalle(
                    etiqueta: 'Contacto comercial',
                    valor:
                        detalle.datosPropuestos['telefono_publico']
                            as String? ??
                        'Sin contacto',
                  ),
                  _Detalle(
                    etiqueta: 'Coordenadas',
                    valor:
                        '${detalle.datosPropuestos['latitud']}, ${detalle.datosPropuestos['longitud']}',
                  ),
                  if (detalle.datosPropuestos['latitud'] is num &&
                      detalle.datosPropuestos['longitud'] is num) ...[
                    const SizedBox(height: 10),
                    _VistaMapaSolicitud(
                      latitud: (detalle.datosPropuestos['latitud'] as num)
                          .toDouble(),
                      longitud: (detalle.datosPropuestos['longitud'] as num)
                          .toDouble(),
                    ),
                  ],
                  _coincidenciasRegistro(detalle),
                ],
                _Detalle(
                  etiqueta: 'Tipo de solicitud',
                  valor: _nombreTipo(solicitud.tipo),
                ),
                _Detalle(
                  etiqueta: 'Mensaje',
                  valor: solicitud.mensaje.isEmpty
                      ? 'Sin mensaje'
                      : solicitud.mensaje,
                ),
                _Detalle(
                  etiqueta: 'Estado',
                  valor: _nombreEstado(solicitud.estado),
                ),
                _Detalle(
                  etiqueta: 'Fecha',
                  valor: _formatearFecha(solicitud.creadoEn),
                ),
                if (solicitud.motivoRespuesta.isNotEmpty)
                  _Detalle(
                    etiqueta: 'Respuesta del administrador',
                    valor: solicitud.motivoRespuesta,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(bottomSheetContext).pop();
                    },
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _coincidenciasRegistro(SolicitudEstablecimientoDetalle detalle) {
    final datos = detalle.datosPropuestos;
    final latitud = datos['latitud'];
    final longitud = datos['longitud'];
    if (latitud is! num || longitud is! num) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _establecimientos.buscarCoincidenciasCercanas(
        nombre: datos['nombre'] as String? ?? '',
        latitud: latitud.toDouble(),
        longitud: longitud.toDouble(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return const Text('No se pudieron consultar posibles coincidencias.');
        }
        final coincidencias = snapshot.data ?? [];
        if (coincidencias.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Sin coincidencias publicadas en un radio de 500 m.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Posibles duplicados cercanos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final coincidencia in coincidencias)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  coincidencia['nombre'] as String? ?? 'Establecimiento',
                ),
                subtitle: Text(
                  '${coincidencia['direccion'] ?? 'Sin dirección'} · '
                  '${(coincidencia['distancia_metros'] as double).round()} m',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _categoriaSolicitud(SolicitudEstablecimientoDetalle detalle) {
    final categoriaId = detalle.datosPropuestos['categoria_id'] as String?;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _categoriasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Detalle(etiqueta: 'Categoría', valor: 'Cargando…');
        }
        if (snapshot.hasError) {
          return const _Detalle(
            etiqueta: 'Categoría',
            valor: 'No se pudo verificar la categoría',
          );
        }
        final filas = snapshot.data ?? [];
        final fila = filas.where((item) => item['id'] == categoriaId);
        if (fila.isEmpty) {
          return const _Detalle(
            etiqueta: 'Categoría',
            valor: 'Categoría no disponible',
          );
        }
        final categoria = fila.first;
        final nombre = categoria['nombre'] as String? ?? 'Sin nombre';
        final activa = categoria['activa'] as bool? ?? false;
        return _Detalle(
          etiqueta: 'Categoría',
          valor: activa ? nombre : '$nombre (inactiva)',
        );
      },
    );
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case SolicitudEstablecimientoModel.tipoAcceso:
        return 'Solicitar acceso';
      case SolicitudEstablecimientoModel.tipoCorreccion:
        return 'Solicitar corrección';
      case SolicitudEstablecimientoModel.tipoRegistro:
        return 'Registrar nuevo establecimiento';
      default:
        return 'Reclamar establecimiento';
    }
  }

  String _nombreEstado(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return 'Aprobada';
      case SolicitudEstablecimientoModel.estadoRechazada:
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return Icons.check_circle;
      case SolicitudEstablecimientoModel.estadoRechazada:
        return Icons.cancel;
      default:
        return Icons.pending_actions;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return Colors.green;
      case SolicitudEstablecimientoModel.estadoRechazada:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin fecha';
    }

    String dosDigitos(int valor) {
      return valor.toString().padLeft(2, '0');
    }

    return '${dosDigitos(fecha.day)}/'
        '${dosDigitos(fecha.month)}/'
        '${fecha.year} '
        '${dosDigitos(fecha.hour)}:'
        '${dosDigitos(fecha.minute)}';
  }

  Widget _botonCabecera({
    required IconData icono,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icono, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Container(
      height: 158,
      decoration: BoxDecoration(
        gradient: SkyPalette.of(context).headerGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _botonCabecera(
                    icono: Icons.arrow_back_rounded,
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitudes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Gestiona las solicitudes de establecimientos',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _botonCabecera(
                    icono: Icons.refresh_rounded,
                    tooltip: 'Actualizar',
                    onPressed: _recargar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorEstado() {
    Widget opcion(String estado, String texto, IconData icono) {
      final seleccionado = estado == _estadoSeleccionado;

      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _estadoSeleccionado = estado),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: seleccionado
                  ? SkyPalette.of(context).primary
                  : SkyPalette.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: seleccionado
                    ? SkyPalette.of(context).primary
                    : SkyPalette.of(context).border,
              ),
              boxShadow: seleccionado
                  ? const [
                      BoxShadow(
                        color: Color(0x241769FF),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icono,
                    size: 14,
                    color: seleccionado
                        ? Colors.white
                        : SkyPalette.of(context).text,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    texto,
                    style: TextStyle(
                      color: seleccionado
                          ? Colors.white
                          : SkyPalette.of(context).text,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opcion(
          SolicitudEstablecimientoModel.estadoPendiente,
          'Pendientes',
          Icons.schedule_rounded,
        ),
        const SizedBox(width: 8),
        opcion(
          SolicitudEstablecimientoModel.estadoAprobada,
          'Aprobadas',
          Icons.check_circle_outline_rounded,
        ),
        const SizedBox(width: 8),
        opcion(
          SolicitudEstablecimientoModel.estadoRechazada,
          'Rechazadas',
          Icons.cancel_outlined,
        ),
      ],
    );
  }

  String _textoVacioSecundario(String estado) {
    switch (estado) {
      case SolicitudEstablecimientoModel.estadoAprobada:
        return 'Las solicitudes aprobadas aparecerán aquí.';
      case SolicitudEstablecimientoModel.estadoRechazada:
        return 'Las solicitudes rechazadas aparecerán aquí.';
      default:
        return 'Las nuevas solicitudes aparecerán aquí.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkyPalette.of(context).background,
      body: SkySurface(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _cabecera(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitudes de establecimientos',
                      style: TextStyle(
                        color: SkyPalette.of(context).text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Revisa las solicitudes antes de aprobarlas o rechazarlas.',
                      style: TextStyle(
                        color: SkyPalette.of(context).muted,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _selectorEstado(),
                    const SizedBox(height: 20),
                    FutureBuilder<List<SolicitudEstablecimientoDetalle>>(
                      future: _solicitudesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return _Mensaje(
                            icono: Icons.error_outline,
                            texto:
                                'No se pudieron cargar las solicitudes.\n'
                                '${snapshot.error}',
                            boton: 'Reintentar',
                            onPressed: _recargar,
                          );
                        }

                        final todas =
                            snapshot.data ??
                            <SolicitudEstablecimientoDetalle>[];

                        final solicitudes = todas
                            .where(
                              (detalle) =>
                                  detalle.solicitud.estado ==
                                  _estadoSeleccionado,
                            )
                            .toList();

                        if (solicitudes.isEmpty) {
                          return _Mensaje(
                            icono: _iconoEstado(_estadoSeleccionado),
                            texto:
                                'No hay solicitudes '
                                '${_nombreEstado(_estadoSeleccionado).toLowerCase()}s.',
                            textoSecundario: _textoVacioSecundario(
                              _estadoSeleccionado,
                            ),
                          );
                        }

                        return Column(
                          children: solicitudes.map((detalle) {
                            final solicitud = detalle.solicitud;
                            final procesando =
                                _solicitudProcesando == solicitud.id;
                            final color = _colorEstado(solicitud.estado);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: SkyPalette.of(context).surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: SkyPalette.of(context).border,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D0A2A66),
                                    blurRadius: 14,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                          child: Icon(
                                            _iconoEstado(solicitud.estado),
                                            color: color,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                detalle.nombreEstablecimiento,
                                                style: TextStyle(
                                                  color: SkyPalette.of(context)
                                                      .text,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _nombreTipo(solicitud.tipo),
                                                style: TextStyle(
                                                  color: SkyPalette.of(context)
                                                      .muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Chip(
                                          backgroundColor: color.withValues(
                                            alpha: 0.09,
                                          ),
                                          side: BorderSide.none,
                                          visualDensity: VisualDensity.compact,
                                          avatar: Icon(
                                            _iconoEstado(solicitud.estado),
                                            color: color,
                                            size: 18,
                                          ),
                                          label: Text(
                                            _nombreEstado(solicitud.estado),
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Solicitante: '
                                      '${detalle.nombreSolicitante}',
                                      style: TextStyle(
                                        color: SkyPalette.of(context).text,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 13,
                                          color: SkyPalette.of(context).muted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formatearFecha(solicitud.creadoEn),
                                          style: TextStyle(
                                            color: SkyPalette.of(context).muted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      solicitud.mensaje.isEmpty
                                          ? 'Sin mensaje'
                                          : solicitud.mensaje,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: SkyPalette.of(context).muted,
                                        fontSize: 12.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (procesando)
                                      const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              _mostrarDetalles(detalle);
                                            },
                                            child: const Text('Ver detalles'),
                                          ),
                                          if (solicitud.estaPendiente) ...[
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                _responder(
                                                  detalle,
                                                  SolicitudEstablecimientoModel
                                                      .estadoRechazada,
                                                );
                                              },
                                              icon: const Icon(Icons.close),
                                              label: const Text('Rechazar'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),
                                            FilledButton.icon(
                                              onPressed: () {
                                                _responder(
                                                  detalle,
                                                  SolicitudEstablecimientoModel
                                                      .estadoAprobada,
                                                );
                                              },
                                              icon: const Icon(Icons.check),
                                              label: const Text('Aprobar'),
                                            ),
                                          ],
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogoRespuesta extends StatefulWidget {
  const _DialogoRespuesta({
    required this.aprobando,
    required this.nombreEstablecimiento,
  });

  final bool aprobando;
  final String nombreEstablecimiento;

  @override
  State<_DialogoRespuesta> createState() => _DialogoRespuestaState();
}

class _DialogoRespuestaState extends State<_DialogoRespuesta> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _motivoController = TextEditingController();

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_motivoController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.aprobando ? 'Aprobar solicitud' : 'Rechazar solicitud',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.aprobando
                  ? 'Se aprobará la solicitud para '
                        '"${widget.nombreEstablecimiento}".'
                  : 'Indica por qué se rechazará la solicitud para '
                        '"${widget.nombreEstablecimiento}".',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motivoController,
              maxLength: 1000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.aprobando
                    ? 'Observación opcional'
                    : 'Motivo del rechazo',
                border: const OutlineInputBorder(),
              ),
              validator: (valor) {
                final texto = valor?.trim() ?? '';

                if (!widget.aprobando && texto.isEmpty) {
                  return 'El motivo del rechazo es obligatorio.';
                }

                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          style: widget.aprobando
              ? null
              : FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text(widget.aprobando ? 'Aprobar' : 'Rechazar'),
        ),
      ],
    );
  }
}

class _VistaMapaSolicitud extends StatelessWidget {
  const _VistaMapaSolicitud({required this.latitud, required this.longitud});

  final double latitud;
  final double longitud;

  @override
  Widget build(BuildContext context) {
    final punto = LatLng(latitud, longitud);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        child: FlutterMap(
          options: MapOptions(initialCenter: punto, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cercly.cercly',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: punto,
                  width: 42,
                  height: 42,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: const [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(valor),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.texto,
    this.textoSecundario,
    this.boton,
    this.onPressed,
  });

  final IconData icono;
  final String texto;
  final String? textoSecundario;
  final String? boton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: SkyPalette.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkyPalette.of(context).border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0A2A66),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SkyPalette.of(context).soft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icono, size: 27, color: SkyPalette.of(context).primary),
          ),
          const SizedBox(height: 15),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SkyPalette.of(context).text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (textoSecundario != null) ...[
            const SizedBox(height: 6),
            Text(
              textoSecundario!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SkyPalette.of(context).muted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (boton != null && onPressed != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(boton!)),
          ],
        ],
      ),
    );
  }
}
