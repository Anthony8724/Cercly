import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../services/administracion_destacadas_service.dart';

class AdministracionDestacadasScreen extends StatefulWidget {
  const AdministracionDestacadasScreen({super.key});

  @override
  State<AdministracionDestacadasScreen> createState() =>
      _AdministracionDestacadasScreenState();
}

class _DatosCampanas {
  const _DatosCampanas(this.candidatas, this.campanas);
  final List<PromocionElegibleAdmin> candidatas;
  final List<CampanaDestacadaAdmin> campanas;
}

class _AdministracionDestacadasScreenState
    extends State<AdministracionDestacadasScreen> {
  final AdministracionDestacadasService _servicio =
      AdministracionDestacadasService();
  late Future<_DatosCampanas> _datos;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _datos = _consultar();
  }

  Future<_DatosCampanas> _consultar() async {
    final candidatas = await _servicio.listarElegibles();
    final campanas = await _servicio.listarCampanas();
    return _DatosCampanas(candidatas, campanas);
  }

  Future<void> _recargar() async {
    final nuevaConsulta = _consultar();
    setState(() {
      _datos = nuevaConsulta;
    });
    try {
      await _datos;
    } catch (_) {
      // FutureBuilder presenta el error y la opción de reintentar.
    }
  }

  String _fecha(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  void _mensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _crear(PromocionElegibleAdmin promocion) async {
    if (_procesando) return;
    final dias = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Duración de la campaña'),
        children: [
          for (final cantidad in [1, 3, 7, 14])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(cantidad),
              child: Text('$cantidad ${cantidad == 1 ? 'día' : 'días'}'),
            ),
        ],
      ),
    );
    if (dias == null || !mounted) return;
    setState(() => _procesando = true);
    try {
      final inicio = DateTime.now();
      final solicitado = inicio.add(Duration(days: dias));
      final fin = DateTime.fromMillisecondsSinceEpoch(
        math.min(
          solicitado.millisecondsSinceEpoch,
          promocion.fechaFin.millisecondsSinceEpoch,
        ),
      );
      await _servicio.crearPendiente(
        promocion: promocion,
        inicio: inicio,
        fin: fin,
      );
      _mensaje('Campaña pendiente creada. Debes aprobarla.');
      await _recargar();
    } catch (error) {
      _mensaje('No se pudo crear: $error', error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _cambiar(CampanaDestacadaAdmin campana, String estado) async {
    if (_procesando) return;
    final accion = switch (estado) {
      'aprobada' => 'aprobar',
      'rechazada' => 'rechazar',
      _ => 'cancelar',
    };
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Confirmar $accion campaña?'),
        content: Text('${campana.titulo} · ${campana.establecimiento}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (aceptar != true || !mounted) return;
    setState(() => _procesando = true);
    try {
      await _servicio.cambiarEstado(campana: campana, nuevoEstado: estado);
      _mensaje('Campaña actualizada correctamente.');
      await _recargar();
    } catch (error) {
      _mensaje('No se pudo actualizar: $error', error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Widget _tarjetaPromocion(PromocionElegibleAdmin promocion) {
    final sky = SkyPalette.of(context);
    return Card(
      color: sky.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              promocion.titulo,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(promocion.establecimiento, style: TextStyle(color: sky.muted)),
            const SizedBox(height: 5),
            Text('Vigente hasta ${_fecha(promocion.fechaFin)}'),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: Key('crear-campana-${promocion.id}'),
                onPressed: _procesando ? null : () => _crear(promocion),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Crear campaña'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaCampana(CampanaDestacadaAdmin campana) {
    final sky = SkyPalette.of(context);
    final vigente =
        !DateTime.now().isBefore(campana.fechaInicio) &&
        !DateTime.now().isAfter(campana.fechaFin);
    return Card(
      color: sky.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campana.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(campana.estado)),
              ],
            ),
            Text(campana.establecimiento, style: TextStyle(color: sky.muted)),
            const SizedBox(height: 5),
            Text(
              '${_fecha(campana.fechaInicio)} — ${_fecha(campana.fechaFin)}',
            ),
            if (campana.estado == 'aprobada' && vigente)
              const Text('Visible en Explorar mientras siga vigente.'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                if (campana.estado == 'pendiente') ...[
                  FilledButton(
                    key: Key('aprobar-campana-${campana.id}'),
                    onPressed: _procesando
                        ? null
                        : () => _cambiar(campana, 'aprobada'),
                    child: const Text('Aprobar'),
                  ),
                  OutlinedButton(
                    onPressed: _procesando
                        ? null
                        : () => _cambiar(campana, 'rechazada'),
                    child: const Text('Rechazar'),
                  ),
                ],
                if (campana.estado == 'aprobada')
                  OutlinedButton(
                    onPressed: _procesando
                        ? null
                        : () => _cambiar(campana, 'cancelada'),
                    child: const Text('Cancelar destacada'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        title: const Text('Campañas destacadas'),
        backgroundColor: sky.surface,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _procesando ? null : _recargar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SkySurface(
        child: RefreshIndicator(
          onRefresh: _recargar,
          child: FutureBuilder<_DatosCampanas>(
            future: _datos,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('No se pudo cargar: ${snapshot.error}'),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _recargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              final datos = snapshot.data!;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 36),
                children: [
                  Text(
                    'Administración de patrocinios',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: sky.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Solo administradores. No se procesan pagos.',
                    style: TextStyle(color: sky.muted),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Promociones disponibles en Tulcán',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: sky.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (datos.candidatas.isEmpty)
                    const Text(
                      'No hay promociones vigentes y públicas en Tulcán.',
                    ),
                  for (final promocion in datos.candidatas)
                    _tarjetaPromocion(promocion),
                  const SizedBox(height: 20),
                  Text(
                    'Campañas registradas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: sky.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (datos.campanas.isEmpty)
                    const Text('Aún no existen campañas destacadas.'),
                  for (final campana in datos.campanas)
                    _tarjetaCampana(campana),
                  if (_procesando)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
