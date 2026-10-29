import 'package:flutter/material.dart';

import '../../../sky/sky_backdrop.dart';
import '../../../sky/sky_theme.dart';
import '../../../shared/ui/cercly_ui.dart';
import '../../categorias/models/categoria_model.dart';
import '../../categorias/services/categoria_publica_service.dart';
import '../models/preferencias_usuario.dart';
import '../services/preferencias_usuario_service.dart';

class MisPreferenciasScreen extends StatefulWidget {
  const MisPreferenciasScreen({super.key, this.service, this.categorias});
  final PreferenciasUsuarioService? service;
  final CategoriaPublicaRepository? categorias;

  @override
  State<MisPreferenciasScreen> createState() => _MisPreferenciasScreenState();
}

class _MisPreferenciasScreenState extends State<MisPreferenciasScreen> {
  late final PreferenciasUsuarioService _service;
  late final CategoriaPublicaRepository _categorias;
  late Future<void> _carga;
  PreferenciasUsuario _value = const PreferenciasUsuario();
  PreferenciasUsuario _guardadas = const PreferenciasUsuario();
  List<CategoriaModel> _opciones = const [];
  bool _guardando = false;
  String? _error;
  bool _conflicto = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PreferenciasUsuarioService();
    _categorias = widget.categorias ?? CategoriaPublicaService();
    _carga = _cargar();
  }

  Future<void> _cargar() async {
    try {
      var conflictoSync = false;
      try {
        await _service.sincronizarPendientes();
      } on PreferenciasConflictException {
        conflictoSync = true;
      }
      final results = await Future.wait<Object>([
        _service.cargar(),
        _categorias.listarCategorias(),
      ]);
      _value = results[0] as PreferenciasUsuario;
      _guardadas = _value;
      _opciones = results[1] as List<CategoriaModel>;
      _conflicto = conflictoSync;
      _error = conflictoSync
          ? 'Tus preferencias cambiaron en otro dispositivo. Conservamos esta edición local para que elijas cómo continuar.'
          : null;
    } catch (_) {
      _error = 'No pudimos cargar tus preferencias. Revisa tu conexión e inténtalo de nuevo.';
    }
    if (mounted) setState(() {});
  }

  bool get _hayCambios =>
      _value.radioMetros != _guardadas.radioMetros ||
      _value.priorizarPromociones != _guardadas.priorizarPromociones ||
      _value.categoriasIds.length != _guardadas.categoriasIds.length ||
      !_value.categoriasIds.containsAll(_guardadas.categoriasIds);

  void _cambiar(PreferenciasUsuario value) => setState(() => _value = value);

  Future<void> _guardar({bool restablecer = false}) async {
    setState(() {
      _guardando = true;
      _error = null;
      _conflicto = false;
    });
    final draft = restablecer
        ? PreferenciasUsuario(revision: _value.revision)
        : _value;
    try {
      final saved = await _service.guardar(draft);
      if (!mounted) return;
      setState(() {
        _value = saved;
        _guardadas = saved;
        _guardando = false;
      });
    } on PreferenciasConflictException {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _conflicto = true;
        _error = 'Tus preferencias cambiaron en otro dispositivo. Conservamos esta edición local para que elijas cómo continuar.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar. Tus cambios siguen disponibles en este dispositivo.';
      });
    }
  }

  Future<void> _usarServidor() async {
    try {
      await _service.descartarCambiosLocales();
      await _cargar();
      if (mounted) setState(() => _conflicto = false);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudieron recuperar las preferencias del servidor.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(
        title: const Text(
          'Mis preferencias',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: sky.headerGradient),
        ),
      ),
      body: SkySurface(
        child: FutureBuilder<void>(
          future: _carga,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && _opciones.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => setState(() => _carga = _cargar()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              key: const Key('lista-mis-preferencias'),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: sky.headerGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: sky.primary.withValues(alpha: .14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .2),
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Encuentra lugares a tu manera',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Personaliza tus recomendaciones. Siempre podrás explorar todos los establecimientos.',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 13,
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
                _EstadoPreferencias(
                  cambios: _hayCambios,
                  pendiente: _value.pendienteSincronizar,
                  guardando: _guardando,
                  conflicto: _conflicto,
                  error: _error,
                  alCargarServidor: _conflicto ? _usarServidor : null,
                ),
                const SizedBox(height: 14),
                CerclySectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CerclySectionTitle(
                        title: 'Categorías favoritas',
                        subtitle:
                            'Elige varias para ver más lugares de tu interés.',
                        icon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 15),
                      if (_opciones.isEmpty)
                        Text(
                          'No hay categorías disponibles por ahora.',
                          style: TextStyle(color: sky.muted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 9,
                          children: [
                            for (final categoria in _opciones)
                              _CategoriaPreferenciaChip(
                                categoria: categoria,
                                selected: _value.categoriasIds.contains(
                                  categoria.id,
                                ),
                                enabled: !_guardando,
                                icono: _icono(categoria.icono),
                                onSelected: (selected) {
                                  final ids = {..._value.categoriasIds};
                                  if (selected) {
                                    ids.add(categoria.id);
                                  } else {
                                    ids.remove(categoria.id);
                                  }
                                  _cambiar(_value.copyWith(categoriasIds: ids));
                                },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CerclySectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CerclySectionTitle(
                        title: 'Distancia preferida',
                        subtitle: 'Define qué tan lejos quieres explorar.',
                        icon: Icons.near_me_outlined,
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 9,
                        children: [
                          for (final radio
                              in PreferenciasUsuario.radiosPermitidos)
                            _RadioPreferenciaChip(
                              radio: radio,
                              selected: _value.radioMetros == radio,
                              enabled: !_guardando,
                              onSelected: () => _cambiar(
                                _value.copyWith(
                                  radioMetros: radio,
                                  limpiarRadio: radio == null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PromocionesPreferenciaCard(
                  selected: _value.priorizarPromociones,
                  enabled: !_guardando,
                  onChanged: (value) =>
                      _cambiar(_value.copyWith(priorizarPromociones: value)),
                ),
                const SizedBox(height: 18),
                _AccionesPreferencias(
                  guardando: _guardando,
                  onGuardar: () => _guardar(),
                  onRestablecer: () => _guardar(restablecer: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _icono(String nombre) => switch (nombre.toLowerCase()) {
    'restaurant' || 'restaurant_menu' => Icons.restaurant_outlined,
    'local_cafe' ||
    'coffee' ||
    'bakery_dining' ||
    'fastfood' ||
    'icecream' => Icons.local_cafe_outlined,
    'shopping_bag' ||
    'store' ||
    'storefront' ||
    'shopping_basket' ||
    'shopping_cart' ||
    'shopping_mall' ||
    'warehouse' => Icons.storefront_outlined,
    'health_and_safety' ||
    'medical_services' ||
    'local_pharmacy' ||
    'biotech' ||
    'visibility' ||
    'self_improvement' => Icons.medical_services_outlined,
    'hotel' || 'bed' => Icons.hotel_outlined,
    'sports' ||
    'fitness_center' ||
    'sports_soccer' => Icons.fitness_center_outlined,
    'school' || 'edit_note' || 'menu_book' || 'redeem' => Icons.school_outlined,
    'checkroom' || 'steps' || 'diamond' => Icons.checkroom_outlined,
    'content_cut' ||
    'spa' ||
    'face' ||
    'local_laundry_service' => Icons.spa_outlined,
    'devices' ||
    'devices_other' ||
    'smartphone' ||
    'computer' => Icons.devices_outlined,
    'directions_car' ||
    'car_repair' ||
    'settings' ||
    'directions_bus' ||
    'local_car_wash' => Icons.directions_car_outlined,
    'construction' ||
    'hardware' ||
    'foundation' ||
    'chair' ||
    'home_repair_service' ||
    'handyman' => Icons.handyman_outlined,
    'agriculture' => Icons.agriculture_outlined,
    'pets' || 'cruelty_free' => Icons.pets_outlined,
    'attractions' ||
    'theaters' ||
    'travel_explore' => Icons.attractions_outlined,
    'account_balance' => Icons.account_balance_outlined,
    'design_services' ||
    'photo_camera' ||
    'cleaning_services' ||
    'miscellaneous_services' => Icons.miscellaneous_services_outlined,
    'local_florist' => Icons.local_florist_outlined,
    'category' || '' => Icons.category_outlined,
    _ => Icons.storefront_outlined,
  };
}

class _EstadoPreferencias extends StatelessWidget {
  const _EstadoPreferencias({
    required this.cambios,
    required this.pendiente,
    required this.guardando,
    required this.conflicto,
    required this.error,
    required this.alCargarServidor,
  });

  final bool cambios, pendiente, guardando, conflicto;
  final String? error;
  final VoidCallback? alCargarServidor;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final Color color;
    final IconData icon;
    final String message;
    if (conflicto) {
      color = sky.error;
      icon = Icons.sync_problem_rounded;
      message = error ?? 'Hay cambios en conflicto.';
    } else if (error != null) {
      color = sky.error;
      icon = Icons.cloud_off_outlined;
      message = error!;
    } else if (guardando) {
      color = sky.primary;
      icon = Icons.sync_rounded;
      message = 'Guardando tus preferencias…';
    } else if (pendiente) {
      color = sky.warning;
      icon = Icons.cloud_upload_outlined;
      message = 'Guardadas en este dispositivo · pendientes de sincronizar';
    } else if (cambios) {
      color = sky.primary;
      icon = Icons.edit_note_rounded;
      message = 'Tienes cambios sin guardar';
    } else {
      color = sky.success;
      icon = Icons.cloud_done_outlined;
      message = 'Tus preferencias están guardadas';
    }

    return Container(
      key: const Key('estado-preferencias'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (conflicto && alCargarServidor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: alCargarServidor,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Usar versión del servidor'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoriaPreferenciaChip extends StatelessWidget {
  const _CategoriaPreferenciaChip({
    required this.categoria,
    required this.selected,
    required this.enabled,
    required this.icono,
    required this.onSelected,
  });

  final CategoriaModel categoria;
  final bool selected, enabled;
  final IconData icono;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return FilterChip(
      key: ValueKey('preferencia-categoria-${categoria.id}'),
      avatar: Icon(
        icono,
        size: 18,
        color: selected ? sky.onPrimary : sky.interactive,
      ),
      label: Text(
        categoria.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: sky.onPrimary,
      selectedColor: sky.primary,
      backgroundColor: sky.soft,
      side: BorderSide(color: selected ? sky.primary : sky.border),
      labelStyle: TextStyle(
        color: selected ? sky.onPrimary : sky.text,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.standard,
      onSelected: enabled ? onSelected : null,
    );
  }
}

class _RadioPreferenciaChip extends StatelessWidget {
  const _RadioPreferenciaChip({
    required this.radio,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final int? radio;
  final bool selected, enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final label = radio == null ? 'Sin límite' : '${radio! ~/ 1000} km';
    return ChoiceChip(
      key: ValueKey('preferencia-radio-${radio ?? 'sin-limite'}'),
      avatar: selected
          ? Icon(Icons.check_rounded, size: 17, color: sky.onPrimary)
          : null,
      label: Text(label),
      selected: selected,
      selectedColor: sky.primary,
      backgroundColor: sky.soft,
      side: BorderSide(color: selected ? sky.primary : sky.border),
      labelStyle: TextStyle(
        color: selected ? sky.onPrimary : sky.text,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      onSelected: enabled ? (_) => onSelected() : null,
    );
  }
}

class _PromocionesPreferenciaCard extends StatelessWidget {
  const _PromocionesPreferenciaCard({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final bool selected, enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sky.headerStart, sky.headerMiddle],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: sky.accent.withValues(alpha: .38)),
        boxShadow: [
          BoxShadow(
            color: sky.primary.withValues(alpha: .12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(17, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.local_offer_rounded, color: sky.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priorizar promociones',
                  style: TextStyle(
                    color: sky.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Destacaremos lugares con promociones vigentes.',
                  style: TextStyle(
                    color: sky.onPrimary.withValues(alpha: .82),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Switch.adaptive(
            key: const Key('preferir-promociones'),
            value: selected,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: sky.accent,
          ),
        ],
      ),
    );
  }
}

class _AccionesPreferencias extends StatelessWidget {
  const _AccionesPreferencias({
    required this.guardando,
    required this.onGuardar,
    required this.onRestablecer,
  });

  final bool guardando;
  final VoidCallback onGuardar, onRestablecer;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      decoration: BoxDecoration(
        color: sky.surface,
        border: Border(top: BorderSide(color: sky.border)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                key: const Key('guardar-preferencias'),
                onPressed: guardando ? null : onGuardar,
                icon: guardando
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  guardando ? 'Guardando…' : 'Guardar preferencias',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('restablecer-preferencias'),
              onPressed: guardando ? null : onRestablecer,
              icon: const Icon(Icons.restart_alt_rounded, size: 19),
              label: const Text('Restablecer valores predeterminados'),
              style: TextButton.styleFrom(
                foregroundColor: sky.muted,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
