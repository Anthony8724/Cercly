import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/config/supabase_options.dart';
import 'package:cercly/features/establecimientos/services/establecimiento_publico_service.dart';

void main() {
  final puedeEjecutarse = SupabaseOptions.isConfigured;

  late SupabaseClient supabase;
  late EstablecimientoPublicoService service;

  setUpAll(() {
    if (!puedeEjecutarse) {
      return;
    }

    supabase = SupabaseClient(
      SupabaseOptions.url,
      SupabaseOptions.publishableKey,
    );

    service = EstablecimientoPublicoService(supabase: supabase);
  });

  tearDownAll(() async {
    if (puedeEjecutarse) {
      await supabase.dispose();
    }
  });

  test('consulta establecimientos públicos reales desde Supabase', () async {
    final establecimientos = await service.listar(
      latitudUsuario: 0.8119,
      longitudUsuario: -77.7173,
    );

    expect(establecimientos, isNotEmpty);

    for (final establecimiento in establecimientos) {
      expect(establecimiento.id, isNotEmpty);
      expect(establecimiento.nombre, isNotEmpty);
      expect(establecimiento.direccion, isNotEmpty);
      expect(establecimiento.categoria.id, isNotEmpty);
      expect(establecimiento.categoria.nombre, isNotEmpty);
      expect(establecimiento.distanciaMetros, isNotNull);
      expect(establecimiento.distanciaMetros, greaterThanOrEqualTo(0));

      for (final promocion in establecimiento.promociones) {
        expect(promocion.estaVigente, isTrue);
      }
    }

    for (var indice = 1; indice < establecimientos.length; indice++) {
      final anterior = establecimientos[indice - 1].distanciaMetros!;

      final actual = establecimientos[indice].distanciaMetros!;

      expect(actual, greaterThanOrEqualTo(anterior));
    }
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');

  test('obtiene el detalle de un establecimiento aprobado', () async {
    final establecimientos = await service.listar();

    expect(establecimientos, isNotEmpty);

    final primero = establecimientos.first;
    final detalle = await service.obtenerPorId(primero.id);

    expect(detalle, isNotNull);
    expect(detalle!.id, primero.id);
    expect(detalle.nombre, primero.nombre);
    expect(detalle.categoria.id, primero.categoria.id);
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');

  test('filtra establecimientos por categoría', () async {
    final establecimientos = await service.listar();

    expect(establecimientos, isNotEmpty);

    final categoriaId = establecimientos.first.categoria.id;

    final filtrados = await service.listar(categoriaId: categoriaId);

    expect(filtrados, isNotEmpty);

    for (final establecimiento in filtrados) {
      expect(establecimiento.categoria.id, categoriaId);
    }
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');

  test('pagina la búsqueda PostGIS sin repetir la primera fila', () async {
    final primeraPagina = await service.buscarCercanos(
      latitud: 0.8116,
      longitud: -77.7172,
      radioMetros: 50000,
      limite: 1,
    );
    final segundaPagina = await service.buscarCercanos(
      latitud: 0.8116,
      longitud: -77.7172,
      radioMetros: 50000,
      limite: 1,
      desplazamiento: 1,
    );

    expect(primeraPagina, hasLength(1));
    expect(segundaPagina, hasLength(1));
    expect(segundaPagina.single.id, isNot(primeraPagina.single.id));
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');
}
