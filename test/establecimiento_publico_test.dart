import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/features/establecimientos/models/establecimiento_publico_model.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';

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
  });
}
