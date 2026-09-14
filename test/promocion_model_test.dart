import 'package:cercly/features/promociones/models/promocion_model.dart';
import 'package:flutter_test/flutter_test.dart';

PromocionModel crearPromocion({
  String titulo = 'Descuento de prueba',
  DateTime? fechaInicio,
  DateTime? fechaFin,
  int radioAlertaMetros = 100,
  bool activa = true,
}) {
  final inicio = fechaInicio ?? DateTime.utc(2026, 9, 12, 12);
  final fin = fechaFin ?? DateTime.utc(2026, 9, 13, 12);

  return PromocionModel(
    id: '',
    establecimientoId: '00000000-0000-0000-0000-000000000001',
    titulo: titulo,
    descripcion: 'Promoción utilizada para pruebas',
    fechaInicio: inicio,
    fechaFin: fin,
    radioAlertaMetros: radioAlertaMetros,
    activa: activa,
  );
}

void main() {
  test('convierte la promoción al formato de Supabase', () {
    final promocion = crearPromocion();

    final datos = promocion.toSupabaseParaCrear();

    expect(datos['establecimiento_id'], '00000000-0000-0000-0000-000000000001');
    expect(datos['titulo'], 'Descuento de prueba');
    expect(datos['radio_alerta_metros'], 100);
    expect(datos['activa'], true);
    expect(datos['imagen_ruta_storage'], isNull);
    expect(datos['fecha_inicio'], '2026-09-12T12:00:00.000Z');
  });

  test('genera solo campos editables para actualizar', () {
    final promocion = crearPromocion();

    final datos = promocion.toSupabaseParaActualizar();

    expect(datos['titulo'], 'Descuento de prueba');
    expect(datos['descripcion'], 'Promoción utilizada para pruebas');
    expect(datos['radio_alerta_metros'], 100);
    expect(datos['fecha_inicio'], '2026-09-12T12:00:00.000Z');
    expect(datos['fecha_fin'], '2026-09-13T12:00:00.000Z');
    expect(datos.containsKey('establecimiento_id'), isFalse);
    expect(datos.containsKey('activa'), isFalse);
    expect(datos.containsKey('imagen_ruta_storage'), isFalse);
  });

  test('rechaza un título vacío', () {
    expect(() => crearPromocion(titulo: ' '), throwsArgumentError);
  });

  test('rechaza una fecha final anterior al inicio', () {
    expect(
      () => crearPromocion(
        fechaInicio: DateTime.utc(2026, 9, 13),
        fechaFin: DateTime.utc(2026, 9, 12),
      ),
      throwsArgumentError,
    );
  });

  test('rechaza un radio menor a 10 metros', () {
    expect(() => crearPromocion(radioAlertaMetros: 9), throwsArgumentError);
  });

  test('rechaza un radio mayor a 5000 metros', () {
    expect(() => crearPromocion(radioAlertaMetros: 5001), throwsArgumentError);
  });

  test('determina si una promoción está vigente', () {
    final ahora = DateTime.now();

    final promocion = crearPromocion(
      fechaInicio: ahora.subtract(const Duration(hours: 1)),
      fechaFin: ahora.add(const Duration(hours: 1)),
    );

    expect(promocion.estaVigente, true);
  });

  test('una promoción inactiva no está vigente', () {
    final ahora = DateTime.now();

    final promocion = crearPromocion(
      fechaInicio: ahora.subtract(const Duration(hours: 1)),
      fechaFin: ahora.add(const Duration(hours: 1)),
      activa: false,
    );

    expect(promocion.estaVigente, false);
  });
}
