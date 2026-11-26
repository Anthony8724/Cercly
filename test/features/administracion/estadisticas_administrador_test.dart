import 'package:cercly/features/administracion/models/estadisticas_admin_model.dart';
import 'package:cercly/features/administracion/services/estadisticas_administrador_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EstadisticasAdministradorService.mensajeError', () {
    test('retorna mensaje claro cuando el error es 42501 (sin permisos)', () {
      const error = PostgrestException(message: 'No autorizado', code: '42501');

      final mensaje = EstadisticasAdministradorService.mensajeError(error);

      expect(mensaje.toLowerCase(), contains('permisos'));
    });

    test('retorna mensaje claro cuando falta la funcion RPC (PGRST202)', () {
      const error = PostgrestException(
        message: 'Could not find the function',
        code: 'PGRST202',
      );

      final mensaje = EstadisticasAdministradorService.mensajeError(error);

      expect(mensaje.toLowerCase(), contains('migración'));
    });

    test('retorna mensaje claro ante FormatException', () {
      const error = FormatException('Respuesta inesperada');

      final mensaje = EstadisticasAdministradorService.mensajeError(error);

      expect(mensaje.toLowerCase(), contains('formato'));
    });

    test('retorna mensaje generico ante error de red o desconocido', () {
      final mensaje = EstadisticasAdministradorService.mensajeError(
        Exception('socket timeout'),
      );

      expect(mensaje.toLowerCase(), contains('conexión'));
    });
  });

  group('Seguridad de mensajes de error', () {
    const datoInterno = 'DETALLE_INTERNO_PRIVADO';

    test('no expone errores internos de PostgreSQL', () {
      const error = PostgrestException(message: datoInterno, code: 'XX000');

      final mensaje = EstadisticasAdministradorService.mensajeError(error);

      expect(mensaje, isNot(contains(datoInterno)));
      expect(mensaje, 'No se pudieron cargar las estadísticas.');
    });

    test('no expone detalles internos de formato', () {
      const error = FormatException(datoInterno);

      final mensaje = EstadisticasAdministradorService.mensajeError(error);

      expect(mensaje, isNot(contains(datoInterno)));
    });

    test('no expone detalles de excepciones desconocidas', () {
      final mensaje = EstadisticasAdministradorService.mensajeError(
        Exception(datoInterno),
      );

      expect(mensaje, isNot(contains(datoInterno)));
    });
  });

  group('GranularidadRegistrosX', () {
    test('expone valores RPC y etiquetas esperadas', () {
      expect(GranularidadRegistros.dia.valorRpc, 'dia');
      expect(GranularidadRegistros.semana.valorRpc, 'semana');
      expect(GranularidadRegistros.mes.valorRpc, 'mes');
      expect(GranularidadRegistros.dia.etiqueta, 'Día');
      expect(GranularidadRegistros.semana.etiqueta, 'Semana');
      expect(GranularidadRegistros.mes.etiqueta, 'Mes');
    });
  });

  group('TipoIndicadorAdmin', () {
    test('contiene los 6 indicadores esperados del panel', () {
      expect(TipoIndicadorAdmin.values.length, 6);
    });
  });
}
