import 'package:cercly/features/promociones/services/administracion_destacadas_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('campañas sin pago no se consideran pagadas; con fecha sí', () {
    Map<String, dynamic> fila(String? pago) => {
      'id': 'campana-prueba',
      'promocion_id': 'promocion-prueba',
      'estado': 'pendiente',
      'fecha_inicio': '2026-11-15T00:00:00Z',
      'fecha_fin': '2026-11-22T00:00:00Z',
      'pago_confirmado_en': pago,
      'promociones': {
        'titulo': 'Oferta de prueba',
        'establecimientos': {'nombre': 'Negocio de prueba'},
      },
    };
    expect(
      CampanaDestacadaAdmin.fromSupabase(fila(null)).pagoConfirmado,
      isFalse,
    );
    expect(
      CampanaDestacadaAdmin.fromSupabase(fila('2026-11-15T18:00:00Z'))
          .pagoConfirmado,
      isTrue,
    );
  });
}
