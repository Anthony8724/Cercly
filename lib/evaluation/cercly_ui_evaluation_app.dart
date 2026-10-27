import 'dart:async';

import 'package:flutter/material.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/mi_cuenta_screen.dart';
import '../features/auth/screens/password_screen.dart';
import '../features/auth/screens/seleccion_tipo_cuenta_screen.dart';
import '../features/auth/services/auth_options.dart';
import '../features/auth/services/auth_service.dart';
import '../features/categorias/models/categoria_model.dart';
import '../features/categorias/models/subcategoria_model.dart';
import '../features/categorias/services/categoria_publica_service.dart';
import '../features/establecimientos/models/establecimiento_model.dart';
import '../features/establecimientos/models/establecimiento_publico_model.dart';
import '../features/establecimientos/models/turno_horario.dart';
import '../features/establecimientos/screens/mis_negocios_screen.dart';
import '../features/establecimientos/screens/registro_establecimiento_screen.dart';
import '../features/establecimientos/services/establecimiento_publico_service.dart';
import '../features/establecimientos/services/establecimiento_service.dart';
import '../features/explorar/controllers/explorar_controller.dart';
import '../features/explorar/models/ubicacion_usuario.dart';
import '../features/explorar/screens/detalle_establecimiento_screen.dart';
import '../features/explorar/screens/navegacion_principal_screen.dart';
import '../features/explorar/services/mapas_externos_service.dart';
import '../features/explorar/services/ubicacion_service.dart';
import '../features/promociones/models/promocion_destacada_model.dart';
import '../sky/sky_controller.dart';
import '../sky/sky_theme.dart';

const _centroTulcan = UbicacionUsuario(latitud: 0.8119, longitud: -77.7173);

class CerclyUiEvaluationApp extends StatefulWidget {
  const CerclyUiEvaluationApp({
    super.key,
    this.skyController,
    this.mostrarTilesMapa = true,
  });

  final SkyController? skyController;
  final bool mostrarTilesMapa;
  @override
  State<CerclyUiEvaluationApp> createState() => _CerclyUiEvaluationAppState();
}

class _CerclyUiEvaluationAppState extends State<CerclyUiEvaluationApp> {
  late final SkyController _sky = widget.skyController ?? SkyController();
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    unawaited(_sky.start());
  }

  @override
  void dispose() {
    if (widget.skyController == null) _sky.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _sky,
    builder: (context, _) => SkyScope(
      controller: _sky,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cercly · Demo local',
        theme: skyTheme(_sky.palette),
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: _reducedMotion),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF173769),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: const Text(
                    'DEMO LOCAL · DATOS FICTICIOS · SIN SUPABASE · SIN ESCRITURAS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
        home: _EvaluationNavigation(
          mostrarTilesMapa: widget.mostrarTilesMapa,
          reducedMotion: _reducedMotion,
          onReducedMotionChanged: (value) =>
              setState(() => _reducedMotion = value),
        ),
      ),
    ),
  );
}

class _EvaluationNavigation extends StatefulWidget {
  const _EvaluationNavigation({
    required this.mostrarTilesMapa,
    required this.reducedMotion,
    required this.onReducedMotionChanged,
  });

  final bool mostrarTilesMapa;
  final bool reducedMotion;
  final ValueChanged<bool> onReducedMotionChanged;

  @override
  State<_EvaluationNavigation> createState() => _EvaluationNavigationState();
}

class _EvaluationNavigationState extends State<_EvaluationNavigation> {
  late final ExplorarController _controller = ExplorarController(
    establecimientoService: _DemoEstablishmentRepository(),
    categoriaService: _DemoCategoryRepository(),
    ubicacionService: const _DemoLocationService(),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.inicializar());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NavegacionPrincipalScreen(
    controller: _controller,
    inicializarController: false,
    mostrarTilesMapa: widget.mostrarTilesMapa,
    terceraOpcionLabel: 'Cuenta',
    terceraOpcionIcon: Icons.person_outline_rounded,
    terceraOpcionSelectedIcon: Icons.person_rounded,
    cargarPromociones: _cargarPromocionesDemo,
    crearDetalle: _crearDetalleDemo,
    terceraOpcionBuilder: (_) => _EvaluationHub(
      sky: SkyScope.maybeOf(context),
      reducedMotion: widget.reducedMotion,
      onReducedMotionChanged: widget.onReducedMotionChanged,
      refrescarExplorar: () => unawaited(_controller.buscar()),
    ),
  );
}

Widget _crearDetalleDemo(
  BuildContext context,
  EstablecimientoPublicoModel establecimiento,
) => DetalleEstablecimientoScreen(
  establecimiento: establecimiento,
  cargarHorario: (_) async => {
    for (final dia in EstablecimientoModel.diasSemana) dia: <TurnoHorario>[],
  },
  estaAutenticado: () => false,
  mapasService: MapasExternosService(),
  crearPantallaAcceso: () => _loginDemo(devolverResultado: true),
  crearPantallaReclamo: (_) => const _SimulatedFeatureScreen(
    title: 'Reclamar establecimiento',
    detail: 'El flujo se presenta en la app real. En esta demo no se envían reclamos.',
  ),
);

Future<List<PromocionDestacadaModel>> _cargarPromocionesDemo() async =>
    _promocionesDemo;

class _EvaluationHub extends StatefulWidget {
  const _EvaluationHub({
    required this.sky,
    required this.reducedMotion,
    required this.onReducedMotionChanged,
    required this.refrescarExplorar,
  });
  final SkyController? sky;
  final bool reducedMotion;
  final ValueChanged<bool> onReducedMotionChanged;
  final VoidCallback refrescarExplorar;

  @override
  State<_EvaluationHub> createState() => _EvaluationHubState();
}

class _EvaluationHubState extends State<_EvaluationHub> {
  bool _probandoGps = false;
  String? _resultadoGps;

  Future<void> _probarGps() async {
    if (_probandoGps) return;
    setState(() => _probandoGps = true);
    final result = await GeolocatorUbicacionService().obtenerUbicacion();
    if (!mounted) return;
    setState(() {
      _probandoGps = false;
      _resultadoGps = result.ubicacion == null
          ? result.mensaje ?? result.estado.name
          : 'Permiso concedido · ${result.ubicacion!.latitud.toStringAsFixed(5)}, ${result.ubicacion!.longitud.toStringAsFixed(5)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Scaffold(
      backgroundColor: sky.background,
      appBar: AppBar(title: const Text('Cercly · Cuenta y demo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _DemoInfoCard(
            icon: Icons.science_outlined,
            title: 'Entorno de demostración',
            body: 'Las fichas, promociones y la cuenta son datos ficticios guardados solo en memoria. Las pantallas de envío y administración no escriben datos.',
          ),
          const SizedBox(height: 12),
          Text(
            'Cercly Sky',
            style: TextStyle(
              color: sky.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<SkyMode>(
            key: const Key('evaluation-sky-mode'),
            initialValue: widget.sky?.mode ?? SkyMode.automatico,
            decoration: const InputDecoration(labelText: 'Ambiente Cercly Sky'),
            items: SkyMode.values
                .map(
                  (mode) =>
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                )
                .toList(),
            onChanged: (mode) {
              if (mode != null) widget.sky?.selectMode(mode);
            },
          ),
          SwitchListTile.adaptive(
            key: const Key('evaluation-reduced-motion'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Movimiento reducido'),
            value: widget.reducedMotion,
            onChanged: widget.onReducedMotionChanged,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('evaluation-open-account'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => _miCuentaDemo())),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('Abrir Mi cuenta'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('evaluation-login'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => _loginDemo())),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Ver inicio de sesión (simulado)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => _registroCuentasDemo()),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Ver registro de cuenta (simulado)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => _recuperacionDemo()),
            ),
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text('Ver recuperación de contraseña (simulada)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('evaluation-gps'),
            onPressed: _probandoGps ? null : _probarGps,
            icon: _probandoGps
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              _probandoGps
                  ? 'Consultando GPS…'
                  : 'Probar permiso GPS del dispositivo',
            ),
          ),
          if (_resultadoGps != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _resultadoGps!,
                key: const Key('evaluation-gps-result'),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _DemoAdminScreen(
                  onSolicitudActualizada: widget.refrescarExplorar,
                ),
              ),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Revisar solicitudes · simulación local'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _DemoOwnerScreen()),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Panel de propietario · vista demo'),
          ),
        ],
      ),
    );
  }
}

MiCuentaScreen _miCuentaDemo() => MiCuentaScreen(
  correo: 'demo@cercly.local',
  cerrarSesion: () async {},
  mostrarConfiguracion: false,
  negociosScreenBuilder: (_) => _misNegociosDemo(),
);

Widget _misNegociosDemo() => MisNegociosScreen(
  cargarNegocios: () async => List.unmodifiable(_DemoDataStore.misNegocios),
  registroService: _DemoRegistrationRepository(),
  registroScreenBuilder: (_) => RegistroEstablecimientoScreen(
    service: _DemoRegistrationRepository(),
    soloEvaluacion: true,
    enviarSolicitudDemoLocal: _DemoDataStore.agregarSolicitud,
  ),
  reclamoScreenBuilder: (_) => const _SimulatedFeatureScreen(
    title: 'Reclamar establecimiento',
    detail: 'La interfaz está disponible en Cercly. En modo demo el reclamo no se envía.',
  ),
  solicitudesScreenBuilder: (_) => const _DemoRequestsScreen(),
);

Widget _loginDemo({bool devolverResultado = false}) => LoginScreen(
  service: AuthService(options: const AuthOptions(google: false)),
  devolverResultado: devolverResultado,
  iniciarSesion: ({required email, required password}) async {},
  registroBuilder: (_) => _registroCuentasDemo(),
  recuperacionBuilder: (_) => _recuperacionDemo(),
);

Widget _registroCuentasDemo() => SeleccionTipoCuentaScreen(
  registrarCuenta: ({
    required nombre,
    required email,
    required password,
    required tipoCuenta,
  }) async => false,
);

Widget _recuperacionDemo() => PasswordScreen(onSubmit: (_) async {});

class _DemoLocationService implements UbicacionService {
  const _DemoLocationService();

  @override
  Future<ResultadoUbicacion> obtenerUbicacion() async =>
      const ResultadoUbicacion(
        estado: EstadoUbicacion.disponible,
        ubicacion: _centroTulcan,
        mensaje: 'Ubicación ficticia de demostración.',
      );

  @override
  Future<bool> abrirAjustesAplicacion() async => false;

  @override
  Future<bool> abrirAjustesUbicacion() async => false;
}

class _DemoCategoryRepository implements CategoriaPublicaRepository {
  @override
  Future<List<CategoriaModel>> listarCategorias() async => _categoriasDemo;

  @override
  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async => _subcategoriasDemo
      .where((item) => item.categoriaId == categoriaId)
      .toList();
}

class _DemoEstablishmentRepository implements EstablecimientoCercanoRepository {
  @override
  Future<List<EstablecimientoPublicoModel>> buscarCercanos({
    required double latitud,
    required double longitud,
    int radioMetros = 5000,
    String? categoriaId,
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    String? busqueda,
    int limite = 20,
    int desplazamiento = 0,
  }) async {
    final term = busqueda?.trim().toLowerCase() ?? '';
    final matches =
        [..._establecimientosDemo, ..._DemoDataStore.publicados].where((item) {
          final withinRadius = (item.distanciaMetros ?? 0) <= radioMetros;
          final withinCategory =
              categoriaId == null || item.categoriaId == categoriaId;
          final withinPromotion = !soloPromociones || item.tienePromociones;
          final withinSearch =
              term.isEmpty ||
              item.nombre.toLowerCase().contains(term) ||
              item.categoria.nombre.toLowerCase().contains(term);
          return withinRadius &&
              withinCategory &&
              withinPromotion &&
              withinSearch;
        }).toList()..sort(
          (a, b) => (a.distanciaMetros ?? 0).compareTo(b.distanciaMetros ?? 0),
        );
    final start = desplazamiento.clamp(0, matches.length);
    final end = (start + limite).clamp(0, matches.length);
    return matches.sublist(start, end);
  }
}

class _DemoRegistrationRepository implements RegistroEstablecimientoRepository {
  @override
  Future<List<Map<String, dynamic>>> listarCategoriasActivas() async => const [
    {'id': 'demo-costura', 'nombre': 'Costurería'},
    {'id': 'demo-cafe', 'nombre': 'Cafetería'},
  ];

  @override
  Future<List<Map<String, dynamic>>> buscarCoincidenciasCercanas({
    required String nombre,
    required double latitud,
    required double longitud,
  }) async {
    if (!nombre.toLowerCase().contains('costur')) return const [];
    return const [
      {
        'id': 'demo-costura-tulcan',
        'nombre': 'Costurería Cercly Demo',
        'direccion': 'Referencia: parque central de Tulcán (ficticia)',
        'distancia_metros': 320.0,
        'fuente': 'cercly',
        'estado_reclamo': 'no_reclamado',
        'propietario_id': null,
      },
    ];
  }

  @override
  Future<String> crearSolicitudRegistro({
    required String nombre,
    required String categoriaId,
    required String descripcion,
    required String direccion,
    required String telefono,
    required double latitud,
    required double longitud,
    List<Map<String, dynamic>> horarios = const [],
  }) async => throw StateError(
    'La demo solo permite escribir mediante el callback local en memoria.',
  );
}

class _SolicitudDemo {
  _SolicitudDemo({
    required this.id,
    required this.nombre,
    required this.categoriaId,
    required this.descripcion,
    required this.direccion,
    required this.telefono,
    required this.latitud,
    required this.longitud,
    required this.horarios,
  });

  final String id;
  final String nombre;
  final String categoriaId;
  final String descripcion;
  final String direccion;
  final String telefono;
  final double latitud;
  final double longitud;
  final List<Map<String, dynamic>> horarios;
  String estado = 'pendiente';
}

class _DemoDataStore {
  static final List<_SolicitudDemo> solicitudes = [];
  static final List<EstablecimientoPublicoModel> publicados = [];
  static final List<EstablecimientoModel> misNegocios = [];
  static int _secuencia = 0;

  static Future<String> agregarSolicitud({
    required String nombre,
    required String categoriaId,
    required String descripcion,
    required String direccion,
    required String telefono,
    required double latitud,
    required double longitud,
    List<Map<String, dynamic>> horarios = const [],
  }) async {
    final id = 'solicitud-demo-${++_secuencia}';
    solicitudes.add(
      _SolicitudDemo(
        id: id,
        nombre: nombre.trim(),
        categoriaId: categoriaId,
        descripcion: descripcion.trim(),
        direccion: direccion.trim(),
        telefono: telefono.trim(),
        latitud: latitud,
        longitud: longitud,
        horarios: List.unmodifiable(horarios),
      ),
    );
    return id;
  }

  static void aprobar(String solicitudId) {
    final solicitud = solicitudes.firstWhere((item) => item.id == solicitudId);
    if (solicitud.estado != 'pendiente') return;
    final categoria = _categoriasDemo.firstWhere(
      (item) => item.id == solicitud.categoriaId,
      orElse: () => _categoriasDemo.first,
    );
    final categoriaPublica = CategoriaPublicaModel(
      id: categoria.id,
      nombre: categoria.nombre,
      slug: categoria.slug,
      icono: categoria.icono,
    );
    publicados.add(
      EstablecimientoPublicoModel(
        id: solicitud.id,
        nombre: solicitud.nombre,
        descripcion: solicitud.descripcion,
        direccion: solicitud.direccion,
        latitud: solicitud.latitud,
        longitud: solicitud.longitud,
        telefonoPublico: solicitud.telefono,
        zonaHoraria: 'America/Guayaquil',
        categoria: categoriaPublica,
        promociones: const [],
        ciudad: 'Tulcán',
        provincia: 'Carchi',
        distanciaMetros: 420,
        fuente: 'cercly',
      ),
    );
    misNegocios.add(
      EstablecimientoModel(
        id: solicitud.id,
        propietarioId: 'propietario-demo',
        nombre: solicitud.nombre,
        descripcion: solicitud.descripcion,
        categoriaId: solicitud.categoriaId,
        direccion: solicitud.direccion,
        latitud: solicitud.latitud,
        longitud: solicitud.longitud,
        telefonoPublico: solicitud.telefono,
        horario: {
          for (final dia in EstablecimientoModel.diasSemana)
            dia: <TurnoHorario>[],
        },
        zonaHoraria: 'America/Guayaquil',
        estado: 'aprobado',
      ),
    );
    solicitud.estado = 'aprobado (demo)';
  }

  static void rechazar(String solicitudId) {
    final solicitud = solicitudes.firstWhere((item) => item.id == solicitudId);
    if (solicitud.estado == 'pendiente') solicitud.estado = 'rechazado (demo)';
  }
}

class _DemoRequestsScreen extends StatelessWidget {
  const _DemoRequestsScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis solicitudes · demo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _DemoInfoCard(
          icon: Icons.science_outlined,
          title: 'Datos locales efímeros',
          body: 'Las solicitudes existen solo en memoria y se pierden al cerrar la app.',
        ),
        const SizedBox(height: 12),
        if (_DemoDataStore.solicitudes.isEmpty)
          const ListTile(title: Text('Todavía no hay solicitudes demo.')),
        for (final solicitud in _DemoDataStore.solicitudes)
          Card(
            child: ListTile(
              title: Text(solicitud.nombre),
              subtitle: Text(
                '${solicitud.direccion}\nEstado: ${solicitud.estado}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    ),
  );
}

class _DemoAdminScreen extends StatefulWidget {
  const _DemoAdminScreen({this.onSolicitudActualizada});

  final VoidCallback? onSolicitudActualizada;

  @override
  State<_DemoAdminScreen> createState() => _DemoAdminScreenState();
}

class _DemoAdminScreenState extends State<_DemoAdminScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisión local · administrador demo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _DemoInfoCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Simulación administrativa',
          body: 'Aprobar o rechazar cambia solo esta sesión de demo. No modifica Supabase ni concede permisos reales.',
        ),
        const SizedBox(height: 12),
        for (final solicitud in _DemoDataStore.solicitudes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(solicitud.nombre),
                    subtitle: Text(
                      '${solicitud.direccion}\nEstado: ${solicitud.estado}',
                    ),
                  ),
                  if (solicitud.estado == 'pendiente')
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _DemoDataStore.rechazar(solicitud.id);
                            widget.onSolicitudActualizada?.call();
                          }),
                          child: const Text('Rechazar en demo'),
                        ),
                        FilledButton(
                          onPressed: () => setState(() {
                            _DemoDataStore.aprobar(solicitud.id);
                            widget.onSolicitudActualizada?.call();
                          }),
                          child: const Text('Aprobar en demo'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (_DemoDataStore.solicitudes.isEmpty)
          const ListTile(title: Text('No hay solicitudes locales pendientes.')),
      ],
    ),
  );
}

class _DemoOwnerScreen extends StatelessWidget {
  const _DemoOwnerScreen();

  @override
  Widget build(BuildContext context) => const _SimulatedFeatureScreen(
    title: 'Panel del propietario · demo',
    detail: 'Los módulos reales de información, horarios, fotografías y promociones requieren sesión y staging. Esta vista no ejecuta escrituras.',
  );
}

class _DemoInfoCard extends StatelessWidget {
  const _DemoInfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final sky = SkyPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sky.surface,
        border: Border.all(color: sky.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: sky.interactive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: sky.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(body, style: TextStyle(color: sky.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulatedFeatureScreen extends StatelessWidget {
  const _SimulatedFeatureScreen({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _DemoInfoCard(
          icon: Icons.info_outline_rounded,
          title: 'Función simulada',
          body: detail,
        ),
      ),
    ),
  );
}

final _categoriasDemo = <CategoriaModel>[
  CategoriaModel(
    id: 'demo-costura',
    nombre: 'Costurería',
    slug: 'costureria',
    icono: 'content_cut',
    activa: true,
    orden: 1,
  ),
  CategoriaModel(
    id: 'demo-cafe',
    nombre: 'Cafetería',
    slug: 'cafeteria',
    icono: 'coffee',
    activa: true,
    orden: 2,
  ),
  CategoriaModel(
    id: 'demo-pan',
    nombre: 'Panadería',
    slug: 'panaderia',
    icono: 'bakery_dining',
    activa: true,
    orden: 3,
  ),
];

final _subcategoriasDemo = <SubcategoriaModel>[
  const SubcategoriaModel(
    id: 'demo-arreglos',
    categoriaId: 'demo-costura',
    nombre: 'Arreglos',
    slug: 'arreglos',
    icono: 'content_cut',
    activa: true,
    orden: 1,
  ),
  const SubcategoriaModel(
    id: 'demo-cafe-especialidad',
    categoriaId: 'demo-cafe',
    nombre: 'Café de especialidad',
    slug: 'especialidad',
    icono: 'coffee',
    activa: true,
    orden: 1,
  ),
];

final _promocionCostura = PromocionPublicaModel(
  id: 'promo-demo-costura',
  titulo: 'Dobladillos de demostración',
  descripcion: 'Promoción ficticia para mostrar la tarjeta y el detalle.',
  fechaInicio: DateTime.now().subtract(const Duration(days: 1)),
  fechaFin: DateTime.now().add(const Duration(days: 7)),
  radioAlertaMetros: 5000,
);

final _establecimientosDemo = <EstablecimientoPublicoModel>[
  EstablecimientoPublicoModel(
    id: 'demo-costura-tulcan',
    nombre: 'Costurería Cercly Demo',
    descripcion: 'Ficha local ficticia para probar detalles, horarios y rutas.',
    direccion: 'Referencia: parque central de Tulcán (ubicación ficticia)',
    latitud: 0.8140,
    longitud: -77.7160,
    telefonoPublico: '',
    zonaHoraria: 'America/Guayaquil',
    categoria: const CategoriaPublicaModel(
      id: 'demo-costura',
      nombre: 'Costurería',
      slug: 'costureria',
      icono: 'content_cut',
    ),
    promociones: [_promocionCostura],
    ciudad: 'Tulcán',
    provincia: 'Carchi',
    distanciaMetros: 320,
    tienePromocionesRpc: true,
    fuente: 'osm',
    estadoReclamo: 'no_reclamado',
  ),
  EstablecimientoPublicoModel(
    id: 'demo-cafe-tulcan',
    nombre: 'Café de la Plaza · Demo',
    descripcion: 'Café ficticio para comprobar tarjetas, filtros y mapa.',
    direccion: 'Centro de Tulcán · punto de demostración',
    latitud: 0.8096,
    longitud: -77.7194,
    telefonoPublico: '',
    zonaHoraria: 'America/Guayaquil',
    categoria: const CategoriaPublicaModel(
      id: 'demo-cafe',
      nombre: 'Cafetería',
      slug: 'cafeteria',
      icono: 'coffee',
    ),
    promociones: const [],
    ciudad: 'Tulcán',
    provincia: 'Carchi',
    distanciaMetros: 710,
    tienePromocionesRpc: false,
  ),
  EstablecimientoPublicoModel(
    id: 'demo-pan-tulcan',
    nombre: 'Panadería del Norte · Demo',
    descripcion: 'Establecimiento ficticio con coordenadas estáticas.',
    direccion: 'Tulcán · punto de demostración',
    latitud: 0.8180,
    longitud: -77.7130,
    telefonoPublico: '',
    zonaHoraria: 'America/Guayaquil',
    categoria: const CategoriaPublicaModel(
      id: 'demo-pan',
      nombre: 'Panadería',
      slug: 'panaderia',
      icono: 'bakery_dining',
    ),
    promociones: const [],
    ciudad: 'Tulcán',
    provincia: 'Carchi',
    distanciaMetros: 1120,
    tienePromocionesRpc: false,
  ),
];

final _promocionesDemo = <PromocionDestacadaModel>[
  PromocionDestacadaModel(
    id: 'promo-demo-costura',
    establecimientoId: 'demo-costura-tulcan',
    establecimientoNombre: 'Costurería Cercly Demo',
    categoriaNombre: 'Costurería',
    titulo: _promocionCostura.titulo,
    descripcion: _promocionCostura.descripcion,
    fechaInicio: _promocionCostura.fechaInicio,
    fechaFin: _promocionCostura.fechaFin,
    radioAlertaMetros: _promocionCostura.radioAlertaMetros,
    latitud: 0.8140,
    longitud: -77.7160,
    distanciaMetros: 320,
  ),
];
