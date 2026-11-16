import 'package:cercly/features/promociones/services/administracion_destacadas_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza la referencia y acepta una referencia valida', () {
    expect(
      AdministracionDestacadasService.validarReferenciaPago('  TRANSF-0001  '),
      'TRANSF-0001',
    );
  });

  test('rechaza una referencia vacia o menor a 4 caracteres', () {
    expect(
      () => AdministracionDestacadasService.validarReferenciaPago('  '),
      throwsArgumentError,
    );
    expect(
      () => AdministracionDestacadasService.validarReferenciaPago('123'),
      throwsArgumentError,
    );
  });

  test('rechaza referencias muy largas y caracteres de control', () {
    expect(
      () => AdministracionDestacadasService.validarReferenciaPago('A' * 101),
      throwsArgumentError,
    );
    expect(
      () => AdministracionDestacadasService.validarReferenciaPago('REF\n123'),
      throwsArgumentError,
    );
  });
}
