import 'package:cercly/config/supabase_options.dart';
import 'package:cercly/features/promociones/services/promociones_destacadas_publicas_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Staging consulta solo campanas destacadas vigentes', () async {
    final cliente = SupabaseClient(
      SupabaseOptions.url,
      SupabaseOptions.publishableKey,
    );
    try {
      final promos = await PromocionesDestacadasPublicasService(
        supabase: cliente,
      ).listarVigentes();
      expect(promos.length, lessThanOrEqualTo(8));
      for (final promo in promos) {
        expect(promo.estaVigente, isTrue);
        expect(promo.establecimientoId, isNotEmpty);
      }
    } finally {
      await cliente.dispose();
    }
  }, skip: SupabaseOptions.isConfigured ? false : 'Supabase sin configurar');
}
