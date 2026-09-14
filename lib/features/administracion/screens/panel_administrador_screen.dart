import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../establecimientos/models/establecimiento_model.dart';
import '../../establecimientos/services/establecimiento_service.dart';
import '../../solicitudes_establecimientos/screens/solicitudes_administrador_screen.dart';

class PanelAdministradorScreen extends StatefulWidget {
  const PanelAdministradorScreen({super.key});

  @override
  State<PanelAdministradorScreen> createState() =>
      _PanelAdministradorScreenState();
}

class _PanelAdministradorScreenState extends State<PanelAdministradorScreen> {
  static const _azul = Color(0xFF1769FF);
  static const _azulOscuro = Color(0xFF0E2C63);
  static const _fondo = Color(0xFFF6F9FF);

  final EstablecimientoService _service = EstablecimientoService();
  final TextEditingController _busquedaController = TextEditingController();

  late Future<List<EstablecimientoModel>> _establecimientosFuture;

  String _estadoSeleccionado = 'pendiente';
  String _busqueda = '';
  String? _establecimientoProcesando;

  @override
  void initState() {
    super.initState();
    _cargarEstablecimientos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _cargarEstablecimientos() {
    _establecimientosFuture = _service.listarTodosLosEstablecimientos();
  }

  Future<void> _recargar() async {
    setState(_cargarEstablecimientos);
    await _establecimientosFuture;
  }

  Future<void> _cerrarSesion() async {
    await AuthService().signOut();
  }

  Future<void> _abrirSolicitudes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SolicitudesAdministradorScreen(),
      ),
    );

    if (mounted) {
      await _recargar();
    }
  }

  Future<void> _cambiarEstado(
    EstablecimientoModel establecimiento,
    String nuevoEstado,
  ) async {
    final esAprobacion = nuevoEstado == 'aprobado';
    final accion = esAprobacion ? 'aprobar' : 'rechazar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            esAprobacion
                ? 'Aprobar establecimiento'
                : 'Rechazar establecimiento',
          ),
          content: Text(
            '¿Deseas $accion el establecimiento '
            '"${establecimiento.nombre}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: esAprobacion ? _azul : const Color(0xFFE84C4C),
              ),
              child: Text(esAprobacion ? 'Aprobar' : 'Rechazar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() => _establecimientoProcesando = establecimiento.id);

    try {
      await _service.cambiarEstado(
        establecimientoId: establecimiento.id,
        nuevoEstado: nuevoEstado,
      );

      if (!mounted) return;

      setState(() {
        _establecimientoProcesando = null;
        _cargarEstablecimientos();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esAprobacion
                ? 'Establecimiento aprobado correctamente.'
                : 'Establecimiento rechazado correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _establecimientoProcesando = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarDetalles(EstablecimientoModel establecimiento) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9E2F3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 30,
                          color: _azul,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          establecimiento.nombre,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _azulOscuro,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Detalle(
                    etiqueta: 'Descripción',
                    valor: establecimiento.descripcion.isEmpty
                        ? 'Sin descripción'
                        : establecimiento.descripcion,
                  ),
                  _Detalle(
                    etiqueta: 'Dirección',
                    valor: establecimiento.direccion,
                  ),
                  _Detalle(
                    etiqueta: 'Teléfono',
                    valor: establecimiento.telefonoPublico.isEmpty
                        ? 'Sin teléfono'
                        : establecimiento.telefonoPublico,
                  ),
                  _Detalle(
                    etiqueta: 'Categoría',
                    valor: establecimiento.categoriaId,
                  ),
                  _Detalle(
                    etiqueta: 'Ubicación',
                    valor:
                        '${establecimiento.latitud}, ${establecimiento.longitud}',
                  ),
                  _Detalle(
                    etiqueta: 'Zona horaria',
                    valor: establecimiento.zonaHoraria,
                  ),
                  _Detalle(
                    etiqueta: 'Estado',
                    valor: _nombreEstado(establecimiento.estado),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _azul,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _nombreEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return const Color(0xFF20A464);
      case 'rechazado':
        return const Color(0xFFE84C4C);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color _fondoEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return const Color(0xFFE9F8F0);
      case 'rechazado':
        return const Color(0xFFFFEEEE);
      default:
        return const Color(0xFFFFF6DD);
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return Icons.check_circle_outline_rounded;
      case 'rechazado':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  Widget _construirAcciones(EstablecimientoModel establecimiento) {
    if (_establecimientoProcesando == establecimiento.id) {
      return const SizedBox(
        height: 44,
        width: 44,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (establecimiento.estado == 'pendiente') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _cambiarEstado(establecimiento, 'rechazado'),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE84C4C),
              side: const BorderSide(color: Color(0xFFFFB7B7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _cambiarEstado(establecimiento, 'aprobado'),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Aprobar'),
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      );
    }

    if (establecimiento.estado == 'aprobado') {
      return OutlinedButton.icon(
        onPressed: () => _cambiarEstado(establecimiento, 'rechazado'),
        icon: const Icon(Icons.block_rounded, size: 18),
        label: const Text('Cambiar a rechazado'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE84C4C),
          side: const BorderSide(color: Color(0xFFFFB7B7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () => _cambiarEstado(establecimiento, 'aprobado'),
      icon: const Icon(Icons.check_rounded, size: 18),
      label: const Text('Cambiar a aprobado'),
      style: FilledButton.styleFrom(
        backgroundColor: _azul,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _botonCabecera({
    required IconData icono,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icono, color: _azulOscuro),
          ),
        ),
      ),
    );
  }

  Widget _cabecera(String correo) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5FF), Color(0xFFBFD8FF), Color(0xFF174A9A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _StarPainter()),
          Positioned(
            right: -36,
            top: 26,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _azul,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _azul.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cercly',
                              style: TextStyle(
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                                color: _azulOscuro,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'Descubre lo que te rodea',
                              style: TextStyle(
                                color: Color(0xFF52698F),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _botonCabecera(
                        icono: Icons.assignment_outlined,
                        tooltip: 'Solicitudes',
                        onPressed: _abrirSolicitudes,
                      ),
                      const SizedBox(width: 8),
                      _botonCabecera(
                        icono: Icons.refresh_rounded,
                        tooltip: 'Actualizar',
                        onPressed: _recargar,
                      ),
                      const SizedBox(width: 8),
                      _botonCabecera(
                        icono: Icons.logout_rounded,
                        tooltip: 'Cerrar sesión',
                        onPressed: _cerrarSesion,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Panel administrativo',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: _azulOscuro,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gestión de establecimientos y solicitudes',
                    style: TextStyle(
                      fontSize: 15,
                      color: _azulOscuro.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFDDEAFF),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            color: _azul,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Administrador de Cercly',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _azulOscuro,
                                ),
                              ),
                              Text(
                                correo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7D9B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                                color: _azul,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Administrador',
                                style: TextStyle(
                                  color: _azul,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorEstado(List<EstablecimientoModel> todos) {
    int contar(String estado) => todos.where((e) => e.estado == estado).length;

    Widget opcion(String estado, String texto, IconData icono) {
      final seleccionado = _estadoSeleccionado == estado;
      final cantidad = contar(estado);

      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _estadoSeleccionado = estado),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: seleccionado ? _azul : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: seleccionado
                    ? _azul
                    : const Color(0xFFDCE5F3),
              ),
              boxShadow: seleccionado
                  ? [
                      BoxShadow(
                        color: _azul.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  size: 18,
                  color: seleccionado ? Colors.white : _azulOscuro,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    texto,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : _azulOscuro,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: seleccionado
                        ? Colors.white
                        : const Color(0xFFF0F5FD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$cantidad',
                    style: TextStyle(
                      color: _azul,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        opcion('pendiente', 'Pendientes', Icons.schedule_rounded),
        const SizedBox(width: 8),
        opcion('aprobado', 'Aprobados', Icons.check_circle_outline_rounded),
        const SizedBox(width: 8),
        opcion('rechazado', 'Rechazados', Icons.cancel_outlined),
      ],
    );
  }

  Widget _buscador() {
    return TextField(
      controller: _busquedaController,
      onChanged: (valor) => setState(() => _busqueda = valor.trim()),
      decoration: InputDecoration(
        hintText: 'Buscar establecimiento...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _busqueda.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _busquedaController.clear();
                  setState(() => _busqueda = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE5F3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE5F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _azul, width: 1.5),
        ),
      ),
    );
  }

  Widget _tarjetaEstablecimiento(EstablecimientoModel establecimiento) {
    final color = _colorEstado(establecimiento.estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F2B5B),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _azul,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          establecimiento.nombre,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _azulOscuro,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _fondoEstado(establecimiento.estado),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconoEstado(establecimiento.estado),
                                size: 15,
                                color: color,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _nombreEstado(establecimiento.estado),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Color(0xFF60779C),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            establecimiento.direccion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF60779C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            establecimiento.descripcion.isEmpty
                ? 'Sin descripción disponible.'
                : establecimiento.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF566B8C),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEDF1F7)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _mostrarDetalles(establecimiento),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver detalles'),
              ),
              const Spacer(),
              Flexible(child: _construirAcciones(establecimiento)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final correo = AuthService().currentUser?.email ?? 'Sin correo';

    return Scaffold(
      backgroundColor: _fondo,
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _cabecera(correo)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<List<EstablecimientoModel>>(
                  future: _establecimientosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 70),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return _MensajePanel(
                        icono: Icons.error_outline_rounded,
                        mensaje:
                            'No se pudieron cargar los establecimientos.\n${snapshot.error}',
                        boton: 'Reintentar',
                        onPressed: _recargar,
                      );
                    }

                    final todos = snapshot.data ?? <EstablecimientoModel>[];
                    final consulta = _busqueda.toLowerCase();
                    final establecimientos = todos.where((establecimiento) {
                      final coincideEstado =
                          establecimiento.estado == _estadoSeleccionado;
                      final coincideBusqueda = consulta.isEmpty ||
                          establecimiento.nombre.toLowerCase().contains(consulta) ||
                          establecimiento.direccion
                              .toLowerCase()
                              .contains(consulta);

                      return coincideEstado && coincideBusqueda;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _selectorEstado(todos),
                        const SizedBox(height: 16),
                        _buscador(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              '${establecimientos.length} ${establecimientos.length == 1 ? 'establecimiento' : 'establecimientos'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _azulOscuro,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _abrirSolicitudes,
                              icon: const Icon(Icons.assignment_outlined),
                              label: const Text('Ver solicitudes'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (establecimientos.isEmpty)
                          _MensajePanel(
                            icono: _busqueda.isEmpty
                                ? _iconoEstado(_estadoSeleccionado)
                                : Icons.search_off_rounded,
                            mensaje: _busqueda.isEmpty
                                ? 'No hay establecimientos ${_nombreEstado(_estadoSeleccionado).toLowerCase()}s.'
                                : 'No encontramos resultados para “$_busqueda”.',
                          )
                        else
                          ...establecimientos.map(_tarjetaEstablecimiento),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(27);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.68);

    for (var i = 0; i < 32; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.72;
      final radio = 0.7 + random.nextDouble() * 1.4;
      canvas.drawCircle(Offset(x, y), radio, paint);
    }

    final brillo = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..strokeWidth = 1.2;

    for (final punto in [
      Offset(size.width * 0.55, 34),
      Offset(size.width * 0.72, 78),
      Offset(size.width * 0.38, 106),
    ]) {
      canvas.drawLine(
        Offset(punto.dx - 5, punto.dy),
        Offset(punto.dx + 5, punto.dy),
        brillo,
      );
      canvas.drawLine(
        Offset(punto.dx, punto.dy - 5),
        Offset(punto.dx, punto.dy + 5),
        brillo,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF173765),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(color: Color(0xFF566B8C))),
        ],
      ),
    );
  }
}

class _MensajePanel extends StatelessWidget {
  const _MensajePanel({
    required this.icono,
    required this.mensaje,
    this.boton,
    this.onPressed,
  });

  final IconData icono;
  final String mensaje;
  final String? boton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 30, color: const Color(0xFF1769FF)),
          ),
          const SizedBox(height: 14),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF566B8C), height: 1.4),
          ),
          if (boton != null && onPressed != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(boton!)),
          ],
        ],
      ),
    );
  }
}
