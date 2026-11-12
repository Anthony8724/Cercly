import 'dart:async';

import 'package:cercly/features/auth/screens/acceso_publico_screen.dart';
import 'package:cercly/features/auth/screens/auth_gate.dart';
import 'package:cercly/features/auth/screens/login_screen.dart';
import 'package:cercly/features/auth/screens/mi_cuenta_screen.dart';
import 'package:cercly/features/auth/screens/register_screen.dart';
import 'package:cercly/features/auth/screens/seleccion_tipo_cuenta_screen.dart';
import 'package:cercly/features/categorias/models/categoria_model.dart';
import 'package:cercly/features/categorias/models/subcategoria_model.dart';
import 'package:cercly/features/categorias/services/categoria_publica_service.dart';
import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';
import 'package:cercly/features/explorar/controllers/explorar_controller.dart';
import 'package:cercly/features/explorar/models/ubicacion_usuario.dart';
import 'package:cercly/features/explorar/screens/navegacion_principal_screen.dart';
import 'package:cercly/features/explorar/services/ubicacion_service.dart';
import 'package:cercly/features/notificaciones/controllers/monitor_proximidad_controller.dart';
import 'package:cercly/features/notificaciones/services/notificacion_local_service.dart';
import 'package:cercly/features/notificaciones/widgets/monitor_proximidad_app.dart';
import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/services/promocion_publica_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _EstablecimientosVacios implements EstablecimientoCercanoRepository {
  @override
  Future<List<EstablecimientoPublicoModel>> listar({
    String? categoriaId,
    List<String>? subcategoriaIds,
    bool soloPromociones = false,
    String? busqueda,
    int limite = 20,
    int desplazamiento = 0,
  }) async => const [];

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
  }) async => const [];
}

class _CategoriasVacias implements CategoriaPublicaRepository {
  @override
  Future<List<CategoriaModel>> listarCategorias() async => const [];

  @override
  Future<List<SubcategoriaModel>> listarSubcategorias(
    String categoriaId,
  ) async => const [];
}

class _UbicacionDenegada implements UbicacionService {
  @override
  Future<EstadoUbicacion> consultarEstadoPermiso({
    bool solicitarPermiso = false,
  }) async => EstadoUbicacion.permisoDenegado;

  @override
  Future<bool> abrirAjustesAplicacion() async => true;

  @override
  Future<bool> abrirAjustesUbicacion() async => true;

  @override
  Future<ResultadoUbicacion> obtenerUbicacion({
    bool solicitarPermiso = false,
  }) async => const ResultadoUbicacion(
    estado: EstadoUbicacion.permisoDenegado,
    mensaje: 'Permiso denegado',
  );
}

class _UbicacionFresca extends _UbicacionDenegada {
  @override
  Future<ResultadoUbicacion> obtenerUbicacion({
    bool solicitarPermiso = false,
  }) async => ResultadoUbicacion(
    estado: EstadoUbicacion.disponible,
    ubicacion: UbicacionUsuario(
      latitud: 0.8116,
      longitud: -77.7172,
      precisionMetros: 10,
      capturadaEn: DateTime.now(),
    ),
  );
}

class _PromocionesVacias implements PromocionesCercanasRepository {
  _PromocionesVacias([this.promociones = const []]);

  final List<PromocionDestacadaModel> promociones;

  @override
  Future<List<PromocionDestacadaModel>> listarCercanas({
    required double latitudUsuario,
    required double longitudUsuario,
    int radioUsuarioMetros = 500,
  }) async => promociones;
}

class _NotificacionesSilenciosas implements NotificacionPromocionGateway {
  @override
  Future<void> inicializar() async {}

  @override
  Future<bool> tienePermisoParaNotificar() async => false;

  @override
  Future<bool> mostrarPromocion(PromocionDestacadaModel promocion) async =>
      false;
}

ExplorarController _controllerPrueba() => ExplorarController(
  establecimientoService: _EstablecimientosVacios(),
  categoriaService: _CategoriasVacias(),
  ubicacionService: _UbicacionDenegada(),
);

User _usuario() => User.fromJson({
  'id': 'usuario-prueba',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'prueba@cercly.app',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'created_at': '2026-09-13T00:00:00.000Z',
})!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('sin sesión abre Explorar y muestra Regístrate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream<User?>.value(null),
          explorarController: _controllerPrueba(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Establecimientos'), findsOneWidget);
    expect(find.text('Regístrate'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('sin sesión puede abrir Mapa y Regístrate', (tester) async {
    final controller = _controllerPrueba();
    await tester.pumpWidget(
      MaterialApp(
        home: NavegacionPrincipalScreen(
          terceraOpcionBuilder: (_) => const AccesoPublicoScreen(),
          terceraOpcionLabel: 'Regístrate',
          terceraOpcionIcon: Icons.person_add_outlined,
          terceraOpcionSelectedIcon: Icons.person_add,
          controller: controller,
          inicializarController: false,
          mostrarTilesMapa: false,
        ),
      ),
    );

    await tester.tap(find.text('Mapa'));
    await tester.pump();
    expect(find.text('Mapa sin ubicación'), findsOneWidget);

    await tester.tap(find.text('Regístrate'));
    await tester.pump();
    expect(find.text('Únete a Cercly'), findsOneWidget);
  });

  testWidgets('panel Radar respeta atribución y controles del mapa', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final explorar = _controllerPrueba()
      ..ubicacion = const UbicacionUsuario(latitud: 0.8116, longitud: -77.7172);
    final ahora = DateTime.now();
    final monitor = MonitorProximidadController(
      ubicacionService: _UbicacionFresca(),
      promocionesService: _PromocionesVacias([
        PromocionDestacadaModel(
          id: 'promo-test',
          establecimientoId: 'negocio-test',
          establecimientoNombre: 'Negocio del Radar',
          categoriaNombre: 'Comida',
          titulo: 'Promoción vigente',
          descripcion: 'Prueba',
          fechaInicio: ahora.subtract(const Duration(hours: 1)),
          fechaFin: ahora.add(const Duration(hours: 1)),
          radioAlertaMetros: 1500,
          latitud: 0.8116,
          longitud: -77.7172,
          distanciaMetros: 50,
        ),
      ]),
      notificaciones: _NotificacionesSilenciosas(),
      usuarioId: () => 'cuenta-a',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonitorProximidadScope(
          controller: monitor,
          child: NavegacionPrincipalScreen(
            terceraOpcionBuilder: (_) => const AccesoPublicoScreen(),
            terceraOpcionLabel: 'Regístrate',
            terceraOpcionIcon: Icons.person_add_outlined,
            terceraOpcionSelectedIcon: Icons.person_add,
            controller: explorar,
            inicializarController: false,
            mostrarTilesMapa: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    final radar = tester.getRect(find.byKey(const Key('radar-panel-position')));
    final atribucion = tester.getRect(
      find.byKey(const Key('atribucion-openstreetmap-explorar')),
    );
    final controles = tester.getRect(find.text('Mapa Cercly'));
    expect(radar.bottom, lessThan(atribucion.top));
    expect(radar.top, greaterThan(controles.bottom));
    await tester.tap(find.byKey(const Key('radar-cercly-toggle')));
    await monitor.iniciar();
    await tester.pumpAndSettle();
    final radarActivo = tester.getRect(
      find.byKey(const Key('radar-panel-position')),
    );
    expect(radarActivo.bottom, lessThan(atribucion.top));
    expect(radarActivo.top, greaterThan(controles.bottom));
    await tester.tap(find.byKey(const Key('radar-list-toggle')));
    await tester.pumpAndSettle();
    final radarExpandido = tester.getRect(
      find.byKey(const Key('radar-panel-position')),
    );
    expect(find.text('Negocio del Radar'), findsOneWidget);
    expect(radarExpandido.bottom, lessThan(atribucion.top));
    expect(radarExpandido.top, greaterThan(controles.bottom));
    monitor.dispose();
  });

  test('resuelve navegación exclusivamente por rol autorizado', () {
    expect(resolverDestinoCuenta(rol: 'usuario'), DestinoCuenta.cuenta);
    expect(resolverDestinoCuenta(rol: 'propietario'), DestinoCuenta.negocio);
    expect(
      resolverDestinoCuenta(rol: 'administrador'),
      DestinoCuenta.administrador,
    );
    expect(
      resolverDestinoCuenta(
        rol: 'usuario',
        metadatos: const {'tipo_cuenta': 'propietario'},
      ),
      DestinoCuenta.cuenta,
    );
  });

  testWidgets('administrador conserva destino y logout vuelve al público', (
    tester,
  ) async {
    final sesiones = StreamController<User?>();
    addTearDown(sesiones.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: sesiones.stream,
          cargarRol: (_) async => 'administrador',
          construirNavegacion: (_, destino) => Text(destino.name),
          explorarController: _controllerPrueba(),
        ),
      ),
    );

    sesiones.add(_usuario());
    await tester.pumpAndSettle();
    expect(find.text('administrador'), findsOneWidget);

    sesiones.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Regístrate'), findsOneWidget);
  });

  testWidgets('registro permite elegir usuario o propietario', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SeleccionTipoCuentaScreen()),
    );

    expect(find.text('¿Cómo quieres usar Cercly?'), findsOneWidget);
    expect(find.text('Como usuario'), findsOneWidget);
    expect(find.text('Como propietario de un negocio'), findsOneWidget);
  });

  testWidgets('login conserva el flujo de autenticación', (tester) async {
    var ejecutado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          iniciarSesion: ({required email, required password}) async {
            ejecutado = email == 'persona@cercly.app' && password == '123456';
          },
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'persona@cercly.app',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(ejecutado, isTrue);
  });

  testWidgets('registro de propietario conserva el tipo seleccionado', (
    tester,
  ) async {
    TipoCuenta? recibido;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          tipoCuenta: TipoCuenta.propietario,
          registrarCuenta:
              ({
                required nombre,
                required email,
                required password,
                required tipoCuenta,
              }) async {
                recibido = tipoCuenta;
                return false;
              },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Persona Cercly');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'persona@cercly.app',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tester.enterText(find.byType(TextFormField).at(3), '123456');
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(recibido, TipoCuenta.propietario);
  });

  testWidgets('Mi cuenta permite cerrar sesión', (tester) async {
    var cerroSesion = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MiCuentaScreen(
          correo: 'persona@cercly.app',
          cerrarSesion: () async => cerroSesion = true,
          tieneNegocios: () async => false,
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('cerrar-sesion-cuenta')));
    await tester.tap(find.byKey(const Key('cerrar-sesion-cuenta')));
    await tester.pump();
    expect(cerroSesion, isTrue);
  });

  testWidgets('Mi cuenta oculta Mis negocios si no hay relación vinculada', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiCuentaScreen(
          correo: 'persona@cercly.app',
          cerrarSesion: () async {},
          tieneNegocios: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('abrir-mis-negocios')), findsNothing);
    expect(find.byKey(const Key('abrir-mis-preferencias')), findsOneWidget);
    expect(
      find.byKey(const Key('solicitar-registro-establecimiento-cuenta')),
      findsNothing,
    );
    expect(find.byKey(const Key('abrir-configuracion-cuenta')), findsOneWidget);
  });

  testWidgets('Mi cuenta muestra Mis negocios con relación comprobada', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiCuentaScreen(
          correo: 'propietaria@cercly.app',
          cerrarSesion: () async {},
          tieneNegocios: () async => true,
          negociosScreenBuilder: (_) =>
              const Scaffold(body: Text('Negocios vinculados')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('abrir-mis-negocios')), findsOneWidget);
  });

  testWidgets('primer negocio se registra desde Configuración', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiCuentaScreen(
          correo: 'persona@cercly.app',
          cerrarSesion: () async {},
          tieneNegocios: () async => false,
          registroScreenBuilder: (_) =>
              const Scaffold(body: Text('Formulario de registro existente')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('solicitar-registro-establecimiento-cuenta')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('abrir-configuracion-cuenta')));
    await tester.pumpAndSettle();
    expect(find.text('¿Tienes un negocio?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('registrar-mi-negocio-configuracion')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Formulario de registro existente'), findsOneWidget);
  });

  testWidgets('Mi cuenta conserva sus acciones en pantalla pequeña', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MiCuentaScreen(
          correo: 'persona@cercly.app',
          cerrarSesion: () async {},
          tieneNegocios: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('abrir-configuracion-cuenta')), findsOneWidget);
    expect(find.byKey(const Key('abrir-mis-preferencias')), findsOneWidget);
    expect(find.byKey(const Key('cerrar-sesion-cuenta')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
