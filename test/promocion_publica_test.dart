import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/services/promocion_publica_service.dart';

void main() {
  group('PromocionDestacadaModel', () {
    test('convierte correctamente los datos de Supabase', () {
      final ahora = DateTime.now();

      final datos = <String, dynamic>{
        'id': 'promocion-1',
        'titulo': '20% en desayunos',
        'descripcion': 'Promoción válida durante la mañana.',
        'imagen_ruta_storage': 'usuario/establecimiento/promocion.jpg',
        'fecha_inicio': ahora
            .subtract(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'fecha_fin': ahora
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'radio_alerta_metros': 250,
        'establecimientos': <String, dynamic>{
          'id': 'establecimiento-1',
          'nombre': 'Café Carchi',
          'latitud': 0.8119,
          'longitud': -77.7173,
          'estado': 'aprobado',
          'categorias': <String, dynamic>{'nombre': 'Cafeterías'},
        },
      };

      final promocion = PromocionDestacadaModel.fromSupabase(datos);

      expect(promocion.id, 'promocion-1');
      expect(promocion.establecimientoId, 'establecimiento-1');
      expect(promocion.establecimientoNombre, 'Café Carchi');
      expect(promocion.categoriaNombre, 'Cafeterías');
      expect(promocion.titulo, '20% en desayunos');
      expect(promocion.radioAlertaMetros, 250);
      expect(promocion.latitud, 0.8119);
      expect(promocion.longitud, -77.7173);
      expect(promocion.estaVigente, isTrue);
    });

    test('reconoce una promoción finalizada', () {
      final ahora = DateTime.now();

      final promocion = PromocionDestacadaModel(
        id: 'promocion-1',
        establecimientoId: 'establecimiento-1',
        establecimientoNombre: 'Café Carchi',
        categoriaNombre: 'Cafeterías',
        titulo: 'Promoción finalizada',
        descripcion: '',
        fechaInicio: ahora.subtract(const Duration(days: 2)),
        fechaFin: ahora.subtract(const Duration(days: 1)),
        radioAlertaMetros: 100,
        latitud: 0.8119,
        longitud: -77.7173,
      );

      expect(promocion.estaVigente, isFalse);
    });

    test('formatea metros y kilómetros correctamente', () {
      final ahora = DateTime.now();

      final promocionCercana = PromocionDestacadaModel(
        id: 'promocion-1',
        establecimientoId: 'establecimiento-1',
        establecimientoNombre: 'Café Carchi',
        categoriaNombre: 'Cafeterías',
        titulo: 'Promoción cercana',
        descripcion: '',
        fechaInicio: ahora.subtract(const Duration(hours: 1)),
        fechaFin: ahora.add(const Duration(hours: 1)),
        radioAlertaMetros: 500,
        latitud: 0.8119,
        longitud: -77.7173,
        distanciaMetros: 450,
      );

      final promocionLejana = promocionCercana.copiarCon(distanciaMetros: 1500);

      expect(promocionCercana.distanciaFormateada, '450 m');
      expect(promocionLejana.distanciaFormateada, '1.5 km');
    });

    test('copia la URL y la distancia calculada', () {
      final ahora = DateTime.now();

      final promocion = PromocionDestacadaModel(
        id: 'promocion-1',
        establecimientoId: 'establecimiento-1',
        establecimientoNombre: 'Café Carchi',
        categoriaNombre: 'Cafeterías',
        titulo: 'Promoción',
        descripcion: '',
        fechaInicio: ahora.subtract(const Duration(hours: 1)),
        fechaFin: ahora.add(const Duration(hours: 1)),
        radioAlertaMetros: 200,
        latitud: 0.8119,
        longitud: -77.7173,
      );

      final copia = promocion.copiarCon(
        urlImagen: 'https://example.com/promocion.jpg',
        distanciaMetros: 180,
      );

      expect(copia.urlImagen, 'https://example.com/promocion.jpg');
      expect(copia.distanciaMetros, 180);
    });
  });

  group('PromocionPublicaService', () {
    late PromocionPublicaService service;

    setUp(() {
      final supabase = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key-de-prueba',
      );

      service = PromocionPublicaService(supabase: supabase);
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

    test('rechaza una latitud fuera del rango permitido', () {
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

    test('rechaza una longitud fuera del rango permitido', () {
      expect(
        () => service.calcularDistanciaMetros(
          latitudOrigen: 0,
          longitudOrigen: -200,
          latitudDestino: 0,
          longitudDestino: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
