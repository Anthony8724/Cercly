import 'package:flutter/material.dart';

import '../../../sky/sky_theme.dart';
import '../models/estadisticas_admin_model.dart';
import '../services/estadisticas_administrador_service.dart';

/// Estadísticas generales de Cercly Sky para el administrador.
///
/// Versión 1: indicadores (KPI), estados de establecimientos y solicitudes, y
/// nuevos registros por periodo. Solo muestra datos reales; lo que aún no se
/// registra (sesiones, búsquedas, visualizaciones) se indica como tal.
class EstadisticasAdministradorScreen extends StatefulWidget {
  const EstadisticasAdministradorScreen({super.key, this.service});

  final EstadisticasAdministradorService? service;

  @override
  State<EstadisticasAdministradorScreen> createState() =>
      _EstadisticasAdministradorScreenState();
}

class _EstadisticasAdministradorScreenState
    extends State<EstadisticasAdministradorScreen> {
  late final EstadisticasAdministradorService _service;
  late Future<EstadisticasResumenModel> _resumenFuture;
  late Future<List<RegistroPeriodoModel>> _registrosFuture;

  int _rangoDias = 30;
  GranularidadRegistros _granularidad = GranularidadRegistros.dia;
  String _tipoUsuario = 'todos';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EstadisticasAdministradorService();
    _resumenFuture = _service.obtenerResumen();
    _cargarRegistros();
  }

  void _cargarRegistros() {
    final hoy = DateTime.now();
    final hasta = DateTime(hoy.year, hoy.month, hoy.day);
    final desde = hasta.subtract(Duration(days: _rangoDias - 1));
    _registrosFuture = _service.obtenerRegistros(
      desde: desde,
      hasta: hasta,
      granularidad: _granularidad,
    );
  }

  Future<void> _recargar() async {
    setState(() {
      _resumenFuture = _service.obtenerResumen();
      _cargarRegistros();
    });
    try {
      await Future.wait<Object?>([_resumenFuture, _registrosFuture]);
    } catch (_) {
      // Los errores se muestran en cada sección mediante su FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SkyPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Estadísticas'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: palette.headerGradient),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<EstadisticasResumenModel>(
              future: _resumenFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _Cargando();
                }
                if (snapshot.hasError) {
                  return _ErrorSeccion(
                    palette: palette,
                    mensaje: EstadisticasAdministradorService.mensajeError(
                      snapshot.error!,
                    ),
                    onReintentar: _recargar,
                  );
                }
                return _ContenidoResumen(
                  palette: palette,
                  resumen: snapshot.data!,
                  service: _service,
                );
              },
            ),
            const SizedBox(height: 24),
            _SeccionTitulo(palette: palette, titulo: 'Nuevos registros'),
            const SizedBox(height: 8),
            _filtrosRegistros(palette),
            const SizedBox(height: 12),
            FutureBuilder<List<RegistroPeriodoModel>>(
              future: _registrosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _Cargando();
                }
                if (snapshot.hasError) {
                  return _ErrorSeccion(
                    palette: palette,
                    mensaje: EstadisticasAdministradorService.mensajeError(
                      snapshot.error!,
                    ),
                    onReintentar: _recargar,
                  );
                }
                return _ListaRegistros(
                  palette: palette,
                  registros: snapshot.data!,
                  tipoUsuario: _tipoUsuario,
                  granularidad: _granularidad,
                );
              },
            ),
            const SizedBox(height: 24),
            _NotaSinDatos(palette: palette),
          ],
        ),
      ),
    );
  }

  Widget _filtrosRegistros(SkyPalette palette) {
    ChoiceChip chip({
      required String etiqueta,
      required bool seleccionado,
      required VoidCallback alSeleccionar,
    }) {
      return ChoiceChip(
        label: Text(etiqueta),
        selected: seleccionado,
        selectedColor: palette.selectedSurface,
        backgroundColor: palette.surface,
        side: BorderSide(color: palette.border),
        labelStyle: TextStyle(color: palette.text),
        onSelected: (_) => alSeleccionar(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final dias in const [7, 30, 90])
              chip(
                etiqueta: '$dias días',
                seleccionado: _rangoDias == dias,
                alSeleccionar: () => setState(() {
                  _rangoDias = dias;
                  _cargarRegistros();
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in GranularidadRegistros.values)
              chip(
                etiqueta: g.etiqueta,
                seleccionado: _granularidad == g,
                alSeleccionar: () => setState(() {
                  _granularidad = g;
                  _cargarRegistros();
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tipo in const [
              ('todos', 'Todos'),
              ('usuario', 'Usuarios'),
              ('propietario', 'Propietarios'),
            ])
              chip(
                etiqueta: tipo.$2,
                seleccionado: _tipoUsuario == tipo.$1,
                alSeleccionar: () => setState(() => _tipoUsuario = tipo.$1),
              ),
          ],
        ),
      ],
    );
  }
}

class _ContenidoResumen extends StatelessWidget {
  const _ContenidoResumen({
    required this.palette,
    required this.resumen,
    required this.service,
  });

  final SkyPalette palette;
  final EstadisticasResumenModel resumen;
  final EstadisticasAdministradorService service;

  void _abrirDetalle(
      BuildContext context, {
        required String titulo,
        required TipoIndicadorAdmin tipo,
      }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    titulo,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<DetalleEstadisticaItem>>(
                      stream: service.streamDetalleIndicador(
                        tipo,
                        diasActivos: resumen.diasUsuarioActivo,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              EstadisticasAdministradorService.mensajeError(
                                snapshot.error!,
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.error),
                            ),
                          );
                        }
                        final items = snapshot.data ?? const [];
                        if (items.isEmpty) {
                          return Center(
                            child: Text(
                              'No hay registros para mostrar.',
                              style: TextStyle(color: palette.muted),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: palette.border),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: palette.soft,
                                child: Icon(
                                  Icons.person_outline,
                                  color: palette.interactive,
                                ),
                              ),
                              title: Text(
                                item.titulo,
                                style: TextStyle(
                                  color: palette.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: item.subtitulo != null &&
                                  item.subtitulo!.isNotEmpty
                                  ? Text(
                                item.subtitulo!,
                                style: TextStyle(color: palette.muted),
                              )
                                  : null,
                              trailing: item.estado != null
                                  ? Text(
                                item.estado!,
                                style: TextStyle(
                                  color: palette.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpis = <_KpiCard>[
      _KpiCard(
        palette: palette,
        icono: Icons.people_outline,
        titulo: 'Usuarios registrados',
        valor: '${resumen.usuariosTotal}',
        onTap: () => _abrirDetalle(
          context,
          titulo: 'Usuarios registrados (${resumen.usuariosTotal})',
          tipo: TipoIndicadorAdmin.usuariosRegistrados,
        ),
      ),
      _KpiCard(
        palette: palette,
        icono: Icons.storefront_outlined,
        titulo: 'Propietarios',
        valor: '${resumen.propietariosTotal}',
        detalle: '${resumen.usuariosNormalesTotal} usuarios normales',
        onTap: () => _abrirDetalle(
          context,
          titulo: 'Propietarios (${resumen.propietariosTotal})',
          tipo: TipoIndicadorAdmin.propietarios,
        ),
      ),
      _KpiCard(
        palette: palette,
        icono: Icons.login,
        titulo: 'Usuarios activos',
        valor: '${resumen.usuariosActivos}',
        detalle: 'Con inicio de sesión en ${resumen.diasUsuarioActivo} días',
        onTap: () => _abrirDetalle(
          context,
          titulo: 'Usuarios activos (${resumen.usuariosActivos})',
          tipo: TipoIndicadorAdmin.usuariosActivos,
        ),
      ),
      _KpiCard(
        palette: palette,
        icono: Icons.pending_actions_outlined,
        titulo: 'Solicitudes pendientes',
        valor: '${resumen.solicitudes.pendientes}',
        onTap: () => _abrirDetalle(
          context,
          titulo: 'Solicitudes pendientes (${resumen.solicitudes.pendientes})',
          tipo: TipoIndicadorAdmin.solicitudesPendientes,
        ),
      ),
      _KpiCard(
        palette: palette,
        icono: Icons.store_mall_directory_outlined,
        titulo: 'Establecimientos',
        valor: '${resumen.establecimientos.total}',
        onTap: () => _abrirDetalle(
          context,
          titulo: 'Establecimientos (${resumen.establecimientos.total})',
          tipo: TipoIndicadorAdmin.establecimientos,
        ),
      ),
      _KpiCard(
        palette: palette,
        icono: Icons.local_offer_outlined,
        titulo: 'Promociones activas',
        valor: '${resumen.promocionesActivas}',
        detalle: '${resumen.promocionesTotal} creadas en total',
        onTap: () => _abrirDetalle(
          context,
          titulo: 'Promociones activas (${resumen.promocionesActivas})',
          tipo: TipoIndicadorAdmin.promocionesActivas,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeccionTitulo(palette: palette, titulo: 'Indicadores generales'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 720 ? 3 : 2;
            const separacion = 12.0;
            final ancho =
                (constraints.maxWidth - separacion * (columnas - 1)) /
                    columnas;
            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: [
                for (final kpi in kpis) SizedBox(width: ancho, child: kpi),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _SeccionTitulo(
          palette: palette,
          titulo: 'Establecimientos por estado',
        ),
        const SizedBox(height: 8),
        _TarjetaEstados(
          palette: palette,
          conteo: resumen.establecimientos,
          etiquetaAprobados: 'Aprobados',
          etiquetaRechazados: 'Rechazados',
        ),
        const SizedBox(height: 24),
        _SeccionTitulo(palette: palette, titulo: 'Solicitudes por estado'),
        const SizedBox(height: 8),
        _TarjetaEstados(
          palette: palette,
          conteo: resumen.solicitudes,
          etiquetaAprobados: 'Aprobadas',
          etiquetaRechazados: 'Rechazadas',
        ),
        const SizedBox(height: 8),
        Text(
          'Datos generados el ${_fechaHora(resumen.generadoEn.toLocal())}',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _TarjetaEstados extends StatelessWidget {
  const _TarjetaEstados({
    required this.palette,
    required this.conteo,
    required this.etiquetaAprobados,
    required this.etiquetaRechazados,
  });

  final SkyPalette palette;
  final ConteoPorEstado conteo;
  final String etiquetaAprobados;
  final String etiquetaRechazados;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      palette: palette,
      child: Column(
        children: [
          _FilaBarra(
            palette: palette,
            etiqueta: 'Pendientes',
            valor: conteo.pendientes,
            total: conteo.total,
            color: palette.warning,
          ),
          const SizedBox(height: 12),
          _FilaBarra(
            palette: palette,
            etiqueta: etiquetaAprobados,
            valor: conteo.aprobados,
            total: conteo.total,
            color: palette.success,
          ),
          const SizedBox(height: 12),
          _FilaBarra(
            palette: palette,
            etiqueta: etiquetaRechazados,
            valor: conteo.rechazados,
            total: conteo.total,
            color: palette.error,
          ),
        ],
      ),
    );
  }
}

class _ListaRegistros extends StatelessWidget {
  const _ListaRegistros({
    required this.palette,
    required this.registros,
    required this.tipoUsuario,
    required this.granularidad,
  });

  final SkyPalette palette;
  final List<RegistroPeriodoModel> registros;
  final String tipoUsuario;
  final GranularidadRegistros granularidad;

  @override
  Widget build(BuildContext context) {
    final totales = <DateTime, int>{};
    for (final fila in registros) {
      if (tipoUsuario != 'todos' && fila.tipoUsuario != tipoUsuario) continue;
      totales.update(
        fila.periodo,
            (actual) => actual + fila.total,
        ifAbsent: () => fila.total,
      );
    }

    if (totales.isEmpty) {
      return _Tarjeta(
        palette: palette,
        child: Text(
          'No hay registros nuevos en este rango.',
          style: TextStyle(color: palette.muted),
        ),
      );
    }

    final periodos = totales.keys.toList()..sort();
    final maximo = totales.values.reduce((a, b) => a > b ? a : b);

    return _Tarjeta(
      palette: palette,
      child: Column(
        children: [
          for (final periodo in periodos) ...[
            _FilaBarra(
              palette: palette,
              etiqueta: _etiquetaPeriodo(periodo, granularidad),
              valor: totales[periodo]!,
              total: maximo,
              color: palette.interactive,
            ),
            if (periodo != periodos.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.palette,
    required this.icono,
    required this.titulo,
    required this.valor,
    this.detalle,
    this.onTap,
  });

  final SkyPalette palette;
  final IconData icono;
  final String titulo;
  final String valor;
  final String? detalle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: _Tarjeta(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icono, color: palette.interactive),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 18, color: palette.muted),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(titulo, style: TextStyle(color: palette.text)),
              if (detalle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    detalle!,
                    style: TextStyle(color: palette.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaBarra extends StatelessWidget {
  const _FilaBarra({
    required this.palette,
    required this.etiqueta,
    required this.valor,
    required this.total,
    required this.color,
  });

  final SkyPalette palette;
  final String etiqueta;
  final int valor;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final proporcion = total <= 0 ? 0.0 : (valor / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiqueta, style: TextStyle(color: palette.text)),
            Text(
              '$valor',
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: proporcion,
          minHeight: 8,
          color: color,
          backgroundColor: palette.soft,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.palette, required this.child});

  final SkyPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo({required this.palette, required this.titulo});

  final SkyPalette palette;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: TextStyle(
        color: palette.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NotaSinDatos extends StatelessWidget {
  const _NotaSinDatos({required this.palette});

  final SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      palette: palette,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: palette.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sesiones, búsquedas, visualizaciones de establecimientos e '
                  'interacciones con promociones todavía no se registran, por '
                  'eso no aparecen aquí. Se agregarán cuando se apruebe el '
                  'registro de eventos.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorSeccion extends StatelessWidget {
  const _ErrorSeccion({
    required this.palette,
    required this.mensaje,
    required this.onReintentar,
  });

  final SkyPalette palette;
  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      palette: palette,
      child: Column(
        children: [
          Icon(Icons.error_outline, color: palette.error),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.text),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

String _dosDigitos(int valor) => valor.toString().padLeft(2, '0');

String _fechaHora(DateTime fecha) =>
    '${_dosDigitos(fecha.day)}/${_dosDigitos(fecha.month)}/${fecha.year} '
        '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';

String _etiquetaPeriodo(DateTime periodo, GranularidadRegistros granularidad) {
  return switch (granularidad) {
    GranularidadRegistros.dia =>
    '${_dosDigitos(periodo.day)}/${_dosDigitos(periodo.month)}/'
        '${periodo.year}',
    GranularidadRegistros.semana =>
    'Semana del ${_dosDigitos(periodo.day)}/${_dosDigitos(periodo.month)}',
    GranularidadRegistros.mes => '${_dosDigitos(periodo.month)}/${periodo.year}',
  };
}