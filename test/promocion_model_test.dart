import 'package:cercly/features/promociones/models/promocion_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromocionModel', () {
    test('está vigente dentro del periodo indicado', () {
      final ahora = DateTime.now();

      final promocion = PromocionModel(
        id: 'promo-1',
        establecimientoId: 'establecimiento-1',
        titulo: 'Descuento del 20 %',
        descripcion: 'Promoción válida durante esta semana.',
        fechaInicio: ahora.subtract(const Duration(days: 1)),
        fechaFin: ahora.add(const Duration(days: 1)),
        radioAlertaMetros: 200,
        activa: true,
      );

      expect(promocion.estaVigente, isTrue);
    });

    test('no está vigente cuando se encuentra desactivada', () {
      final ahora = DateTime.now();

      final promocion = PromocionModel(
        id: 'promo-2',
        establecimientoId: 'establecimiento-1',
        titulo: 'Promoción desactivada',
        descripcion: 'Esta promoción no debe mostrarse.',
        fechaInicio: ahora.subtract(const Duration(days: 1)),
        fechaFin: ahora.add(const Duration(days: 1)),
        radioAlertaMetros: 100,
        activa: false,
      );

      expect(promocion.estaVigente, isFalse);
    });

    test('no está vigente cuando ya terminó', () {
      final ahora = DateTime.now();

      final promocion = PromocionModel(
        id: 'promo-3',
        establecimientoId: 'establecimiento-1',
        titulo: 'Promoción terminada',
        descripcion: 'Esta promoción ya finalizó.',
        fechaInicio: ahora.subtract(const Duration(days: 2)),
        fechaFin: ahora.subtract(const Duration(days: 1)),
        radioAlertaMetros: 300,
        activa: true,
      );

      expect(promocion.estaVigente, isFalse);
    });
  });
}
