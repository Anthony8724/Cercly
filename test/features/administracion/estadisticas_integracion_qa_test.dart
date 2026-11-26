import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cercly/features/administracion/models/estadisticas_admin_model.dart';
import 'package:cercly/features/administracion/services/estadisticas_administrador_service.dart';

void main() {
  final env = Platform.environment;

  test(
    'Seis indicadores contra Supabase QA real',
    () async {
      const url = 'http://127.0.0.1:57421';

      expect(env['CERCLY_STATS_QA_URL'], url);

      final cliente = SupabaseClient(url, env['CERCLY_STATS_QA_ANON']!);

      try {
        final acceso = await cliente.auth.signInWithPassword(
          email: 'qa-estadisticas-administrador@example.com',
          password: env['CERCLY_STATS_QA_PASSWORD']!,
        );

        expect(acceso.session, isNotNull);

        final servicio = EstadisticasAdministradorService(supabase: cliente);

        final resumen = await servicio.obtenerResumen();

        expect(resumen.usuariosTotal, 1007);
        expect(resumen.usuariosActivos, 1007);
        expect(resumen.propietariosTotal, 1);
        expect(resumen.usuariosNormalesTotal, 1005);

        expect(resumen.establecimientos.total, 209);
        expect(resumen.establecimientos.aprobados, 207);
        expect(resumen.establecimientos.pendientes, 1);
        expect(resumen.establecimientos.rechazados, 1);

        expect(resumen.solicitudes.pendientes, 207);
        expect(resumen.promocionesTotal, 208);
        expect(resumen.promocionesActivas, 207);

        final esperados = {
          TipoIndicadorAdmin.usuariosRegistrados: 1007,
          TipoIndicadorAdmin.usuariosActivos: 1007,
          TipoIndicadorAdmin.propietarios: 1,
          TipoIndicadorAdmin.establecimientos: 209,
          TipoIndicadorAdmin.solicitudesPendientes: 207,
          TipoIndicadorAdmin.promocionesActivas: 207,
        };

        for (final indicador in esperados.entries) {
          final items = await servicio.obtenerDetalleIndicador(indicador.key);

          expect(items.length, indicador.value, reason: indicador.key.name);

          if (indicador.key == TipoIndicadorAdmin.establecimientos) {
            expect(items.map((e) => e.titulo).toSet(), {
              for (var i = 1; i <= 209; i++) 'Negocio QA $i',
            });
          }

          if (indicador.key == TipoIndicadorAdmin.promocionesActivas) {
            expect(items.map((e) => e.titulo).toSet(), {
              for (var i = 1; i <= 207; i++) 'Promocion QA $i',
            });
          }

          if (indicador.key == TipoIndicadorAdmin.solicitudesPendientes) {
            expect(items.map((e) => e.titulo).toSet(), {
              for (var i = 1; i <= 206; i++) 'Negocio QA $i',
              'Solicitud registro QA',
            });

            expect(
              items.every((e) => e.subtitulo == 'Solicitante: Usuario HTTP QA'),
              isTrue,
            );
          }

          debugPrint(
            'APROBADO: ${indicador.key.name}, '
            '${items.length} registros HTTP reales',
          );
        }
      } finally {
        try {
          if (cliente.auth.currentSession != null) {
            await cliente.auth.signOut();
          }
        } finally {
          await cliente.dispose();
        }
      }
    },
    skip: env['CERCLY_STATS_QA_ENABLED'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
