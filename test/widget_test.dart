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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _EstablecimientosVacios implements EstablecimientoCercanoRepository {
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
  Future<bool> abrirAjustesAplicacion() async => true;

  @override
  Future<bool> abrirAjustesUbicacion() async => true;

  @override
  Future<ResultadoUbicacion> obtenerUbicacion() async =>
      const ResultadoUbicacion(
        estado: EstadoUbicacion.permisoDenegado,
        mensaje: 'Permiso denegado',
      );
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

    expect(find.text('Cerca de ti'), findsOneWidget);
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

  test('resuelve navegación por rol e intención de propietario', () {
    expect(resolverDestinoCuenta(rol: 'usuario'), DestinoCuenta.cuenta);
    expect(
      resolverDestinoCuenta(rol: 'propietario'),
      DestinoCuenta.negocio,
    );
    expect(
      resolverDestinoCuenta(rol: 'administrador'),
      DestinoCuenta.administrador,
    );
    expect(
      resolverDestinoCuenta(
        rol: 'usuario',
        metadatos: const {'tipo_cuenta': 'propietario'},
      ),
      DestinoCuenta.negocio,
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
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('cerrar-sesion-cuenta')));
    await tester.pump();
    expect(cerroSesion, isTrue);
  });
}
