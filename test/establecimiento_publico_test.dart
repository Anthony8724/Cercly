import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';

Map<String, dynamic> crearDetallePublico({
  String id = 'establecimiento-1',
  String categoriaId = 'categoria-1',
}) {
  return <String, dynamic>{
    'id': id,
    'nombre': 'Cafetería Central',
    'descripcion': 'Café y postres',
    'direccion': 'Tulcán, Ecuador',
    'latitud': 0.8119,
    'longitud': -77.7173,
    'telefono_publico': '0999999999',
    'zona_horaria': 'America/Guayaquil',
    'ciudad': 'Tulcán',
    'provincia': 'Carchi',
    'pais_codigo': 'EC',
    'categorias': <String, dynamic>{
      'id': categoriaId,
      'nombre': 'Comida y bebidas',
      'slug': 'comida-bebidas',
      'icono': 'restaurant',
    },
    'fotos_establecimiento': <Map<String, dynamic>>[],
    'promociones': <Map<String, dynamic>>[],
  };
}

void main() {
  group('EstablecimientoPublicoModel', () {
    test('convierte correctamente los datos de Supabase', () {
      final ahora = DateTime.now();

      final datos = <String, dynamic>{
        'id': 'establecimiento-1',
        'nombre': 'Cafetería Central',
        'descripcion': 'Café y postres',
        'direccion': 'Tulcán, Ecuador',
        'latitud': 0.8119,
        'longitud': -77.7173,
        'telefono_publico': '0999999999',
        'zona_horaria': 'America/Guayaquil',
        'categorias': <String, dynamic>{
          'id': 'categoria-1',
          'nombre': 'Cafeterías',
          'slug': 'cafeterias',
          'icono': 'coffee',
        },
        'fotos_establecimiento': <Map<String, dynamic>>[
          {
            'id': 'foto-2',
            'ruta_storage': 'usuario/establecimiento/foto2.jpg',
            'es_portada': false,
            'orden': 0,
          },
          {
            'id': 'foto-1',
            'ruta_storage': 'usuario/establecimiento/portada.jpg',
            'es_portada': true,
            'orden': 1,
          },
        ],
        'promociones': <Map<String, dynamic>>[
          {
            'id': 'promocion-1',
            'titulo': 'Café con descuento',
            'descripcion': 'Promoción de prueba',
            'imagen_ruta_storage': 'usuario/establecimiento/promocion.jpg',
            'fecha_inicio': ahora
                .subtract(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'fecha_fin': ahora
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'radio_alerta_metros': 200,
          },
        ],
      };

      final establecimiento = EstablecimientoPublicoModel.fromSupabase(datos);

      expect(establecimiento.id, 'establecimiento-1');
      expect(establecimiento.nombre, 'Cafetería Central');
      expect(establecimiento.categoria.nombre, 'Cafeterías');
      expect(
        establecimiento.rutaFotoPortada,
        'usuario/establecimiento/portada.jpg',
      );
      expect(establecimiento.promociones, hasLength(1));
      expect(establecimiento.tienePromociones, isTrue);
      expect(establecimiento.categoriaId, 'categoria-1');
    });

    test('descarta promociones que ya finalizaron', () {
      final ahora = DateTime.now();

      final datos = <String, dynamic>{
        'id': 'establecimiento-1',
        'nombre': 'Tienda Central',
        'descripcion': '',
        'direccion': 'Tulcán',
        'latitud': 0.8119,
        'longitud': -77.7173,
        'telefono_publico': '',
        'zona_horaria': 'America/Guayaquil',
        'categorias': <String, dynamic>{
          'id': 'categoria-1',
          'nombre': 'Tiendas',
          'slug': 'tiendas',
          'icono': 'store',
        },
        'fotos_establecimiento': <Map<String, dynamic>>[],
        'promociones': <Map<String, dynamic>>[
          {
            'id': 'promocion-finalizada',
            'titulo': 'Promoción finalizada',
            'descripcion': '',
            'imagen_ruta_storage': null,
            'fecha_inicio': ahora
                .subtract(const Duration(days: 2))
                .toUtc()
                .toIso8601String(),
            'fecha_fin': ahora
                .subtract(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
            'radio_alerta_metros': 100,
          },
        ],
      };

      final establecimiento = EstablecimientoPublicoModel.fromSupabase(datos);

      expect(establecimiento.promociones, isEmpty);
      expect(establecimiento.tienePromociones, isFalse);
    });

    test('formatea metros y kilómetros correctamente', () {
      final categoria = CategoriaPublicaModel(
        id: 'categoria-1',
        nombre: 'Restaurantes',
        slug: 'restaurantes',
        icono: 'restaurant',
      );

      final cercano = EstablecimientoPublicoModel(
        id: 'establecimiento-1',
        nombre: 'Restaurante Uno',
        descripcion: '',
        direccion: 'Tulcán',
        latitud: 0,
        longitud: 0,
        telefonoPublico: '',
        zonaHoraria: 'America/Guayaquil',
        categoria: categoria,
        promociones: const [],
        distanciaMetros: 450,
      );

      final lejano = EstablecimientoPublicoModel(
        id: 'establecimiento-2',
        nombre: 'Restaurante Dos',
        descripcion: '',
        direccion: 'Tulcán',
        latitud: 0,
        longitud: 0,
        telefonoPublico: '',
        zonaHoraria: 'America/Guayaquil',
        categoria: categoria,
        promociones: const [],
        distanciaMetros: 1500,
      );

      expect(cercano.distanciaFormateada, '450 m');
      expect(lejano.distanciaFormateada, '1.5 km');
    });
  });

  group('EstablecimientoPublicoService', () {
    late EstablecimientoPublicoService service;

    setUp(() {
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key-de-prueba',
      );

      service = EstablecimientoPublicoService(supabase: supabase);
    });

    test('la distancia entre el mismo punto es cero', () {
      final distancia = service.calcularDistanciaMetros(
        latitudOrigen: 0.8119,
        longitudOrigen: -77.7173,
        latitudDestino: 0.8119,
        longitudDestino: -77.7173,
      );

      expect(distancia, closeTo(0, 0.001));
    });

    test('calcula aproximadamente un grado de latitud', () {
      final distancia = service.calcularDistanciaMetros(
        latitudOrigen: 0,
        longitudOrigen: 0,
        latitudDestino: 1,
        longitudDestino: 0,
      );

      expect(distancia, greaterThan(110000));
      expect(distancia, lessThan(112500));
    });

    test('rechaza coordenadas que están fuera del rango', () {
      expect(
        () => service.calcularDistanciaMetros(
          latitudOrigen: 100,
          longitudOrigen: 0,
          latitudDestino: 0,
          longitudDestino: 0,
        ),
        throwsArgumentError,
      );
    });

    test('envía todos los filtros y la paginación al RPC PostGIS', () async {
      Map<String, dynamic>? parametrosRecibidos;
      List<String>? idsSolicitados;
      List<String>? idsHorariosSolicitados;

      final servicioRpc = EstablecimientoPublicoService(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'publishable-key-de-prueba',
        ),
        ejecutarRpcCercanos: (parametros) async {
          parametrosRecibidos = parametros;
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'establecimiento-1',
              'distancia_metros': 245.75,
              'tiene_promociones': true,
            },
          ];
        },
        cargarDetallesPublicos: (ids) async {
          idsSolicitados = ids;
          return <Map<String, dynamic>>[crearDetallePublico()];
        },
        cargarHorariosPublicos: (ids) async {
          idsHorariosSolicitados = ids;
          return const <Map<String, dynamic>>[];
        },
      );

      final resultado = await servicioRpc.buscarCercanos(
        latitud: 0.8116,
        longitud: -77.7172,
        radioMetros: 2500,
        categoriaId: ' categoria-1 ',
        subcategoriaIds: const ['subcategoria-1', 'subcategoria-2'],
        soloPromociones: true,
        busqueda: ' Café ',
        limite: 15,
        desplazamiento: 30,
      );

      expect(parametrosRecibidos, <String, dynamic>{
        'p_latitud': 0.8116,
        'p_longitud': -77.7172,
        'p_radio_metros': 2500,
        'p_categoria_id': 'categoria-1',
        'p_subcategoria_ids': ['subcategoria-1', 'subcategoria-2'],
        'p_solo_promociones': true,
        'p_busqueda': 'Café',
        'p_limite': 15,
        'p_desplazamiento': 30,
      });
      expect(idsSolicitados, ['establecimiento-1']);
      expect(idsHorariosSolicitados, ['establecimiento-1']);
      expect(resultado, hasLength(1));
      expect(resultado.single.distanciaMetros, 245.75);
      expect(resultado.single.tienePromociones, isTrue);
      expect(resultado.single.estadoHorario, 'sinHorario');
      expect(resultado.single.ciudad, 'Tulcán');
      expect(resultado.single.provincia, 'Carchi');
      expect(resultado.single.paisCodigo, 'EC');
    });

    test('envía filtros opcionales vacíos como null', () async {
      Map<String, dynamic>? parametrosRecibidos;

      final servicioRpc = EstablecimientoPublicoService(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'publishable-key-de-prueba',
        ),
        ejecutarRpcCercanos: (parametros) async {
          parametrosRecibidos = parametros;
          return const <Map<String, dynamic>>[];
        },
      );

      await servicioRpc.buscarCercanos(
        latitud: 0.8116,
        longitud: -77.7172,
        categoriaId: ' ',
        subcategoriaIds: const [' ', ''],
        busqueda: '   ',
      );

      expect(parametrosRecibidos!['p_categoria_id'], isNull);
      expect(parametrosRecibidos!['p_subcategoria_ids'], isNull);
      expect(parametrosRecibidos!['p_solo_promociones'], isFalse);
      expect(parametrosRecibidos!['p_busqueda'], isNull);
      expect(parametrosRecibidos!['p_limite'], 20);
      expect(parametrosRecibidos!['p_desplazamiento'], 0);
    });

    test('rechaza coordenadas inválidas antes de llamar al RPC', () async {
      var fueInvocado = false;
      final servicioRpc = EstablecimientoPublicoService(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'publishable-key-de-prueba',
        ),
        ejecutarRpcCercanos: (parametros) async {
          fueInvocado = true;
          return const <Map<String, dynamic>>[];
        },
      );

      await expectLater(
        servicioRpc.buscarCercanos(latitud: 91, longitud: -77.7172),
        throwsArgumentError,
      );
      expect(fueInvocado, isFalse);
    });

    test('rechaza radio, límite y desplazamiento inválidos', () async {
      await expectLater(
        service.buscarCercanos(
          latitud: 0.8116,
          longitud: -77.7172,
          radioMetros: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.buscarCercanos(
          latitud: 0.8116,
          longitud: -77.7172,
          limite: 101,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.buscarCercanos(
          latitud: 0.8116,
          longitud: -77.7172,
          desplazamiento: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
