import 'package:cercly/features/promociones/services/administracion_destacadas_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inicioPromo = DateTime.utc(2026, 11, 1);
  final finPromo = DateTime.utc(2026, 11, 30);

  test('acepta una campaña incluida dentro de la promoción', () {
    expect(
      () => AdministracionDestacadasService.validarPeriodo(
        inicio: DateTime.utc(2026, 11, 12),
        fin: DateTime.utc(2026, 11, 14),
        inicioPromocion: inicioPromo,
        finPromocion: finPromo,
      ),
      returnsNormally,
    );
  });

  test('impide una campaña más larga que la promoción', () {
    expect(
      () => AdministracionDestacadasService.validarPeriodo(
        inicio: DateTime.utc(2026, 11, 12),
        fin: DateTime.utc(2026, 12, 1),
        inicioPromocion: inicioPromo,
        finPromocion: finPromo,
      ),
      throwsArgumentError,
    );
  });

  test('impide periodos invertidos', () {
    expect(
      () => AdministracionDestacadasService.validarPeriodo(
        inicio: DateTime.utc(2026, 11, 14),
        fin: DateTime.utc(2026, 11, 12),
        inicioPromocion: inicioPromo,
        finPromocion: finPromo,
      ),
      throwsArgumentError,
    );
  });
}
