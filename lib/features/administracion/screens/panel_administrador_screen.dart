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
  static const _azul = Color(0xFF2468F2);
  static const _azulOscuro = Color(0xFF102A56);
  static const _fondo = Color(0xFFF5F8FE);
  static const _borde = Color(0xFFE2E9F5);

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

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          esAprobacion ? 'Aprobar establecimiento' : 'Rechazar establecimiento',
        ),
        content: Text(
          'Â¿Deseas ${esAprobacion ? 'aprobar' : 'rechazar'} '
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
              backgroundColor: esAprobacion ? _azul : const Color(0xFFE5484D),
            ),
            child: Text(esAprobacion ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
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
        return const Color(0xFF168A54);
      case 'rechazado':
        return const Color(0xFFE5484D);
      default:
        return const Color(0xFFE99908);
    }
  }

  Color _fondoEstado(String estado) {
    switch (estado) {
      case 'aprobado':
        return const Color(0xFFE9F7F0);
      case 'rechazado':
        return const Color(0xFFFFEEEE);
      default:
        return const Color(0xFFFFF5D9);
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

  void _mostrarDetalles(EstablecimientoModel establecimiento) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
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
                const SizedBox(height: 22),
                Text(
                  establecimiento.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _azulOscuro,
                  ),
                ),
                const SizedBox(height: 18),
                _Detalle(
                  etiqueta: 'DescripciÃ³n',
                  valor: establecimiento.descripcion.isEmpty
                      ? 'Sin descripciÃ³n'
                      : establecimiento.descripcion,
                ),
                _Detalle(
                  etiqueta: 'DirecciÃ³n',
                  valor: establecimiento.direccion,
                ),
                _Detalle(
                  etiqueta: 'TelÃ©fono',
                  valor: establecimiento.telefonoPublico.isEmpty
                      ? 'Sin telÃ©fono'
                      : establecimiento.telefonoPublico,
                ),
                _Detalle(
                  etiqueta: 'CategorÃ­a',
                  valor: establecimiento.categoriaId,
                ),
                _Detalle(
                  etiqueta: 'UbicaciÃ³n',
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }

  Widget _accionCabecera({
    required IconData icono,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        elevation: 0,
        shadowColor: const Color(0x1A0A2A66),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE4EAF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0A2A66),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icono, size: 18, color: _azulOscuro),
          ),
        ),
      ),
    );
  }

  Widget _marcaCercly() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, color: _azul, size: 43),
        SizedBox(width: 2),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cercly',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 31,
                height: 0.95,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Descubre lo que te rodea',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cabecera(String correo) {
    return SizedBox(
      height: 323,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 175,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8EC7FF),
                    Color(0xFF3F7FE8),
                    Color(0xFF174FAD),
                    Color(0xFF0A2A66),
                  ],
                  stops: [0, 0.33, 0.7, 1],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _StarPainter()),
                  ),
                  Positioned(
                    left: -42,
                    top: -30,
                    child: Container(
                      width: 220,
                      height: 150,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _marcaCercly()),
                          const SizedBox(width: 12),
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Ciudades más\ncercanas, historias\nmás grandes',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.2,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 156,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 21, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x140A2A66),
                    blurRadius: 18,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Panel administrativo',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _azulOscuro,
                                  height: 1.05,
                                  letterSpacing: -0.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Gestión de establecimientos y solicitudes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.2,
                                color: _azulOscuro.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _accionCabecera(
                        icono: Icons.assignment_outlined,
                        tooltip: 'Solicitudes',
                        onPressed: _abrirSolicitudes,
                      ),
                      const SizedBox(width: 8),
                      _accionCabecera(
                        icono: Icons.refresh_rounded,
                        tooltip: 'Actualizar',
                        onPressed: _recargar,
                      ),
                      const SizedBox(width: 8),
                      _accionCabecera(
                        icono: Icons.logout_rounded,
                        tooltip: 'Cerrar sesiÃ³n',
                        onPressed: _cerrarSesion,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Container(
                    width: double.infinity,
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFDFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7EDF7)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x100A2A66),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: _azul,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Administrador de Cercly',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _azulOscuro,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                correo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7D9B),
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 112),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: _azul,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Administrador',
                                  style: TextStyle(
                                    color: _azul,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
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
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: seleccionado ? _azul : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: seleccionado ? _azul : _borde),
              boxShadow: seleccionado
                  ? [
                      BoxShadow(
                        color: _azul.withValues(alpha: 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
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
                    color: seleccionado ? Colors.white : _azulOscuro,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    texto,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : _azulOscuro,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? Colors.white
                          : const Color(0xFFF0F5FD),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$cantidad',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _azul,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
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
        opcion('pendiente', 'Pendientes', Icons.schedule_rounded),
        const SizedBox(width: 8),
        opcion('aprobado', 'Aprobados', Icons.check_circle_outline_rounded),
        const SizedBox(width: 8),
        opcion('rechazado', 'Rechazados', Icons.cancel_outlined),
      ],
    );
  }

  Widget _buscador() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(17)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D102A56),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _busquedaController,
        onChanged: (valor) => setState(() => _busqueda = valor.trim()),
        decoration: InputDecoration(
          hintText: 'Buscar establecimiento...',
          hintStyle: const TextStyle(color: Color(0xFF8091AC)),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: _borde),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: _borde),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: const BorderSide(color: _azul, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _accionesTarjeta(EstablecimientoModel establecimiento) {
    if (_establecimientoProcesando == establecimiento.id) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (establecimiento.estado == 'pendiente') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cambiarEstado(establecimiento, 'rechazado'),
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Rechazar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE5484D),
                side: const BorderSide(color: Color(0xFFFFB9BB)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _cambiarEstado(establecimiento, 'aprobado'),
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Aprobar'),
              style: FilledButton.styleFrom(
                backgroundColor: _azul,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final volverAprobado = establecimiento.estado == 'rechazado';
    return SizedBox(
      width: double.infinity,
      child: volverAprobado
          ? FilledButton.icon(
              onPressed: () => _cambiarEstado(establecimiento, 'aprobado'),
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Cambiar a aprobado'),
              style: FilledButton.styleFrom(backgroundColor: _azul),
            )
          : OutlinedButton.icon(
              onPressed: () => _cambiarEstado(establecimiento, 'rechazado'),
              icon: const Icon(Icons.block_rounded, size: 17),
              label: const Text('Cambiar a rechazado'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE5484D),
              ),
            ),
    );
  }

  Widget _tarjetaEstablecimiento(EstablecimientoModel establecimiento) {
    final color = _colorEstado(establecimiento.estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _borde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A102A56),
            blurRadius: 16,
            offset: Offset(0, 6),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _azul,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      establecimiento.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _azulOscuro,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF60779C),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            establecimiento.direccion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF60779C),
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _fondoEstado(establecimiento.estado),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconoEstado(establecimiento.estado),
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _nombreEstado(establecimiento.estado),
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            establecimiento.descripcion.isEmpty
                ? 'Sin descripciÃ³n disponible.'
                : establecimiento.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5D708F),
              height: 1.35,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _mostrarDetalles(establecimiento),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            label: const Text('Ver detalles'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 8),
          _accionesTarjeta(establecimiento),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
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
                      final coincideBusqueda =
                          consulta.isEmpty ||
                          establecimiento.nombre.toLowerCase().contains(
                            consulta,
                          ) ||
                          establecimiento.direccion.toLowerCase().contains(
                            consulta,
                          );
                      return coincideEstado && coincideBusqueda;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _selectorEstado(todos),
                        const SizedBox(height: 15),
                        _buscador(),
                        const SizedBox(height: 15),
                        Text(
                          '${establecimientos.length} ${establecimientos.length == 1 ? 'establecimiento' : 'establecimientos'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _azulOscuro,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 7),
                        if (establecimientos.isEmpty)
                          _MensajePanel(
                            icono: _busqueda.isEmpty
                                ? _iconoEstado(_estadoSeleccionado)
                                : Icons.search_off_rounded,
                            mensaje: _busqueda.isEmpty
                                ? 'No hay establecimientos ${_nombreEstado(_estadoSeleccionado).toLowerCase()}s.'
                                : 'No encontramos resultados para â€œ$_busquedaâ€.',
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
    final resplandor = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.62, size.height * 0.36),
          radius: 74,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.36),
      74,
      resplandor,
    );

    final random = math.Random(27);
    final paint = Paint();

    for (var i = 0; i < 28; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.82;
      final intensidad = 0.25 + random.nextDouble() * 0.5;
      final radio = 0.45 + random.nextDouble() * 1.05;
      paint.color = Colors.white.withValues(alpha: intensidad);
      canvas.drawCircle(Offset(x, y), radio, paint);
    }

    final brillo = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = 1;

    for (final punto in [
      Offset(size.width * 0.46, 36),
      Offset(size.width * 0.62, 72),
      Offset(size.width * 0.84, 30),
    ]) {
      canvas.drawLine(
        Offset(punto.dx - 4, punto.dy),
        Offset(punto.dx + 4, punto.dy),
        brillo,
      );
      canvas.drawLine(
        Offset(punto.dx, punto.dy - 4),
        Offset(punto.dx, punto.dy + 4),
        brillo,
      );
    }

    final halo = Path()
      ..moveTo(size.width * 0.55, size.height * 0.54)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.28,
        size.width * 0.86,
        size.height * 0.38,
      );
    canvas.drawPath(
      halo,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round,
    );
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 29, color: const Color(0xFF2468F2)),
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
