import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/config/supabase_options.dart';
import 'package:cercly/features/promociones/services/promocion_publica_service.dart';

void main() {
  final puedeEjecutarse = SupabaseOptions.isConfigured;

  late SupabaseClient supabase;
  late PromocionPublicaService service;

  setUpAll(() {
    if (!puedeEjecutarse) {
      return;
    }

    supabase = SupabaseClient(
      SupabaseOptions.url,
      SupabaseOptions.publishableKey,
    );

    service = PromocionPublicaService(supabase: supabase);
  });

  tearDownAll(() async {
    if (puedeEjecutarse) {
      await supabase.dispose();
    }
  });

  test('consulta promociones públicas vigentes desde Supabase', () async {
    final promociones = await service.listarVigentes(
      latitudUsuario: 0.8119,
      longitudUsuario: -77.7173,
    );

    for (final promocion in promociones) {
      expect(promocion.id, isNotEmpty);
      expect(promocion.titulo, isNotEmpty);
      expect(promocion.establecimientoId, isNotEmpty);
      expect(promocion.establecimientoNombre, isNotEmpty);
      expect(promocion.categoriaNombre, isNotEmpty);
      expect(promocion.estaVigente, isTrue);
      expect(promocion.distanciaMetros, isNotNull);
      expect(promocion.distanciaMetros, greaterThanOrEqualTo(0));
    }

    for (var indice = 1; indice < promociones.length; indice++) {
      final anterior = promociones[indice - 1].distanciaMetros!;
      final actual = promociones[indice].distanciaMetros!;

      expect(actual, greaterThanOrEqualTo(anterior));
    }
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');

  test('obtiene una promoción vigente por su identificador', () async {
    final promociones = await service.listarVigentes();

    if (promociones.isEmpty) {
      return;
    }

    final primera = promociones.first;

    final detalle = await service.obtenerPorId(primera.id);

    expect(detalle, isNotNull);
    expect(detalle!.id, primera.id);
    expect(detalle.titulo, primera.titulo);
    expect(detalle.establecimientoId, primera.establecimientoId);
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');

  test('filtra las promociones por categoría', () async {
    final promociones = await service.listarVigentes();

    if (promociones.isEmpty) {
      return;
    }

    final primera = promociones.first;

    final establecimiento = await supabase
        .from('establecimientos')
        .select('categoria_id')
        .eq('id', primera.establecimientoId)
        .single();

    final categoriaId = establecimiento['categoria_id'] as String;

    final filtradas = await service.listarVigentes(categoriaId: categoriaId);

    for (final promocion in filtradas) {
      expect(promocion.categoriaNombre, isNotEmpty);
    }
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');

  test('detecta promociones dentro de su radio de alerta', () async {
    final promociones = await service.listarCercanas(
      latitudUsuario: 0.8119,
      longitudUsuario: -77.7173,
    );

    for (final promocion in promociones) {
      expect(promocion.distanciaMetros, isNotNull);
      expect(
        promocion.distanciaMetros!,
        lessThanOrEqualTo(promocion.radioAlertaMetros),
      );
    }
  }, skip: puedeEjecutarse ? false : 'Supabase no está configurado.');
}
