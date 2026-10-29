import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sky/sky_theme.dart';
import '../../../sky/sky_backdrop.dart';

import '../../establecimientos/models/establecimiento_publico_model.dart';
import '../controllers/explorar_controller.dart';
import '../models/ubicacion_usuario.dart';
import '../widgets/cabecera_explorar.dart';
import '../widgets/estado_ubicacion_card.dart';
import '../widgets/filtros_explorar.dart';
import '../widgets/promociones_explorar.dart';
import '../widgets/tarjeta_establecimiento_publico.dart';
import 'detalle_establecimiento_screen.dart';

typedef CrearDetalleEstablecimiento = Widget Function(
  BuildContext context,
  EstablecimientoPublicoModel establecimiento,
);

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({
    required this.controller,
    this.onPerfil,
    this.cargarPromociones,
    this.crearDetalle,
    super.key,
  });

  final ExplorarController controller;
  final VoidCallback? onPerfil;
  final CargarPromocionesExplorar? cargarPromociones;
  final CrearDetalleEstablecimiento? crearDetalle;

  void _abrirDetalle(
    BuildContext context,
    EstablecimientoPublicoModel establecimiento,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) =>
            crearDetalle?.call(routeContext, establecimiento) ??
            DetalleEstablecimientoScreen(establecimiento: establecimiento),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ubicacion = controller.ubicacion;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: sky.headerStart,
            systemNavigationBarColor: sky.surface,
            systemNavigationBarIconBrightness:
                sky.environment == SkyEnvironment.noche
                ? Brightness.light
                : Brightness.dark,
          ),
          child: SkySurface(
            intensity: 1,
            child: RefreshIndicator(
              onRefresh: controller.buscar,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: CabeceraExplorar(
                      onPerfil: onPerfil,
                      buscador: _BuscadorEstablecimientos(
                        controller: controller,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.estadoUbicacion !=
                              EstadoUbicacion.disponible) ...[
                            EstadoUbicacionCard(controller: controller),
                            const SizedBox(height: 12),
                          ],
                          FiltrosExplorar(controller: controller),
                          if (controller.recomendados.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_outlined,
                                  color: sky.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recomendados para ti',
                                  style: TextStyle(
                                    color: sky.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (final item in controller.recomendados)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TarjetaEstablecimientoPublico(
                                  establecimiento: item,
                                  onTap: () => _abrirDetalle(context, item),
                                ),
                              ),
                          ],
                          if (controller.estadoUbicacion ==
                                  EstadoUbicacion.disponible &&
                              !controller.cargandoResultados &&
                              controller.errorResultados == null)
                            PromocionesExplorar(
                              establecimientos: controller.establecimientos,
                              cargarPromociones: cargarPromociones,
                              latitudUsuario: ubicacion?.latitud,
                              longitudUsuario: ubicacion?.longitud,
                              radioMaximoMetros: controller.radioMetros
                                  .toDouble(),
                              onEstablecimiento: (establecimiento) =>
                                  _abrirDetalle(context, establecimiento),
                              onVerTodas: () =>
                                  controller.cambiarSoloPromociones(true),
                            ),
                          const SizedBox(height: 14),
                          _EncabezadoResultados(controller: controller),
                        ],
                      ),
                    ),
                  ),
                  ..._contenido(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _contenido(BuildContext context) {
    final recomendadosIds = controller.recomendados
        .map((item) => item.id)
        .toSet();
    final establecimientosVisibles = controller.establecimientos
        .where((item) => !recomendadosIds.contains(item.id))
        .toList(growable: false);

    if (controller.cargandoResultados && controller.establecimientos.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            key: Key('estado-loading'),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    if (controller.errorResultados != null &&
        controller.establecimientos.isEmpty &&
        controller.recomendados.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MensajeCentral(
            key: const Key('estado-error'),
            icono: Icons.cloud_off_outlined,
            titulo: 'No pudimos cargar los lugares',
            descripcion: controller.errorResultados!,
            accion: FilledButton.icon(
              onPressed: controller.buscar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ),
      ];
    }

    if (establecimientosVisibles.isEmpty &&
        controller.recomendados.isNotEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              children: [
                const Text(
                  'Estas son tus recomendaciones. Puedes cambiar los filtros para explorar más lugares.',
                ),
                if (controller.hayMasResultados)
                  TextButton.icon(
                    key: const Key('cargar-mas-sin-duplicados'),
                    onPressed: controller.cargandoResultados
                        ? null
                        : controller.cargarMas,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Cargar más establecimientos'),
                  ),
              ],
            ),
          ),
        ),
      ];
    }

    if (establecimientosVisibles.isEmpty) {
      final tieneBusqueda = controller.busqueda.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MensajeCentral(
            key: const Key('estado-sin-resultados'),
            icono: Icons.search_off,
            titulo: tieneBusqueda
                ? 'No encontramos coincidencias'
                : 'No encontramos establecimientos',
            descripcion: tieneBusqueda
                ? 'Prueba con otro nombre, categoría o subcategoría.'
                : 'Prueba con otro radio o cambia los filtros.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        sliver: SliverList.builder(
          itemCount:
              establecimientosVisibles.length +
              (controller.hayMasResultados ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == establecimientosVisibles.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  key: const Key('cargar-mas'),
                  onPressed: controller.cargandoResultados
                      ? null
                      : controller.cargarMas,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Cargar más'),
                ),
              );
            }

            final establecimiento = establecimientosVisibles[index];
            return TarjetaEstablecimientoPublico(
              establecimiento: establecimiento,
              onTap: () => _abrirDetalle(context, establecimiento),
            );
          },
        ),
      ),
    ];
  }
}

class _EncabezadoResultados extends StatelessWidget {
  const _EncabezadoResultados({required this.controller});

  final ExplorarController controller;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    final titulo = controller.busqueda.trim().isEmpty
        ? (controller.ubicacion == null ? 'Establecimientos' : 'Cerca de ti')
        : 'Resultados de búsqueda';

    return Row(
      children: [
        Icon(Icons.location_on_rounded, color: sky.primary, size: 23),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sky.text,
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -.3,
            ),
          ),
        ),
        if (!controller.cargandoResultados && controller.ubicacion != null)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${controller.establecimientos.length} lugares mostrados',
                    style: TextStyle(
                      color: sky.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (controller.busqueda.trim().isEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.tune_rounded, size: 15, color: sky.muted),
                    const SizedBox(width: 3),
                    Text(
                      'Más cercanos',
                      style: TextStyle(
                        color: sky.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BuscadorEstablecimientos extends StatefulWidget {
  const _BuscadorEstablecimientos({required this.controller});

  final ExplorarController controller;

  @override
  State<_BuscadorEstablecimientos> createState() =>
      _BuscadorEstablecimientosState();
}

class _BuscadorEstablecimientosState extends State<_BuscadorEstablecimientos> {
  late final TextEditingController _textoController;

  @override
  void initState() {
    super.initState();
    _textoController = TextEditingController(text: widget.controller.busqueda);
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  void _limpiar() {
    _textoController.clear();
    widget.controller.limpiarBusqueda();
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return SizedBox(
      height: 51,
      child: TextField(
        key: const Key('buscador-establecimientos'),
        controller: _textoController,
        textInputAction: TextInputAction.search,
        onChanged: widget.controller.cambiarBusqueda,
        onSubmitted: (_) => widget.controller.buscar(),
        style: TextStyle(
          color: sky.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar lugares cerca de ti',
          hintStyle: TextStyle(color: sky.muted, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded, color: sky.muted, size: 23),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textoController,
            builder: (context, valor, _) {
              if (valor.text.isEmpty) {
                return Icon(Icons.tune_rounded, color: sky.primary, size: 21);
              }
              return IconButton(
                key: const Key('limpiar-busqueda'),
                tooltip: 'Limpiar búsqueda',
                onPressed: _limpiar,
                icon: const Icon(Icons.close_rounded),
              );
            },
          ),
          filled: true,
          fillColor: sky.inputFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: sky.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: sky.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _MensajeCentral extends StatelessWidget {
  const _MensajeCentral({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.accion,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sky.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sky.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 58, color: sky.muted),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                descripcion,
                textAlign: TextAlign.center,
                style: TextStyle(color: sky.muted),
              ),
              if (accion != null) ...[const SizedBox(height: 18), accion!],
            ],
          ),
        ),
      ),
    );
  }
}
