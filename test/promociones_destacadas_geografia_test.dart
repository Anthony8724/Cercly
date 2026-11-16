import 'package:cercly/features/promociones/models/promocion_destacada_model.dart';
import 'package:cercly/features/promociones/services/promociones_destacadas_publicas_service.dart';
import 'package:flutter_test/flutter_test.dart';

PromocionDestacadaModel _p(String id, double latitud, double longitud) {
  final ahora = DateTime.now();
  return PromocionDestacadaModel(
    id: id,
    establecimientoId: 'negocio-$id',
    establecimientoNombre: 'Negocio $id',
    categoriaNombre: 'Servicios',
    titulo: id,
    descripcion: 'Campaña de prueba',
    fechaInicio: ahora.subtract(const Duration(days: 1)),
    fechaFin: ahora.add(const Duration(days: 1)),
    radioAlertaMetros: 500,
    latitud: latitud,
    longitud: longitud,
  );
}

void main() {
  test('cualquier ciudad: filtra destacadas por radio y cercanía', () {
    final cercanas = seleccionarDestacadas(
      candidatas: [
        _p('lejana', 0.03, 0),
        _p('media', 0.005, 0),
        _p('cercana', 0.001, 0),
      ],
      limite: 8,
      latitudUsuario: 0,
      longitudUsuario: 0,
      radioMaximoMetros: 1000,
    );
    expect(cercanas.map((p) => p.id), ['cercana', 'media']);
    expect(cercanas.first.distanciaMetros, lessThan(150));
  });

  test('sin GPS devuelve campañas nacionales en el orden recibido', () {
    final seleccion = seleccionarDestacadas(
      candidatas: [_p('Quito', 0, 0), _p('Guayaquil', 5, 5)],
      limite: 1,
    );
    expect(seleccion.map((p) => p.id), ['Quito']);
    expect(seleccion.first.distanciaMetros, isNull);
  });

  test('rechaza radio sin GPS', () {
    expect(
      () => seleccionarDestacadas(
        candidatas: [],
        limite: 8,
        radioMaximoMetros: 5000,
      ),
      throwsArgumentError,
    );
  });
}
